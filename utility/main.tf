locals {
  name = "utility"
}

# Create a default VPC for vault server
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16" # CIDR block for the VPC
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${local.name}-vpc"
  }
}

# Generate a new RSA private key using the TLS provider
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create a new key pair using the AWS provider
resource "aws_key_pair" "public_key" {
  key_name   = "${local.name}-keypair"
  public_key = tls_private_key.keypair.public_key_openssh
}

# Save the generated private key to a local PEM file
resource "local_file" "private_key" {
  content  = tls_private_key.keypair.private_key_pem
  filename = "${local.name}-keypair.pem"
}

# data source to fetch avaiable availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Create a public subnet in the VPC
resource "aws_subnet" "public_subnet" {
  count                   = 2 # Create two public subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.${count.index}.0/24"                                        # CIDR block for each subnet
  availability_zone       = element(data.aws_availability_zones.available.names, count.index) # Use different AZs
  map_public_ip_on_launch = true                                                              # Enable public IP assignment
  tags = {
    Name = "${local.name}-public-subnet-${count.index + 1}"
  }
}
# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${local.name}-internet-gateway"
  }
}

# Create a route table for the public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${local.name}-public-rt"
  }
}
# Associate the public subnets with the route table
resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public.id
}


# Fetch latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# IAM role for Vault EC2 instance
resource "aws_iam_role" "vault_ec2_role" {
  name = "${local.name}-vault-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach SSM managed policy so instance can be managed via Session Manager
resource "aws_iam_role_policy_attachment" "vault_ssm_attachment" {
  role       = aws_iam_role.vault_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# KMS policy for Vault (basic set of operations) - scope as needed
resource "aws_iam_policy" "vault_kms_policy" {
  name        = "${local.name}-vault-kms-policy"
  description = "Allow KMS operations needed by Vault"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowKMSUse"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "${aws_kms_key.vault_kms.arn}"
      }
    ]
  })
}

/* Backend & Auto-unseal resources for Vault */

# KMS key for auto-unseal
resource "aws_kms_key" "vault_kms" {
  description             = "KMS key for Vault auto-unseal"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "Enable IAM users to use the key"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
}

# Attach the KMS policy to the EC2 role
resource "aws_iam_role_policy_attachment" "vault_kms_attach" {
  role       = aws_iam_role.vault_ec2_role.name
  policy_arn = aws_iam_policy.vault_kms_policy.arn
}

# Instance profile for Vault EC2
resource "aws_iam_instance_profile" "vault_instance_profile" {
  name = "${local.name}-vault-instance-profile"
  role = aws_iam_role.vault_ec2_role.name
}

# Security group for Vault EC2 instance (allow 8200 from ELB only)
resource "aws_security_group" "vault_sg" {
  name        = "${local.name}-vault-sg"
  description = "Security group for Vault server"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Vault API from ELB"
    from_port       = 8200
    to_port         = 8200
    protocol        = "tcp"
    security_groups = [aws_security_group.vault_elb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-vault-sg"
  }
}

# Security group for Vault ELB (allow incoming 8200)
resource "aws_security_group" "vault_elb_sg" {
  name        = "${local.name}-vault-elb-sg"
  description = "Security group for Vault ELB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow Vault traffic"
    from_port   = 443 # Changed to 443 for HTTPS
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-vault-elb-sg"
  }
}

# Vault EC2 instance
resource "aws_instance" "vault_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.public_subnet[0].id
  vpc_security_group_ids      = [aws_security_group.vault_sg.id]
  key_name                    = aws_key_pair.public_key.key_name
  iam_instance_profile        = aws_iam_instance_profile.vault_instance_profile.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/vault.sh", {
    region    = var.region
    key       = aws_kms_key.vault_kms.id
    nr_key    = var.nr_key
    nr_acc_id = var.nr_acc_id
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${local.name}-vault-server"
  }
}

