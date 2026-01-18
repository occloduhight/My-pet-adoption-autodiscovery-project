# Security Group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  name        = "${var.name}-bastion-sg"
  description = "Security group for Bastion Host"
  vpc_id = var.vpc_id

  # Allow only outbound access to private instances
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "${var.name}-bastion-sg"
  }
}

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

# Autoscaling policy
resource "aws_autoscaling_policy" "bastion_asg_policy" {
  name                   = "${var.name}-bastion-asg-policy"
  autoscaling_group_name = aws_autoscaling_group.bastion_asg.name
  policy_type            = "TargetTrackingScaling"
  adjustment_type        = "ChangeInCapacity"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70
  }
}

# Bastion IAM role
resource "aws_iam_role" "bastion_role" {
  name = "${var.name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
      }
    ]
  })
}

# Attach  AmazonSSMManaged policy to bastion IAM role
resource "aws_iam_role_policy_attachment" "bastion_ssm_attach" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create instance profile for  bastionEC2
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.name}-bastion-profile"
  role = aws_iam_role.bastion_role.name
}

# Launch template
resource "aws_launch_template" "bastion_lt" {
  name_prefix   = "${var.name}-bastion-lt"
  image_id      = data.aws_ami.ubuntu.id
  key_name      = var.key_name
  instance_type = "t2.micro"
  iam_instance_profile {
    name = aws_iam_instance_profile.bastion_profile.name
  }
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    private_key = var.private_key
  }))
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.bastion_sg.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name}-bastion-lt"
    }
  }
}
# Autoscaling group
resource "aws_autoscaling_group" "bastion_asg" {
  name                      = "${var.name}-bastion-asg"
  desired_capacity          = 1
  max_size                  = 3
  min_size                  = 1
  vpc_zone_identifier       = var.subnets
  health_check_grace_period = 120
  health_check_type         = "EC2"
  force_delete              = true
  launch_template {
    id      = aws_launch_template.bastion_lt.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "${var.name}-bastion-asg"
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Autoscaling policy
resource "aws_autoscaling_policy" "bastion_asg_policy" {
  name                   = "${var.name}-bastion-asg-policy"
  autoscaling_group_name = aws_autoscaling_group.bastion_asg.name
  policy_type            = "TargetTrackingScaling"
  adjustment_type        = "ChangeInCapacity"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70
  }
}
