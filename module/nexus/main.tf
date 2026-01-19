data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM role for EC2 instances (Nexus) to access SSM
resource "aws_iam_role" "nexus_ssm_role" {
  name = "${var.name}-nexus-ssm-role"

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

# Attach AWS managed policy for SSM access
resource "aws_iam_role_policy_attachment" "nexus_ssm_managed" {
  role       = aws_iam_role.nexus_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for attaching the role to the EC2 instance
resource "aws_iam_instance_profile" "nexus_instance_profile" {
  name = "${var.name}-nexus-instance-profile"
  role = aws_iam_role.nexus_ssm_role.name
}


# Nexus security group: only allow traffic from ELB on app port (8081)
resource "aws_security_group" "nexus_sg" {
  name        = "${var.name}-nexus-sg"
  description = "Allow traffic from Nexus ELB only"
  vpc_id      = var.vpc_id


  ingress {
    description     = "Nexus app from ELB"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.nexus_elb_sg.id]
  }

  ingress {
    description = "Nexus app from ELB"
    from_port   = 8085
    to_port     = 8085
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-nexus-sg" }
}

# Nexus ELB security group: allow HTTPS from anywhere
resource "aws_security_group" "nexus_elb_sg" {
  name        = "${var.name}-nexus-elb-sg"
  description = "ELB for Nexus - allow HTTPS from anywhere"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS"
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

  tags = { Name = "${var.name}-nexus-elb-sg" }
}

# Nexus EC2 instance (SSM-only access)
resource "aws_instance" "nexus" {
  ami                         = data.aws_ami.ubuntu.id

  instance_type               = "t2.medium"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.nexus_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.nexus_instance_profile.name
  associate_public_ip_address = true
  key_name                    = var.key_name

  user_data = templatefile("${path.module}/nexus.sh", {
    nr_key    = var.nr_key
    nr_acc_id = var.nr_acc_id
  })
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.name}-nexus" }
}

# Classic ELB for Nexus
resource "aws_elb" "nexus_elb" {
  name                      = "${var.name}-nexus-elb"
  subnets                   = var.subnet_ids
  security_groups           = [aws_security_group.nexus_elb_sg.id]
  cross_zone_load_balancing = true

  listener {
    instance_port      = 8081
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = var.certificate_arn

  }

  health_check {
    target              = "TCP:8081"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  instances = [aws_instance.nexus.id]
  tags      = { Name = "${var.name}-nexus-elb" }

}

# Route53 Hosted Zone and ACM Certificate
data "aws_route53_zone" "my_hosted_zone" {
  name         = var.domain_name
  private_zone = false
}

# data block to fetch ACM certificate for Nexus
# data "aws_acm_certificate" "acm-cert" {
#   domain   = var.domain_name
#   statuses = ["ISSUED"]
# }
# data "aws_acm_certificate" "acm-cert" {
#   domain   = var.domain_name
#   statuses = ["ISSUED"]
#   most_recent = true
# }


# Route53 Record for Nexus Service
resource "aws_route53_record" "nexus_dns" {
  zone_id = data.aws_route53_zone.my_hosted_zone.zone_id
  name    = "nexus.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_elb.nexus_elb.dns_name
    zone_id                = aws_elb.nexus_elb.zone_id
    evaluate_target_health = true
  }
}

