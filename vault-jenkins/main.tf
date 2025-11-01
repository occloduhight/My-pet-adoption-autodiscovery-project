locals {
  name = "auto-project"
}

resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "${local.name}-vpc"
  }
}

# create public subnet 
resource "aws_subnet" "pub_sub" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-3a"

  tags = {
    Name = "${local.name}-pub_sub"
  }
}
# create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.name}-igw"
  }
}
# Create route table for public subnet
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${local.name}-pub_rt"
  }
}
# Creating route table association for public_subnet_1
resource "aws_route_table_association" "ass_public_subnet" {
  subnet_id      = aws_subnet.pub_sub.id
  route_table_id = aws_route_table.pub_rt.id
}
# Create keypair resource
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "private_key" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "${local.name}-key.pem"
  file_permission = "400"
}
resource "aws_key_pair" "public_key" {
  key_name   = "${local.name}1-key"
  public_key = tls_private_key.keypair.public_key_openssh
}
# Data source to get the latest RedHat AMI
data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # RedHat's owner ID
  filter {
    name   = "name"
    values = ["RHEL-9*"]
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

# Create IAM role for Jenkins server to assume  SSM role
resource "aws_iam_role" "ssm_jenkins_role" {
  name = "${local.name}-ssm-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach  AmazonSSMManaged policy to JENKIN IAM role
resource "aws_iam_role_policy_attachment" "jenkins_ssm_managed_instance_core" {
  role       = aws_iam_role.ssm_jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# Attach ADMINISTRATOR ACCESS policy to the role
resource "aws_iam_role_policy_attachment" "jenkins_admin_role_attachment" {
  role       = aws_iam_role.ssm_jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
# CREATE INSTANCE PROFILE FOR JENKINS SERVER
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${local.name}-ssm-jenkins-profile"
  role = aws_iam_role.ssm_jenkins_role.name
}

# Create jenkins security group
resource "aws_security_group" "jenkins_sg" {
  name        = "${local.name}-jenkins-sg"
  description = "Allow SSH and HTTPS"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    from_port   = 8080
    to_port     = 8080
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
    Name = "${local.name}-jenkins-sg"
  }
}
resource "aws_instance" "jenkins_server" {
  ami                         = data.aws_ami.redhat.id 
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.public_key.id
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.pub_sub.id

  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name
  root_block_device {
    volume_size = 20    
    volume_type = "gp3" 
    encrypted   = true  
  }
  user_data = templatefile("${path.module}/jenkins_userdata.sh", {
    nr_key = var.nr_key,
    nr_acc_id      = var.nr_acc_id,
    region           = var.region
  })
  metadata_options {
    http_tokens = "required"

  }

  tags = {
    Name = "${local.name}-jenkins-server"
  }
}

# Create ACM certificate with DNS validation
resource "aws_acm_certificate" "acm_cert" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name}-acm-cert"
  }
}

data "aws_route53_zone" "acp_zone" {
  name         = "odochidevops.space"
  private_zone = false
}

# Fetch DNS Validation Records for ACM Certificate
resource "aws_route53_record" "acm_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.acm_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  # Create DNS Validation Record for ACM Certificate
  zone_id         = data.aws_route53_zone.acp_zone.zone_id
  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  depends_on      = [aws_acm_certificate.acm_cert]
}

# Validate the ACM Certificate after DNS Record Creation
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.acm_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation_record : record.fqdn]
  depends_on              = [aws_acm_certificate.acm_cert]
}

# Create Security group for the jenkins elb
resource "aws_security_group" "jenkins_elb_sg" {
  name        = "${local.name}-jenkins-elb-sg"
  description = "Allow HTTPS"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    from_port   = 443
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
    Name = "${local.name}-jenkins-elb-sg"
  }
}

# Create elastic Load Balancer for Jenkins
resource "aws_elb" "elb_jenkins" {
  name            = "elb-jenkins"
  security_groups = [aws_security_group.jenkins_elb_sg.id]
  subnets         = [aws_subnet.pub_sub.id]

  listener {
    instance_port      = 8080
    instance_protocol  = "HTTP"
    lb_port            = 443
    lb_protocol        = "HTTPS"
    ssl_certificate_id = aws_acm_certificate.acm_cert.arn
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    target              = "TCP:8080"
  }
  instances                   = [aws_instance.jenkins_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "${local.name}-jenkins-server"
  }
}

