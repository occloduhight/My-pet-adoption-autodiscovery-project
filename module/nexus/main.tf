# Creating security group for Nexus
resource "aws_security_group" "nexus_sg" {
  name        = "${var.name}-nexus-sg"
  description = "Allow inbound traffic from lb and all outbound traffic"
  vpc_id      = var.vpc
  ingress {
    description     = "Nexus (port 8081)"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.nexus_lb_sg.id]
  }
  ingress {
    description     = "custom (port 8085)"
    from_port       = 8085
    to_port         = 8085
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Egress rule: Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound to anywhere
  }
  tags = {
    Name = "${var.name}-Nexus-sg"
  }
}

# Creating security group for LoadBalancer
resource "aws_security_group" "nexus_lb_sg" {
  name        = "${var.name}-nexus-lb-sg2"
  description = "Allow inbound traffic for lb and all outbound traffic"
  vpc_id      = var.vpc
  ingress {
    description = "HTTPS (port 443)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow from the VPC CIDR block
  }
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound to anywhere
  }
  tags = {
    Name = "${var.name}-nexus-lb-sg2"
  }
}
# create load balancer for the nexus
resource "aws_elb" "elb_nexus" {
  # ELB name must not exceed 32 characters
  name            = substr("${var.name}-nexus-elb", 0, 32)

  security_groups = [aws_security_group.nexus_lb_sg.id]
  subnets         = var.subnets
  instances       = [aws_instance.nexus_server.id]

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  listener {
    instance_port      = 8081
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
    target              = "TCP:8081"
  }

  tags = {
    # Keep tag Name readable, truncate if necessary
    Name = substr("${var.name}-nexus-elb", 0, 32)
  }
}

# import route 53 zone id
data "aws_route53_zone" "selected" {
  name         = var.domain
  private_zone = false
}

# Create a DNS record for the ELB
resource "aws_route53_record" "nexus" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "nexus.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.elb_nexus.dns_name
    zone_id                = aws_elb.elb_nexus.zone_id
    evaluate_target_health = true
  }
}

# create an IAM instance role
resource "aws_iam_role" "nexus_role" {
  name = "${var.name}-nexus-role2"
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
    Name = "${var.name}-nexus-role"
  }
}

# nexus IAM profile
resource "aws_iam_instance_profile" "nexus_profile" {
  name = "${var.name}-nexus-profile"
  role = aws_iam_role.nexus_role.name
}

# SSM permission
resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.nexus_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Data source to get the latest red-hat AMI
data "aws_ami" "centos" {
  most_recent = true
  owners      = ["125523088429"] # Verified CentOS image owner (check regionally!)
  filter {
    name   = "name"
    values = ["CentOS Stream 9*"]
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

# Create Nexus Server
resource "aws_instance" "nexus_server" {
  ami                         = data.aws_ami.centos.id 
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.nexus_sg.id]
  key_name                    = var.keypair
  subnet_id                   = var.subnet_id
  user_data                   = file("${path.module}/nexus_userdata.sh")
  iam_instance_profile        = aws_iam_instance_profile.nexus_profile.name
  associate_public_ip_address = true
  tags = {
    Name = "${var.name}-nexus-server"
  }
}

# Configure Docker on Jenkins to allow Nexus insecure registry via SSM
resource "aws_ssm_document" "docker_config" {
  name          = "${var.name}-docker-config"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Configure Docker to allow Nexus as an insecure registry"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "configureDocker"
        inputs = {
          runCommand = [
            "sudo mkdir -p /etc/docker",
            "sudo bash -c 'cat <<EOF > /etc/docker/daemon.json\n{\n  \"insecure-registries\": [\"${aws_instance.nexus_server.private_ip}:8085\"]\n}\nEOF'",
            "sudo systemctl restart docker"
          ]
        }
      }
    ]
  })
}

# Associate the Docker configuration SSM document with the Jenkins instance
resource "aws_ssm_association" "docker_config_association" {
  name = aws_ssm_document.docker_config.name

  # Target the Jenkins instance by its ID (passed from root module)
  targets {
    key    = "InstanceIds"
    # values = [aws_instance.jenkins_server.id]
    values = [var.jenkins_instance_id]


  }

  compliance_severity = "HIGH"   # optional, improves AWS Console visibility

  depends_on = [
    aws_ssm_document.docker_config,
    aws_instance.nexus_server
  ]
}