# Classic ELB for Vault
resource "aws_elb" "vault_elb" {
  name            = "${local.name}-vault-elb"
  subnets         = aws_subnet.public_subnet[*].id
  security_groups = [aws_security_group.vault_elb_sg.id]
  depends_on      = [aws_acm_certificate_validation.acm_cert_validation]

  listener {
    instance_port      = 8200
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.acm-cert.arn
  }

  health_check {
    target              = "TCP:8200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }

  instances                   = [aws_instance.vault_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "${local.name}-vault-elb"
  }
}

# Lookup the existing Route 53 hosted zone
data "aws_route53_zone" "my-hosted-zone" {
  name         = var.domain_name
  private_zone = false
}

# Create ACM certificate with DNS validation 
resource "aws_acm_certificate" "acm-cert" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name}-acm-cert"
  }
}

# fetch DNS validation records for the ACM certificate
resource "aws_route53_record" "acm_validation_records" {
  for_each = {
    for dvo in aws_acm_certificate.acm-cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = data.aws_route53_zone.my-hosted-zone.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
}



# Validate the ACM certificate after DNS records are created
resource "aws_acm_certificate_validation" "acm_cert_validation" {
  certificate_arn         = aws_acm_certificate.acm-cert.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation_records : r.fqdn]
}

# Route53 record for Vault
resource "aws_route53_record" "vault_alias" {
  zone_id = data.aws_route53_zone.my-hosted-zone.zone_id
  name    = "vault.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_elb.vault_elb.dns_name
    zone_id                = aws_elb.vault_elb.zone_id
    evaluate_target_health = true
  }
  depends_on = [aws_acm_certificate_validation.acm_cert_validation]
}



################################
# Jenkins Server Infrastructure #
################################

# IAM role for Jenkins EC2 instance
resource "aws_iam_role" "instance_role" {
  name               = "${local.name}-Jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Attach SSM policies to Jenkins role
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach Administrator access policy to Jenkins role
resource "aws_iam_role_policy_attachment" "admin_attach" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Attach role to Jenkins instance profile
resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name = "${local.name}-Jenkins-profile"
  role = aws_iam_role.instance_role.name
}

#Security group for jenkins
resource "aws_security_group" "jenkins_sg" {
  name        = "${local.name}-jenkins-sg"
  description = "Allowing inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Jenkins-port"
    protocol        = "tcp"
    from_port       = 8080
    to_port         = 8080
    security_groups = [aws_security_group.jenkins_elb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-jenkins-sg"
  }
}

#Security group for jenkins-elb
resource "aws_security_group" "jenkins_elb_sg" {
  name        = "${local.name}-jenkins-elb-sg"
  description = "Allowing inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Jenkins access"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-jenkins-elb-sg"
  }
}

# Get the latest RHEL 9 AMI for the region
# -----------------------------
# Get the latest Red Hat 9 AMI for the region
# -----------------------------
data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat official AWS account
  filter {
    name   = "name"
    values = ["RHEL-9.*_HVM-*-x86_64-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# -----------------------------
# Jenkins EC2 instance using Red Hat
# -----------------------------
resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.redhat.id
  instance_type               = "t2.large"
  subnet_id                   = aws_subnet.public_subnet[1].id
  key_name                    = aws_key_pair.public_key.key_name
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins_instance_profile.name
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/jenkins.sh", {
    nr_key    = var.nr_key
    nr_acc_id = var.nr_acc_id
    region    = var.region
  })

  # Pass variables to user-data script
  # user_data = templatefile("${path.module}/jenkins.sh", {
  #   newrelic_api_key    = var.nr_key
  #   newrelic_account_id = var.nr_acc_id
  #   region              = var.region
  # })

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${local.name}-jenkins"
  }
}

#creating Jenkins elb
resource "aws_elb" "elb-jenkins" {
  name            = "${local.name}-elb-jenkins"
  security_groups = [aws_security_group.jenkins_elb_sg.id]
  subnets         = aws_subnet.public_subnet[*].id

  listener {
    instance_port      = 8080
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.acm-cert.arn
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    target              = "TCP:8080"
  }

  instances                   = [aws_instance.jenkins.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "${local.name}-elb-jenkins"
  }
}

#creating A jenkins record
resource "aws_route53_record" "jenkins-record" {
  zone_id = data.aws_route53_zone.my-hosted-zone.zone_id
  name    = "jenkins.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_elb.elb-jenkins.dns_name
    zone_id                = aws_elb.elb-jenkins.zone_id
    evaluate_target_health = true
  }
}