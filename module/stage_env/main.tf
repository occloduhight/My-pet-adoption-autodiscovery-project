resource "aws_security_group" "stage_sg" {
  name        = "${var.name}stage-sg"
  description = "Allow SSH access"
  vpc_id      = var.vpc_id
  ingress {
    description     = "ssh access from bastion and ansible"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg, var.ansible_sg]
  }
  ingress {
    description     = "application access from load balancer"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.stage_sg_lb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-stage-sg"
  }
}

# import redhat ami
data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat's AWS account ID
  filter {
    name   = "name"
    values = ["RHEL-8.*_HVM-*-x86_64-*-Hourly2-GP2"]
  }
}

resource "aws_launch_template" "stage_template" {
  name          = "${var.name}-stage-launch-template"
  image_id      = data.aws_ami.redhat.id
  instance_type = "t2.medium"
  key_name      = var.key_name
  user_data = base64encode(templatefile("${path.module}/stage_userdata.sh", {
    nr_key = var.nr_key,
    nr_acc_id      = var.nr_acc_id,
    nexus_ip         = var.nexus_ip
  }))
  network_interfaces {
    security_groups = [aws_security_group.stage_sg.id]
  }
}

resource "aws_autoscaling_group" "stage_asg" {
  name = "${var.name}-stage-asg"
  launch_template {
    id      = aws_launch_template.stage_template.id
    version = "$Latest"
  }
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  vpc_zone_identifier = var.private_subnets
  target_group_arns   = [aws_lb_target_group.stage_tg.arn]
  health_check_type   = "EC2"
  force_delete        = true
  tag {
    key                 = "Name"
    value               = "${var.name}-stage-asg"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "asg" {
  name                   = "foo"
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.stage_asg.name
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70
  }
}

resource "aws_security_group" "stage_sg_lb" {
  name        = "${var.name}stage-sg-lb"
  description = "Allow SSH access"
  vpc_id      = var.vpc_id
  ingress {
    description = "application access from load balancer"
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
    Name = "${var.name}-stage-sg-lb"
  }
}

resource "aws_lb" "stage_lb" {
  name                       = "${var.name}-stage-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.stage_sg_lb.id]
  subnets                    = var.public_subnets
  enable_deletion_protection = false
  tags = {
    Name = "${var.name}-stage-lb"
  }
}

resource "aws_lb_target_group" "stage_tg" {
  name     = "${var.name}-stage-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = {
    Name = "${var.name}-stage-tg"
  }
}

resource "aws_lb_listener" "stage_listener" {
  load_balancer_arn = aws_lb.stage_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage_tg.arn
  }
}

# import route53 zone
data "aws_route53_zone" "a" {
  name         = var.domain
  private_zone = false
}

resource "aws_route53_record" "stage_record" {
  zone_id = data.aws_route53_zone.a.zone_id
  name    = "stage.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_lb.stage_lb.dns_name
    zone_id                = aws_lb.stage_lb.zone_id
    evaluate_target_health = true
  }
}

# import ACM certificate
data "aws_acm_certificate" "cert" {
  domain   = var.domain
  statuses = ["ISSUED"]
}