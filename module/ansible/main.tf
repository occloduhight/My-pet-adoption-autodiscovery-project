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

#Creating ansible security group
resource "aws_security_group" "ansible_sg" {
  name        = "${var.name}-ansible-sg"
  description = "Allow ssh"
  vpc_id      = var.vpc
  ingress {
    description     = "sshport"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-ansible-sg"
  }
}

# Create Ansible Server
resource "aws_instance" "ansible_server" {
  ami                    = data.aws_ami.ubuntu.id  
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.ansible_profile.name
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  key_name               = var.keypair
  subnet_id              = var.subnet_id
  user_data              = local.ansible_userdata
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options {http_tokens = "required"}
  tags = {
    Name = "${var.name}-ansible-server"
  }
}

# Create IAM role for ansible
resource "aws_iam_role" "ansible_role" {
  name = "${var.name}-ansible-discovery-role-"
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
# Attach the EC2 full access policy to the role
resource "aws_iam_role_policy_attachment" "ec2_policy" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}
# Attach S3 full access policy to the role
resource "aws_iam_role_policy_attachment" "s3_policy" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
# Create IAM instance profile for ansible
resource "aws_iam_instance_profile" "ansible_profile" {
  name = "${var.name}-ansible-profile"
  role = aws_iam_role.ansible_role.name
}
# resource "null_resource" "ansible_setup" {
#   provisioner "local-exec" {
#     command = <<EOT
#       aws s3 cp --recursive ${path.module}/scripts/ s3://auto-discovery-odo2025/ansible-scripts/
#     EOT
#   } 
# }
