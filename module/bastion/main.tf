resource "aws_security_group" "bastion_sg" {
  name        = "${var.name}bastion-sg"
  description = "Allow SSH access"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-bastion-sg"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_iam_role" "bastion_role" {
  name = "${var.name}-bastion-role"
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

# Attach SSM managed policy to the Jenkins role
resource "aws_iam_role_policy_attachment" "ssm_role_attachment" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create Instance Profile for Jenkins EC2
resource "aws_iam_instance_profile" "bastion_instance_profile" {
  name = "${var.name}-bastion-instance-profile"
  role = aws_iam_role.bastion_role.name
}

resource "aws_launch_template" "bastion_template" {
  name          = "bastion-launch-template"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = var.key_name
  iam_instance_profile {
    name = aws_iam_instance_profile.bastion_instance_profile.id
  }
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    private_key      = var.private_key,
    nr_key = var.nr_key,
    nr_acc_id      = var.nr_acc_id
  }))
  network_interfaces {
    security_groups = [aws_security_group.bastion_sg.id]
  }
}

resource "aws_autoscaling_group" "bastion_asg" {
  name = "${var.name}-bastion-asg"
  launch_template {
    id      = aws_launch_template.bastion_template.id
    version = "$Latest"
  }
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  vpc_zone_identifier = var.subnet
  health_check_type   = "EC2"
  force_delete        = true
  tag {
    key                 = "Name"
    value               = "${var.name}-bastion-asg"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "asg" {
  name                   = "${var.name}-bastion-asg-policy"
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.bastion_asg.name
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70
  }
}