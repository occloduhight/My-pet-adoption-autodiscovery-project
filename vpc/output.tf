output "vpc_id" { value = aws_vpc.vpc.id }
output "public_subnets" { value = [aws_subnet.pub_sub1.id, aws_subnet.pub_sub2.id] }
output "private_subnets" { value = [aws_subnet.pri_sub1.id, aws_subnet.pri_sub2.id] }
output "internet_gateway_id" { value = aws_internet_gateway.igw.id }
output "nat_gateway_id" { value = aws_nat_gateway.ngw.id }
