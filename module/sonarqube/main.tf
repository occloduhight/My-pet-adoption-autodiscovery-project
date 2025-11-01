# Ubuntu AMI lookup
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

# Load user data script from file
resource "aws_instance" "sonarqube_server" {
  ami                         = data.aws_ami.ubuntu.id # ubuntu in eu-west-3
  instance_type               = "t2.medium"
  key_name                    = var.key
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sonarqube_sg.id]
  user_data = local.userdata
  root_block_device {
    volume_size = 20    # Size in GB
    volume_type = "gp3" # General Purpose SSD (recommended)
    encrypted   = true  # Enable encryption (best practice)
  }
  tags = {
    Name = "${var.name}-sonarqube-server"
  }
}

# Create sonarqube security group
resource "aws_security_group" "sonarqube_sg" {
  name        = "${var.name}-sonarqube-sg"
  description = "Allow SSH and HTTPS"
  vpc_id      = var.vpc_id
  ingress {
    description = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg]
  }
  ingress {
    description = "HTTP from ELB"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    security_groups = [aws_security_group.elb_sonar_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}--sonarqube-sg"
  }
}

#Create Security Group for Sonarqube Sever ELB
resource "aws_security_group" "elb_sonar_sg" {
  name        = "${var.name}-sonarqube-elb-sg"
  description = "Allow HTTPS"
  vpc_id      = var.vpc_id
  ingress {
    description = "HTTPS from Internet"
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
    Name = "${var.name}-sonarqube-elb-sg"
  }
}

# Create Elastic load balancer for Sonarqube Server
resource "aws_elb" "elb_sonar" {
  name            = "${var.name}-elb-sonarqube"
  subnets         = var.subnets
  security_groups = [aws_security_group.elb_sonar_sg.id]
  instances                   = [aws_instance.sonarqube_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  listener {
    instance_port      = 9000
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = var.acm_certificate_arn
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:9000"
    interval            = 30
  }
  tags = {
    Name = "${var.name}-elb-sonarqube"
  }
}

# Create Route 53 Hosted Zone for Sonarqube
data "aws_route53_zone" "zone_id" {
  name         = var.domain
  private_zone = false
}

# Create Route 53 A Record for Sonarqube Server
resource "aws_route53_record" "sonar_record" {
  zone_id = data.aws_route53_zone.zone_id.zone_id
  name    = "sonarqube.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.elb_sonar.dns_name
    zone_id                = aws_elb.elb_sonar.zone_id
    evaluate_target_health = true
  }
}