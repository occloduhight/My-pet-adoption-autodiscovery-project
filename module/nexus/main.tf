# Security Group for Nexus Server
resource "aws_security_group" "nexus_sg" {
  name        = "${var.name}-nexus-sg"
  description = "Allow inbound Nexus traffic and all outbound traffic"
   vpc_id      = var.vpc

  # Allow Nexus UI (8081) from Load Balancer
  ingress {
    description     = "Allow Nexus UI (port 8081)"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  # Allow Docker registry access (8085) from anywhere (adjust as needed)
  ingress {
    description = "Docker Registry (port 8085)"
    from_port   = 8085
    to_port     = 8085
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
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


# Security Group for Load Balancer
resource "aws_security_group" "lb_sg" {
  name        = "${var.name}-lb-sg"
  description = "Allow inbound traffic to Load Balancer"
  vpc_id      =  var.vpc

  ingress {
    description = "HTTPS (port 443)"
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
    Name = "${var.name}-lb-sg"
  }
}
# LOAD BALANCER + ROUTE53 DNS RECORD
resource "aws_elb" "elb_nexus" {
  name            = "${var.name}-nexus-elb"
  security_groups = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  listener {
    instance_port      = 8081
    instance_protocol  = "HTTP"
    lb_port            = 443
    lb_protocol        = "HTTPS"
    ssl_certificate_id = aws_acm_certificate.acm-cert.arn
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    target              = "TCP:8081"
  }

  instances                   = [aws_instance.nexus_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "${var.name}-nexus-elb"
  }
}

resource "aws_route53_record" "nexus_record" {
 zone_id = data.aws_route53_zone.acp-zone.id
  name    = "nexus.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_elb.elb_nexus.dns_name
    zone_id                = aws_elb.elb_nexus.zone_id
    evaluate_target_health = true
  }
}
# IAM ROLE AND PROFILE
resource "aws_iam_role" "nexus_role" {
  name = "${var.name}-nexus-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.name}-nexus-role"
  }
}

resource "aws_iam_instance_profile" "nexus_profile" {
  name = "${var.name}-nexus-profile"
  role = aws_iam_role.nexus_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.nexus_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# Data Source - Red Hat AMI
data "aws_ami" "redhat" {
  most_recent = true

  filter {
    name   = "name"
    values = ["RHEL-8*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["309956199498"] # Red Hat official AWS account ID
}

# EC2 INSTANCE - NEXUS SERVER
resource "aws_instance" "nexus_server" {
  ami                         = data.aws_ami.redhat.id
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.nexus_sg.id]
  key_name                    = var.keypair
  subnet_id                   = var.subnet_id
  iam_instance_profile        = aws_iam_instance_profile.nexus_profile.name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/nexus_userdata.sh")

  tags = {
    Name = "${var.name}-nexus-server"
  }
}

resource "null_resource" "update_jenkins" {
  depends_on = [aws_instance.nexus_server]

  provisioner "local-exec" {
    command = <<-EOF
#!/bin/bash
sudo cat <<EOT>> /etc/docker/daemon.json
  {
    "insecure-registries" : ["${aws_instance.nexus_server.public_ip}:8085"]
  }
EOT
sudo systemctl restart docker
EOF
  interpreter = [ "bash", "-c" ]
  } 
}