data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}
resource "aws_iam_role" "sonarqube_role" {
  name = "${var.name}-sonarqube-role"
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

# Attach SSM managed policy to the sonarqube role
resource "aws_iam_role_policy_attachment" "ssm_role_attachment" {
  role       = aws_iam_role.sonarqube_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create Instance Profile for sonarqube EC2
resource "aws_iam_instance_profile" "sonarqube_instance_profile" {
  name = "${var.name}-sonarqube-instance-profile"
  role = aws_iam_role.sonarqube_role.name
}

# sonarqube EC2 Instance
resource "aws_instance" "sonarqube" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.medium"
  subnet_id                   = var.subnet
  vpc_security_group_ids      = [aws_security_group.sonarqube_sg.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.sonarqube_instance_profile.name
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/user_data.sh", {
    nr_key = var.nr_key,
    nr_acc_id         = var.nr_acc_id
  })
  tags = {
    Name = "${var.name}-sonarqube"
  }
}

resource "aws_security_group" "sonarqube_sg" {
  name        = "${var.name}-sonarqube-sg"
  description = "Allow SSH and HTTP from anywhere"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 9000
    to_port     = 9000
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
    Name = "${var.name}-sonarqube-sg"
  }
}

resource "aws_security_group" "sonarqube_elb_sg" {
  name        = "${var.name}-sonarqube-elb-sg"
  description = "Allow SSH and HTTP from anywhere"
  vpc_id      = var.vpc_id

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
    Name = "${var.name}-sonarqube-elb-sg"
  }
}

# sonarqube classic load balancer
resource "aws_elb" "sonarqube_elb" {
  name            = "${var.name}-sonarqube-elb"
  subnets         = var.subnets_elb
  security_groups = [aws_security_group.sonarqube_elb_sg.id]
  instances       = [aws_instance.sonarqube.id]
  listener {
    instance_port      = 9000
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = data.aws_acm_certificate.cert.arn
  }
  health_check {
    target              = "TCP:9000"
    interval            = 30
    timeout             = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
  }
  tags = {
    Name = "${var.name}-sonarqube-elb"
  }
}

# import route 53 zone
data "aws_route53_zone" "main" {
  name         = var.domain
  private_zone = false
}

# import ACM certificate
data "aws_acm_certificate" "cert" {
  domain   = "odochidevops.space"
  statuses = ["ISSUED"]
}

# Create Route 53 record for sonarqube ELB
resource "aws_route53_record" "sonarqube_elb_record" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "sonarqube.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.sonarqube_elb.dns_name
    zone_id                = aws_elb.sonarqube_elb.zone_id
    evaluate_target_health = false
  }
}