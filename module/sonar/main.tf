# Creating security group for sonar
resource "aws_security_group" "sonar_sg" {
  name        = "${var.name}-sonar-sg"
  description = "Allow SSH, HTTP (Nginx), and HTTPS access"
  vpc_id      = var.vpc_id

  # Ingress: HTTP access for Nginx
  ingress {
    description = "HTTP Access for Nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [ aws_security_group.sonar_sg_elb.id ]
  }
#   ingress {
#   description     = "SonarQube from ELB"
#   from_port       = 9000
#   to_port         = 9000
#   protocol        = "tcp"
#   security_groups = [aws_security_group.sonar_sg_elb.id]
# }

  # Egress rule: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols
    cidr_blocks = ["0.0.0.0/0"] 
  }

  tags = {
    Name = "${var.name}-sonar-sg"
  }
}
# Security Group for SonarQube Server ##
resource "aws_security_group" "sonar_sg_elb" {
  name        = "${var.name}-sonar-sg-elb"
  description = "Allow SSH, HTTP (Nginx), and HTTPS access"
  vpc_id      = var.vpc_id

  # Ingress: HTTP access for Nginx
  ingress {
    description = "HTTP Access for Nginx"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Egress: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-sonar-sg-elb"
  }
}

# Data block for IAM Policy Document
data "aws_iam_policy_document" "sonar_assume_role_policy" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# IAM Role and Instance Profile for SonarQube EC2 Instance
resource "aws_iam_role" "sonar_role" {
  name               = "${var.name}-sonar-role"
  assume_role_policy = data.aws_iam_policy_document.sonar_assume_role_policy.json
}

# Attach SSM managed policy 
resource "aws_iam_role_policy_attachment" "sonar_ssm_attach" {
  role       = aws_iam_role.sonar_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "sonar_instance_profile" {
  name = "${var.name}-sonar-instance-profile"
  role = aws_iam_role.sonar_role.name
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

# Create sonar Server
resource "aws_instance" "sonar_server" {
  ami                         = data.aws_ami.latest_ubuntu.id
  instance_type               = "t2.medium"
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.sonarqube_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.sonar_instance_profile.name
  # User Data Script for all installation and configuration steps
  user_data = templatefile("${path.module}/sonar.sh", {
    newrelic_api_key    = var.nr_key
    newrelic_account_id = var.nr_acc_id
  })
  tags = {
    Name = "${var.name}-Sonar_Server"
  }
}

resource "aws_elb" "elb_sonar" {
  name            = "${var.name}-elb-sonar"
  security_groups = [aws_security_group.sonar_sg_elb.id]
  subnets         = var.public_subnets
  listener {
    instance_port      = 80
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = data.aws_acm_certificate.acm-cert.arn

  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "tcp:80"
    interval            = 30
  }
  instances                   = [aws_instance.sonar_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "${var.name}-sonar_elb"
  }
}

# import route 53 zone id
data "aws_route53_zone" "selected" {
  name         = var.domain_name
  private_zone = false
}
#creating A sonarqube record
resource "aws_route53_record" "sonar" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "sonar.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_elb.elb_sonar.dns_name
    zone_id                = aws_elb.elb_sonar.zone_id
    evaluate_target_health = true
  }
}
# data block to fetch ACM certificate for Sonarqube
data "aws_acm_certificate" "acm-cert" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}
