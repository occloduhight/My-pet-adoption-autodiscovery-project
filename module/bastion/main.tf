# Bastion Security Group
resource "aws_security_group" "bastion_sg" {
  name        = "${var.name}-bastion-sg"
  description = "Allow only outbound traffic"
  vpc_id      = var.vpc

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-bastion-sg" }
}

# IAM Role for SSM
resource "aws_iam_role" "bastion_ssm_role" {
  name = "${var.name}-bastion-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.bastion_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion_ssm_profile" {
  name = "${var.name}-bastion-ssm-profile"
  role = aws_iam_role.bastion_ssm_role.name
}

# Get the latest Red Hat AMI
data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat official owner
  filter {
    name   = "name"
    values = ["RHEL-9.*x86_64*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Launch Template
resource "aws_launch_template" "bastion_lt" {
  name_prefix   = "${var.name}-bastion-"
  image_id      = data.aws_ami.redhat.id
  instance_type = "t2.micro"
  key_name      = var.keypair

  iam_instance_profile { name = aws_iam_instance_profile.bastion_ssm_profile.name }

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_security_group.bastion_sg.id]
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    privatekey = var.privatekey,
    nr_key     = var.nr_key,
    nr_acc_id  = var.nr_acc_id,
    region     = var.region
  }))

  tags = { Name = "${var.name}-bastion" }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "bastion_asg" {
  name                      = "${var.name}-bastion-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 120
  health_check_type         = "EC2"
  force_delete              = true

  launch_template {
    id      = aws_launch_template.bastion_lt.id
    version = "$Latest"
  }

  vpc_zone_identifier = var.subnets

  tag {
    key                 = "Name"
    value               = "${var.name}-bastion-asg"
    propagate_at_launch = true
  }
}

# ASG Scaling Policy
resource "aws_autoscaling_policy" "bastion_asg_policy" {
  name                   = "${var.name}-bastion-asg-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.bastion_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}
