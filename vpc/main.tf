# Create VPC
resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "${var.name}-vpc"
  }
}

# Public Subnet 1
resource "aws_subnet" "pub_sub1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.az1

  tags = {
    Name = "${var.name}-pub_sub1"
  }
}

# Public Subnet 2
resource "aws_subnet" "pub_sub2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.az2

  tags = {
    Name = "${var.name}-pub_sub2"
  }
}

# Private Subnet 1
resource "aws_subnet" "pri_sub1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.az1

  tags = {
    Name = "${var.name}-pri_sub1"
  }
}

# Private Subnet 2
resource "aws_subnet" "pri_sub2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.az2

  tags = {
    Name = "${var.name}-pri_sub2"
  }
}
# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.name}-igw"
  }
}

# Elastic IP for NAT
resource "aws_eip" "eip" {
  domain = "vpc"

  tags = {
    Name = "${var.name}-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.pub_sub1.id

  tags = {
    Name = "${var.name}-ngw"
  }

  depends_on = [aws_eip.eip]
}

# Route Tables
# Public Route Table
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name}-pub_rt"
  }
}

# Private Route Table
resource "aws_route_table" "pri_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "${var.name}-pri_rt"
  }
}


# Route Table Associations

# Public
resource "aws_route_table_association" "ass-public_subnet_1" {
  subnet_id      = aws_subnet.pub_sub1.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_route_table_association" "ass-public_subnet_2" {
  subnet_id      = aws_subnet.pub_sub2.id
  route_table_id = aws_route_table.pub_rt.id
}

# Private
resource "aws_route_table_association" "ass-private_subnet_1" {
  subnet_id      = aws_subnet.pri_sub1.id
  route_table_id = aws_route_table.pri_rt.id
}

resource "aws_route_table_association" "ass-private_subnet_2" {
  subnet_id      = aws_subnet.pri_sub2.id
  route_table_id = aws_route_table.pri_rt.id
}
# Key Pair

# Generate RSA Private Key
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save Private Key locally
resource "local_file" "private-key" {
  content         = tls_private_key.key.private_key_pem
  filename        = "${var.name}-key.pem"
  file_permission = 440
}

# Create AWS Key Pair
resource "aws_key_pair" "public-key" {
  key_name   = "${var.name}-infra-key"
  public_key = tls_private_key.key.public_key_openssh
}
