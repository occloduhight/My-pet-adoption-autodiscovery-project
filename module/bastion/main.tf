# Security Group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  name        = "${var.name}-bastion-sg"
  description =  "Allow only outbound traffic"
  vpc_id      = var.vpc

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

# Create IAM role for SSM
resource "aws_iam_role" "bastion_ssm_role" {
  name = "${var.name}-bastion-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}
# Attach SSM Core Policy for Session Manager Access
resource "aws_iam_role_policy_attachment" "bastion_ssm_core" {
  role       = aws_iam_role.bastion_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# create IAM instance profile
resource "aws_iam_instance_profile" "bastion_ssm_profile" {
  name = "bastion-ssm-profile"
  role = aws_iam_role.bastion_ssm_role.name
}

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

# Create Bastion Launch Template
resource "aws_launch_template" "bastion_lt" {
  name_prefix   = "${var.name}-bastion-"
  image_id      = data.aws_ami.redhat.id
  instance_type = "t2.micro"
  key_name      = var.keypair

   iam_instance_profile {
    name = aws_iam_instance_profile.bastion_ssm_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_security_group.bastion_sg.id]
  }

  user_data = base64encode(templatefile("./module/bastion/userdata.sh", {
    privatekey = "bastion-key.pem",
    nr-key     = "YOUR_NEWRELIC_LICENSE_KEY",
    nr-acc-id  = "YOUR_NEWRELIC_ACCOUNT_ID",
    region     = "eu-west-3"
  }))

  tags = {
    Name = "${var.name}-bastion"
  }
}

# resource "aws_instance" "bastion" {
#   ami                    = data.aws_ami.redhat.id
#   instance_type          = "t2.micro"
#   key_name               = var.key_name
#   subnet_id              = var.public_subnet
#   vpc_security_group_ids = [aws_security_group.bastion_sg.id]
#   iam_instance_profile   = aws_iam_instance_profile.bastion_instance_profile.name
#   associate_public_ip_address = true

#    network_interfaces {
#     associate_public_ip_address = true
#     delete_on_termination       = true
#     security_groups             = [aws_security_group.bastion_sg.id]
#   }

#   user_data = base64encode(templatefile("./module/bastion/userdata.sh", {
#     privatekey = "bastion-key.pem",
#     nr-key     = "YOUR_NEWRELIC_LICENSE_KEY",
#     nr-acc-id  = "YOUR_NEWRELIC_ACCOUNT_ID",
#     region     = "eu-west-3"
#   }))
# tags = {
#     Name = "${var.name}-bastion"
#   }
# }
  


# Create Auto Scaling Group for Bastion
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
# Creat ASG policy for Baston Host
# Auto Scaling Policy for Bastion
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