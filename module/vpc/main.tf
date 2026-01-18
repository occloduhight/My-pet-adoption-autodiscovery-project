#this block creating a vpc
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name = "${var.name}-vpc"
  }
}

# import available azs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Create public subnets
resource "aws_subnet" "pub-sub1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-pub-subnet-1"
  }
}

resource "aws_subnet" "pub-sub2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-pub-subnet-2"
  }
}
# Create private subnets
resource "aws_subnet" "priv-sub1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-priv-subnet-1"
  }
}

resource "aws_subnet" "priv-sub2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-pri-subnet-2"
  }
}

#  create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.name}-igw"
  }
}

#  this block creates nat gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.pub-sub1.id
  depends_on    = [aws_internet_gateway.igw] # wait for the igw to be created frist before creating resource(nat gateway); 

  tags = {
    Name = "${var.name}-nat"
  }
}
# this blolck creates a EPI(elastic ip) for nat gateway
resource "aws_eip" "eip" {
  domain = "vpc"
}

#  create route table for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name}-public-route-table"
  }
}

resource "aws_route_table_association" "pub-sub1" {
  subnet_id      = aws_subnet.pub-sub1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "pub-sub2" {
  subnet_id      = aws_subnet.pub-sub2.id
  route_table_id = aws_route_table.public_rt.id
}

# create route table for private subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "${var.name}-private-route-table"
  }
}

resource "aws_route_table_association" "priv-sub1" {
  subnet_id      = aws_subnet.priv-sub1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "priv-sub2" {
  subnet_id      = aws_subnet.priv-sub2.id
  route_table_id = aws_route_table.private_rt.id
}

#  this block creates keypair
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.key.private_key_pem
  filename        = "${var.name}-key.pem"
  file_permission = "640"
}

resource "aws_key_pair" "public_key" {
  key_name   = "${var.name}-public_key"
  public_key = tls_private_key.key.public_key_openssh
}
 