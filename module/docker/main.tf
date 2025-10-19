resource "aws_security_group" "docker_host_sg" {
  name        = "${var.name}-docker-sg"
  description = "Allow SSH and Docker registry traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Docker registry (HTTP/HTTPS)"
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
    Name = "${var.name}-docker-sg"
  }
}

resource "aws_instance" "docker_host" {
  ami                    = data.aws_ami.redhat.id
  instance_type          = "t2.medium"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.docker_host_sg.id]
  key_name               = var.keypair

 user_data = templatefile("${path.module}/docker_userdata.sh", {
  nexus_ip   = var.nexus_ip
  nr_key     = var.nr_key
  nr_acc_id  = var.nr_acc_id
})

  tags = {
    Name = "${var.name}-docker-host"
  }
}

data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat official owner ID

  filter {
    name   = "name"
    values = ["RHEL-8.*x86_64*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
