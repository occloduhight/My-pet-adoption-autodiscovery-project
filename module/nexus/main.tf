data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat's AWS account ID
  filter {
    name   = "name"
    values = ["RHEL-8.*_HVM-*-x86_64-*-Hourly2-GP2"]
  }
}

resource "aws_iam_role" "nexus_role" {
  name = "${var.name}-nexus-role234"
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

# Attach SSM managed policy to the nexus role
resource "aws_iam_role_policy_attachment" "ssm_role_attachment" {
  role       = aws_iam_role.nexus_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create Instance Profile for nexus EC2
resource "aws_iam_instance_profile" "nexus_instance_profile" {
  name = "${var.name}-nexus-instance-profile24"
  role = aws_iam_role.nexus_role.name
}

# nexus EC2 Instance
resource "aws_instance" "nexus" {
  ami                         = data.aws_ami.redhat.id
  instance_type               = "t2.medium"
  subnet_id                   = var.subnet
  vpc_security_group_ids      = [aws_security_group.nexus_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.nexus_instance_profile.id
  user_data = templatefile("${path.module}/nexus_userdata.sh", {
    nr_key = var.nr_key,
    nr_acc_id         = var.nr_acc_id,
    region              = var.region
  })
  tags = {
    Name = "${var.name}-nexus"
  }
}

resource "aws_security_group" "nexus_sg" {
  name        = "${var.name}-nexus-sg"
  description = "Allow SSH and HTTP from anywhere"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
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
  tags = {
    Name = "${var.name}-nexus-sg"
  }
}

resource "aws_security_group" "nexus_elb_sg" {
  name        = "${var.name}-nexus-elb-sg"
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
    Name = "${var.name}-nexus-elb-sg"
  }
}

# nexus classic load balancer
resource "aws_elb" "nexus_elb" {
  name            = "${var.name}-nexus-elb"
  subnets         = var.subnets_elb
  security_groups = [aws_security_group.nexus_elb_sg.id]
  instances       = [aws_instance.nexus.id]
  listener {
    instance_port      = 8081
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = data.aws_acm_certificate.cert.arn
  }
  health_check {
    target              = "TCP:8081"
    interval            = 30
    timeout             = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
  }
  tags = {
    Name = "${var.name}-nexus-elb"
  }
}

# import route 53 zone
data "aws_route53_zone" "main" {
  name         = var.domain
  private_zone = false
}

# import ACM certificate
data "aws_acm_certificate" "cert" {
  domain   = var.domain
  statuses = ["ISSUED"]
}

# Create Route 53 record for nexus ELB
resource "aws_route53_record" "nexus_elb_record" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "nexus.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.nexus_elb.dns_name
    zone_id                = aws_elb.nexus_elb.zone_id
    evaluate_target_health = false
  }
}

resource "aws_ssm_document" "update_jenkins" {
  name          = "${var.name}-update-jenkins-docker-config"
  document_type = "Command"
  depends_on    = [aws_instance.nexus]

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Configure Docker insecure registry on Nexus instance"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "configureDocker"
        inputs = {
          runCommand = [
            "sudo mkdir -p /etc/docker",
            "echo '{\"insecure-registries\" : [\"${aws_instance.nexus.public_ip}:8085\"]}' | sudo tee /etc/docker/daemon.json",
            "sudo systemctl daemon-reexec",
            "sudo systemctl restart docker"
          ]
        }
      }
    ]
  })
}

  resource "aws_ssm_association" "update_jenkins" {
  name = aws_ssm_document.update_jenkins.name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.nexus.id]
  }
}

