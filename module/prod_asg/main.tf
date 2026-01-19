#prod security group
resource "aws_security_group" "prod_sg" {
  name        = "${var.name}-prod-sg"
  description = "prod Security group"
  vpc_id      = var.vpc_id
  ingress {
    description     = "SSH access from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg, var.ansible_sg.id]
  }

  ingress {
    description = "HTTP access from ALB"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.prod_elb_sg.id]
  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-prod-sg"
  }
}
# Fetch latest Ubuntu 22.04 LTS AMI
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

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Create Launch Template
resource "aws_launch_template" "prod_lt" {
  image_id      = data.aws_ami.ubuntu.id
  name_prefix   = "${var.name}-prod-web-tmp"
  instance_type = "t2.medium"
  key_name      = var.key

  user_data = base64encode(templatefile("${path.module}/docker.sh", {
    nr_key     = var.nr_key
    nr_acc_id = var.nr_acc_id
  }))

  network_interfaces {
    security_groups = [aws_security_group.prod_sg.id]
  }

  metadata_options {
    http_tokens = "required"
  }
}

# Create Auto Scaling Group
resource "aws_autoscaling_group" "prod_autoscaling_grp" {
  name                      = "${var.name}-prod-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 120
  health_check_type         = "EC2"
  force_delete              = true
  launch_template {
    id      = aws_launch_template.prod_lt.id
    version = "$Latest"
  }
  vpc_zone_identifier = var.private_subnets
  target_group_arns   = [aws_lb_target_group.prod-tg.arn]

  tag {
    key                 = "Name"
    value               = "${var.name}-prod-asg"
    propagate_at_launch = true
  }
}
# Created autoscaling group policy
resource "aws_autoscaling_policy" "prod-asg-policy" {
  name                   = "${var.name}-asg-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.prod_autoscaling_grp.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Create Application Load Balancer for prod
resource "aws_lb" "prod_lb" {
  name               = "${var.name}-prod-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prod_elb_sg.id]
  subnets            = var.public_subnets
  tags = {
    Name = "${var.name}-prod-lb"
  }
}
#prod-elb security group
resource "aws_security_group" "prod_elb_sg" {
  name        = "${var.name}-prod-elb-sg"
  description = "prod-elb Security group"
  vpc_id      = var.vpc_id
  ingress {
    description = "HTTP access from ALB"
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
    Name = "${var.name}-prod-elb-sg"
  }
}

#Create Target group for load Balancer
resource "aws_lb_target_group" "prod-tg" {
  name        = "${var.name}-prod-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 5
    path                = "/"
  }
  tags = {
    Name = "${var.name}-prod-tg"
  }
}

# Create load balance listener for http
resource "aws_lb_listener" "prod_load_balancer_listener_http" {
  load_balancer_arn = aws_lb.prod_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod-tg.arn
  }
}
# Create load balance listener for https
resource "aws_lb_listener" "prod_load_balancer_listener_https" {
  load_balancer_arn = aws_lb.prod_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod-tg.arn
  }
}
# Create Route 53 record for prod server
data "aws_route53_zone" "acp-zone" {
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


# Create Route 53 record for prod server
resource "aws_route53_record" "prod-record" {
  zone_id = data.aws_route53_zone.acp-zone.zone_id
  name    = "prod.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_lb.prod_lb.dns_name
    zone_id                = aws_lb.prod_lb.zone_id
    evaluate_target_health = true
  }
}