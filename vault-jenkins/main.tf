locals {
  name = "odochi"
}

# VPC CREATION
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${local.name}-vpc"
  }
}

# INTERNET GATEWAY
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${local.name}-igw"
  }
}

# create public subnet 1
resource "aws_subnet" "pub_sub" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-3a"

  tags = {
    Name = "${local.name}-pub_sub"
  }
}

# PUBLIC ROUTE TABLE
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

# ROUTE TABLE ASSOCIATIONS
resource "aws_route_table_association" "public_association_1" {
  subnet_id      = aws_subnet.pub_sub.id
  route_table_id = aws_route_table.pub_rt.id
}

# SSH Key
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "keypair" {
  key_name   = "${local.name}-keypair"
  public_key = tls_private_key.key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content  = tls_private_key.key.private_key_pem
  filename = "${path.module}/${local.name}-keypair.pem"
}

# IAM ROLE & INSTANCE PROFILE
resource "aws_iam_role" "jenkins_ec2_role" {
  name = "${local.name}-jenkins-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name = "jenkins-ec2-profile"
  role = aws_iam_role.jenkins_ec2_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.jenkins_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "admin_access" {
  role       = aws_iam_role.jenkins_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Security Groups
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow HTTP, SSH and Jenkins access"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow Jenkins Web UI"
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

# Data Source - Red Hat AMI
data "aws_ami" "redhat" {
  most_recent = true

  filter {
    name   = "name"
    values = ["RHEL-8*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["309956199498"] # Red Hat official AWS account ID
}

# Jenkins EC2 Instance
resource "aws_instance" "jenkins_server" {
  ami                         = data.aws_ami.redhat.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.keypair.key_name
  subnet_id                   = aws_subnet.pub_sub.id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins_instance_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("./jenkins_userdata.sh", {
    region          = var.region
    nr_key          = var.nr_key
    nr_acc_id       = var.nr_acc_id
    RELEASE_VERSION = "8"
  })

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${local.name}-Jenkins-Server"
  }
}

# DATA SOURCES
# Fetch the most recent Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Fetch Route53 hosted zone
data "aws_route53_zone" "selected" {
  name         = "odochidevops.space."   # replace with your domain
  private_zone = false
}

# Security group for Vault server
resource "aws_security_group" "vault_sg" {
  name        = "${local.name}-vault-sg"
  description = "Allow SSH, HTTP, HTTPS, and Vault UI/API"
  vpc_id      = aws_vpc.vpc.id  # ensure aws_vpc.main exists or update to your actual VPC reference

  ingress {
    description = "Vault HTTP"
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
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
    Name = "${local.name}-vault-sg"
  }
}

resource "aws_instance" "vault_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.keypair.key_name
  subnet_id              = aws_subnet.pub_sub.id
  vpc_security_group_ids = [aws_security_group.vault_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.vault_profile.name
  associate_public_ip_address = true
  tags = {
    Name = "${local.name}-vault-server"
  }
}
# ACM CERTIFICATE + VALIDATION
resource "aws_acm_certificate" "acm_cert" {
  domain_name       = "vault.odochidevops.space"
  validation_method = "DNS"
  tags = {
    Name = "vault-acm-cert"
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.acm_cert.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.selected.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.acm_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ELB FOR VAULT
resource "aws_elb" "vault_elb" {
  name               = "${local.name}-vault-elb"
  subnets            = [aws_subnet.pub_sub.id]
  security_groups    = [aws_security_group.vault_sg.id]

  listener {
    instance_port     = 8200
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  instances = [aws_instance.vault_server.id]

  health_check {
    target              = "HTTP:8200/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${local.name}-vault-elb"
  }
}
# ROUTE53 RECORD FOR VAULT
resource "aws_route53_record" "vault_record" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "vault.${trim(data.aws_route53_zone.selected.name, ".")}"
  type    = "A"

  alias {
    name                   = aws_elb.vault_elb.dns_name
    zone_id                = aws_elb.vault_elb.zone_id
    evaluate_target_health = true
  }
}

# ELB Security Group vault
resource "aws_security_group" "vault_elb_sg" {
  name        = "${local.name}-vault-elb-sg"
  description = "Allow inbound HTTPS traffic"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-vault-elb-sg"
  }
}

# Vault IAM Role vault
resource "aws_iam_role" "vault_role" {
  name = "${local.name}-vault-role"
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
  tags = {
    Name = "${local.name}-vault-role"
  }
}
# Attach KMS access policy to Vault IAM Role
resource "aws_iam_role_policy" "vault_kms_access" {
  name = "${local.name}-vault-kms-access"
  role = aws_iam_role.vault_role.id   # ensure this matches your actual IAM role name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.kms_key.arn
      }
    ]
  })
}

# Create a KMS key for Vault
resource "aws_kms_key" "kms_key" {
  description             = "${local.name}-vault-kms-key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${local.name}-vault-kms-key"
  }
}

# Create a KMS alias
resource "aws_kms_alias" "kms_alias" {
  name          = "alias/${local.name}-kms-key"
  target_key_id = aws_kms_key.kms_key.key_id
}

# Vault IAM Instance Profile
resource "aws_iam_instance_profile" "vault_profile" {
  name = "${local.name}-vault-profile"
  role = aws_iam_role.vault_role.name
}
