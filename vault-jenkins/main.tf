locals {
    name = "odochi"
}
# VPC CREATION
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "$(local.name)-vpc"
  }
}
# INTERNET GATEWAY
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "$(local.name)-igw"
  }
}
# PUBLIC SUBNETS
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = true
  tags = {
    Name = "$(local.name)-public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-3b"
  map_public_ip_on_launch = true
  tags = {
    Name = "$(local.name)-public-subnet-2"
  }
}

# PUBLIC ROUTE TABLE
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "$(local.name)public-route-table"
  }
}

# ROUTE TABLE ASSOCIATIONS
resource "aws_route_table_association" "public_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}
# Generate a new RSA private key (for SSH)
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create an AWS key pair from the generated public key
resource "aws_key_pair" "keypair" {
  key_name   = "${local.name}-keypair"
  public_key = tls_private_key.key.public_key_openssh
}

# Save the private key locally so you can SSH into the instance
resource "local_file" "private_key_pem" {
  content  = tls_private_key.key.private_key_pem
  filename = "${path.module}/${local.name}-keypair.pem"
}

# IAM ROLE AND INSTANCE PROFILE
# Create IAM Role for EC2 with SSM and Admin permissions
resource "aws_iam_role" "jenkins_ec2_role" {
  name = "jenkins-ec2-role"

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
# Attach AmazonSSMManagedInstanceCore policy
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role = aws_iam_role.vault_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach AdministratorAccess policy
resource "aws_iam_role_policy_attachment" "admin_access" {
  role = aws_iam_role.vault_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Security Group for Jenkins
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
  ami                         = data.aws_ami.redhat.id # redhat in eu-west-3)
  instance_type               = "t3.medium"
  key_name               = aws_key_pair.keypair.key_name   
   subnet_id                   = aws_subnet.public_subnet_1.id   
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile = aws_iam_instance_profile.jenkins_instance_profile.name
  associate_public_ip_address = true

root_block_device {
    volume_size = 20    
    volume_type = "gp3" 
    encrypted   = true 
  }
  user_data = templatefile("./jenkins_userdata.sh", {

    region = "eu-west-3"
  })
  metadata_options {
    http_tokens = "required"

  }

tags = {
    Name = "$(local.name)-Jenkins-Server"
  }
}

# Create ACM certificate with DNS validation
resource "aws_acm_certificate" "acm-cert" {
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
# Create Security group for the jenkins elb
resource "aws_security_group" "jenkins-elb-sg" {
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
  security_groups = [aws_security_group.jenkins-elb-sg.id] 
  subnets         = [ aws_subnet.public_subnet_1.id ]

  listener {
    instance_port      = 8080
    instance_protocol  = "HTTP"
    lb_port            = 443
    lb_protocol        = "HTTPS"
    # ssl_certificate_id = aws_acm_certificate.acm-cert.arn
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
# Security Group for Vault
resource "aws_security_group" "vault_sg" {
  name        = "vault-sg"
  description = "Allow Vault and SSH traffic"
  vpc_id      = aws_vpc.vpc.id
  # Inbound: HTTP on port 
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Vault UI/API access"
  }
 # Outbound: Allow all traffic (to EC2)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# create a vault server
resource "aws_instance" "vault" {
  ami                         = data.aws_ami.ubuntu.id           
  instance_type               = "t2.medium"                      
  subnet_id                   = aws_subnet.public_subnet_1.id            
  vpc_security_group_ids      = [aws_security_group.vault_sg.id] 
  key_name               = aws_key_pair.keypair.key_name
  associate_public_ip_address = true                             
  iam_instance_profile = aws_iam_instance_profile.vault_ssm_profile.name
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  # User data script to install Jenkins and required tools
  user_data = templatefile("./vault.sh", {
    region        = "eu-west-3",
    VAULT_VERSION = "1.18.3",
    key           = aws_kms_key.vault.id
  })
  metadata_options {
    http_tokens = "required"
  }
  # Tag the instance for easy identification
  tags = {
    Name = "${local.name}-vault-server"
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
#creating and attaching an IAM role with SSM permissions to the vault instance.
resource "aws_iam_role" "vault_ssm_role" {
  name = "${local.name}-ssm-vault-role2"
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
  name = "${local.name}-ssm-vault-instance-profile2"
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

# Security Group for Vault ELB
resource "aws_security_group" "vault_elb" {
  name        = "${local.name}-vault-elb-sg"
  description = "Security group for Vault ELB"
  vpc_id      = aws_vpc.vpc.id

  # Allow HTTP (Vault UI) and HTTPS traffic
  ingress {
    description = "Allow Vault UI traffic"
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
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

# -------------------------------
# Vault Classic Load Balancer
# -------------------------------
resource "aws_elb" "vault_elb" {
  name            = "${local.name}-vault-elb"
  subnets         = [aws_subnet.public_subnet_1.id]  # ✅ Must be in the same VPC
  security_groups = [aws_security_group.vault_elb.id]
  instances       = [aws_instance.vault.id]

  listener {
    instance_port     = 8200
    instance_protocol = "tcp"
    lb_port           = 8200
    lb_protocol       = "tcp"
  }

  health_check {
    target              = "TCP:8200"
    interval            = 30
    timeout             = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
  }

  tags = {
    Name = "${local.name}-vault-elb"
  }

  depends_on = [aws_instance.vault]
}