# Data source to get the latest Ubuntu AMI
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
}
# create a vault server
resource "aws_instance" "vault_server" {
  ami                         = data.aws_ami.ubuntu.id            # AMI ID passed as a variable (e.g., ubuntu)
  instance_type               = "t2.medium"                       # Instance type (e.g., t3.medium)
  subnet_id                   = aws_subnet.pub_sub.id             # Use first available subnet
  vpc_security_group_ids      = [aws_security_group.vault_sg.id]  # Attach security group
  key_name                    = aws_key_pair.public_key.key_name # Use the created key pair
  associate_public_ip_address = true                              # Required for SSH and browser access
  iam_instance_profile        = aws_iam_instance_profile.vault_ssm_profile.name
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  # User data script to install Jenkins and required tools
  user_data = templatefile("${path.module}/vault.sh", {
    region           = var.region,
    VAULT_VERSION    = "1.18.3",
    key              = aws_kms_key.vault.id,
    nr_key = var.nr_key,
    nr_acc_id      = var.nr_acc_id
    
  })
  metadata_options {
    http_tokens = "required"
  }
  # Tag the instance for easy identification
  tags = {
    Name = "${local.name}-vault"
  }
}
# create KMS key to manage vault unseal keys
resource "aws_kms_key" "vault" {
  description             = "An example symmetric encryption KMS key"
  enable_key_rotation     = true
  deletion_window_in_days = 20
  tags = {
    Name = "${local.name}-vault-kms-key"
  }
}
# Security Group for ELB to allow HTTP traffic
resource "aws_security_group" "vault_sg" {
  name        = "${local.name}-vault-sg"
  description = "Allow HTTP traffic to server"
  vpc_id      = aws_vpc.vpc.id
  # Inbound: HTTP on port 80
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Outbound: Allow all traffic (to EC2)
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
#creating and attaching an IAM role with SSM permissions to the vault instance.
resource "aws_iam_role" "vault_ssm_role" {
  name = "${local.name}-ssm-vault-role24"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}
# create iam role policy forto give permission to the kms role
resource "aws_iam_role_policy" "kms_policy" {
  name = "${local.name}-kms-policy1"
  role = aws_iam_role.vault_ssm_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDatakey*",
          "kms:DescribeKey"
        ],
        Effect   = "Allow"
        Resource = "${aws_kms_key.vault.arn}"
      }
    ]
  })
}
#Attach the AmazonSSMManagedInstanceCore policy
# — required for Session Manager and SSM Agent functionality.
resource "aws_iam_role_policy_attachment" "vault_ssm_attachment" {
  role       = aws_iam_role.vault_ssm_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# create instance profile for vault
resource "aws_iam_instance_profile" "vault_ssm_profile" {
  name = "${local.name}-ssm-vault-instance-profile"
  role = aws_iam_role.vault_ssm_role.id
}
# Security Group for ELB to allow HTTP traffic
resource "aws_security_group" "vault_elb_sg" {
  name        = "${local.name}-vault-elb-sg"
  description = "Allow HTTP traffic to server"
  vpc_id      = aws_vpc.vpc.id
  # Inbound: HTTP on port 80
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Outbound: Allow all traffic (to EC2)
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
# Create a new load balancer for vault
resource "aws_elb" "vault_elb" {
  name            = "${local.name}-vault-elb1"
  subnets         = [aws_subnet.pub_sub.id] # Use first available subnet
  security_groups = [aws_security_group.vault_elb_sg.id]
  listener {
    instance_port      = 8200
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.acm_cert.arn
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:8200"
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
# Create Route 53 record for vault server
resource "aws_route53_record" "vault_record" {
  zone_id = data.aws_route53_zone.acp_zone.id
  name    = "vault.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.vault_elb.dns_name
    zone_id                = aws_elb.vault_elb.zone_id
    evaluate_target_health = true
  }
}

# Create Route 53 record for jenkins server
resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.acp_zone.id
  name    = "jenkins.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.elb_jenkins.dns_name
    zone_id                = aws_elb.elb_jenkins.zone_id
    evaluate_target_health = true
  }
}