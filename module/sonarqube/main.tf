# Creating security group for SonarQube
resource "aws_security_group" "sonarqube-sg" {
  name        = "${var.name}-sonarqube-sg"
  description = "Allow inbound traffic from lb and all outbound traffic"
  vpc_id      = var.vpc

  # Ingress rule: Allow SonarQube web UI (port 9000) from loadbalancer sg
  ingress {
    description     = "SonarQube Web UI (port 9000)"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.lb-sg.id]
    # cidr_blocks = [var.vpc_cidr_block]  # Allow from the VPC CIDR block
  }

  # Egress rule: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound to anywhere
  }

  tags = {
    Name = "${var.name}-sonarqube-sg"
  }
}

# Creating security group for LoadBalancer
resource "aws_security_group" "lb-sg" {
  name        = "${var.name}-sonarqube-lb-sg"
  description = "Allow inbound traffic for lb and all outbound traffic"
  vpc_id      = var.vpc


  # Ingress rule: Allow HTTPS (port 443) from within VPC
  ingress {
    description = "HTTPS (port 443)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow from the VPC CIDR block
  }
  # Egress rule: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound to anywhere
  }

  tags = {
    Name = "${var.name}-sonarqube-lb-sg"
  }
}
# Data source to get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# Create Sonarqube Server
resource "aws_instance" "sonarqube-server" {
  ami                         = data.aws_ami.ubuntu.id #ubuntu 
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.sonarqube-sg.id]
  key_name                    = var.keypair
  subnet_id                   = var.subnet_id
  user_data                   = file("${path.module}/sonar_userdata.sh")
  iam_instance_profile        = aws_iam_instance_profile.sonarqube_profile.name
  associate_public_ip_address = true
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.name}-sonarqube-server"
  }
}

# create loadbalancer for the sonarqube
resource "aws_elb" "elb_sonarqube" {
  name            = "${var.name}-sonarqube-elb"
  security_groups = [aws_security_group.lb-sg.id]
  subnets         = [var.subnets]

  listener {
    instance_port      = 9000
    instance_protocol  = "HTTP"
    lb_port            = 443
    lb_protocol        = "HTTPS"
    ssl_certificate_id = var.certificate
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    target              = "TCP:9000"
  }
  instances                   = [aws_instance.sonarqube-server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "${var.name}-sonarqube-elb"
  }
}

# Create a DNS record for the ELB
resource "aws_route53_record" "sonarqube" {
  zone_id = var.hosted_zone_id
  name    = "sonarqube.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_elb.elb_sonarqube.dns_name
    zone_id                = aws_elb.elb_sonarqube.zone_id
    evaluate_target_health = true
  }

}

# create an IAM instance role
resource "aws_iam_role" "sonarqube-role" {
  name = "${var.name}-sonarqube-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${var.name}-sonarqube-role"
  }
}

# sonarqube IAM profile
resource "aws_iam_instance_profile" "sonarqube_profile" {
  name = "${var.name}-sonarqube-profile"
  role = aws_iam_role.sonarqube-role.name
}

# SSM permission
resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.sonarqube-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}