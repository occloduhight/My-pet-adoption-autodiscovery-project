# Data source to get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# ansible IAM Role
resource "aws_iam_role" "ansible_role" {
  name = "${var.name}-ansible-discovery-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
     Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach ec2fullaccess policy to the ansible role
resource "aws_iam_role_policy_attachment" "ec2_policy" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}
# Attach s3fullaccess policy to the ansible role
resource "aws_iam_role_policy_attachment" "s3_policy" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_instance_profile" "ansible_profile" {
  name = "${var.name}-ansible-profile"
  role = aws_iam_role.ansible_role.name
}

# Security Group for Ansible Server
resource "aws_security_group" "ansible_sg" {
  name        = "${var.name}-ansible-sg"
  description = "Allow ssh"
  vpc_id      = var.vpc_id

  ingress {
    description = "sshport"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-ansible-sg"
  }
}

resource "aws_instance" "ansible_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  subnet_id              = var.subnet_id[0]
  iam_instance_profile = aws_iam_instance_profile.ansible_profile.id
  depends_on = [aws_s3_object.scripts1, aws_s3_object.scripts2, aws_s3_object.scripts3]
  user_data = templatefile("${path.module}/user_data.sh", {
    private_key         = var.private_key
    newrelic_api_key    = var.nr_key
    newrelic_account_id = var.nr_acc_id
    s3_bucket_name      = var.s3_bucket_name
    nexus_ip            = var.nexus_ip
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
    Name = "${var.name}-ansible-server"
  }
}
# upload Ansible file to S3
resource "aws_s3_object" "scripts1" {
  bucket = var.s3_bucket_name
  key    = "scripts/deployment.yml"
  source = "${path.module}/scripts/deployment.yml"
}

# upload Ansible file to S3
resource "aws_s3_object" "scripts2" {
  bucket = var.s3_bucket_name
  key    = "scripts/prod_script.sh"
  source = "${path.module}/scripts/prod_script.sh"
}

# upload Ansible file to S3
resource "aws_s3_object" "scripts3" {
  bucket = var.s3_bucket_name
  key    = "scripts/stage_script.sh"
  source = "${path.module}/scripts/stage_script.sh"
}