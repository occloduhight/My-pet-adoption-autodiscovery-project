data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat's AWS account ID
  filter {
    name   = "name"
    values = ["RHEL-8.*_HVM-*-x86_64-*-Hourly2-GP2"]
  }
}

# ansible IAM Role and Instance Profile
resource "aws_iam_role" "ansible_role" {
  name = "${var.name}-ansible-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Attach ec2fullaccess policy to the ansible role
resource "aws_iam_role_policy_attachment" "ansible_role_attachment" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Attach s3fullaccess policy to the ansible role
# resource "aws_iam_role_policy_attachment" "ansible_role_attachment2" {
#   role       = aws_iam_role.ansible_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
# }

# Create Instance Profile for ansible EC2
resource "aws_iam_instance_profile" "ansible_instance_profile" {
  name = "${var.name}-ansible-instance-profile"
  role = aws_iam_role.ansible_role.name
}

# ansible EC2 Instance
resource "aws_instance" "ansible" {
  ami                    = data.aws_ami.redhat.id
  instance_type          = "t2.micro"
  subnet_id              = var.subnet
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  key_name               = var.key_name
  # associate_public_ip_address = false
  iam_instance_profile   = aws_iam_instance_profile.ansible_instance_profile.name
  user_data = templatefile("${path.module}/ansible_userdata.sh", {
    private_key = var.private_key,
    s3_bucket   = var.s3_bucket,
    nexus_ip    = var.nexus_ip
  })
  tags = {
    Name = "${var.name}-ansible"
  }
}

resource "aws_security_group" "ansible_sg" {
  name        = "${var.name}-ansible-sg"
  description = "Allow SSH and HTTP from anywhere"
  vpc_id      = var.vpc_id
  ingress {
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

# Upload scripts to s3 bucket
resource "aws_s3_object" "stage_bash_script" {
  bucket = var.s3_bucket
  key    = "scripts/stage_bash.sh"
  source = "${path.module}/scripts/stage_bash.sh"
}
resource "aws_s3_object" "prod_bash_script" {
  bucket = var.s3_bucket
  key    = "scripts/prod_bash.sh"
  source = "${path.module}/scripts/prod_bash.sh"
}
resource "aws_s3_object" "deployment_yml" {
  bucket = var.s3_bucket
  key    = "scripts/deployment.yml"
  source = "${path.module}/scripts/deployment.yml"
}
