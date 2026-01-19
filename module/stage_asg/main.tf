# Stage Security Group
resource "aws_security_group" "stage_sg" {
  name        = "${var.name}-stage-sg"
  description = "Stage Security group"
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
    security_groups = [aws_security_group.stage_elb_sg.id]
  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-stage-sg"
  }
}

# Stage ELB Security Group
resource "aws_security_group" "stage_elb_sg" {
  name        = "${var.name}-stage-elb-sg"
  description = "Stage ELB Security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP access from internet"
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
    Name = "${var.name}-stage-elb-sg"
  }
}

# Data source: latest CentOS AMI
data "aws_ami" "centos" {
  most_recent = true
  owners      = ["125523088429"] # CentOS official owner ID
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

# Launch Template
resource "aws_launch_template" "stage_lnch_tmpl" {
  image_id      = data.aws_ami.centos.id
  name_prefix   = "${var.name}-stage-web-tmpl"
  instance_type = "t2.medium"
  key_name      = var.key_name
user_data = base64encode(templatefile("${path.module}/docker.sh", {
  nexus_ip       = var.nexus_ip,
  nr_key         = var.nr_key,
  nr_acc_id      = var.nr_acc_id,
}))

  network_interfaces {
    security_groups = [aws_security_group.stage_sg.id]
  }

  metadata_options {
    http_tokens = "required"
  }
}

# Create Auto Scaling Group
resource "aws_autoscaling_group" "stage_autoscaling_grp" {
  name                      = "${var.name}-stage-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 120
  health_check_type         = "EC2"
  force_delete              = true

  launch_template {
    id      = aws_launch_template.stage_lnch_tmpl.id
    version = "$Latest"
  }

  vpc_zone_identifier = var.private_subnets
  target_group_arns   = [aws_lb_target_group.stage_target_group.arn]

  tag {
    key                 = "Name"
    value               = "${var.name}-stage-asg"
    propagate_at_launch = true
  }
}

# resource "aws_autoscaling_group" "stage_autoscaling_grp" {
#   name                      = "${var.name}-stage-asg"
#   max_size                  = 3
#   min_size                  = 1
#   desired_capacity          = 1
#   health_check_grace_period = 120
#   health_check_type         = "EC2"
#   force_delete              = true
#   launch_template {
#     id      = aws_launch_template.stage_lnch_tmpl.id
#     version = "$Latest"
#   }
#   vpc_zone_identifier = var.private_subnets
#   target_group_arns   = [aws_lb_target_group.stage-target-group.arn]

#   tag {
#     key                 = "Name"
#     value               = "${var.name}-stage-asg"
#     propagate_at_launch = true
#   }
# }
# Autoscaling Policy
resource "aws_autoscaling_policy" "stage_asg_policy" {
  name                   = "asg-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.stage_autoscaling_grp.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Application Load Balancer
resource "aws_lb" "stage_lb" {
  name               = "${var.name}-stage-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.stage_elb_sg.id]

  # Use public subnets list
  subnets = var.public_subnets

  tags = {
    Name = "${var.name}-stage-lb"
  }
}

# Target Group
resource "aws_lb_target_group" "stage_target_group" {
  name        = "${var.name}-stage-tg"
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
    Name = "${var.name}-stage-tg"
  }
}

# HTTP Listener
resource "aws_lb_listener" "stage_listener_http" {
  load_balancer_arn = aws_lb.stage_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage_target_group.arn
  }
}

# HTTPS Listener
resource "aws_lb_listener" "stage_listener_https" {
  load_balancer_arn = aws_lb.stage_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage_target_group.arn
  }
}

# Route 53
data "aws_route53_zone" "selected" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "stage_record" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "stage.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.stage_lb.dns_name
    zone_id                = aws_lb.stage_lb.zone_id
    evaluate_target_health = true
  }
}
