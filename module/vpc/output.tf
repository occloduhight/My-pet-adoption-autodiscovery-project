output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "pub_sub1_id" {
  value = aws_subnet.pub_sub1.id
}

output "pub_sub2_id" {
  value = aws_subnet.pub_sub2.id
}

output "pri_sub1_id" {
  value = aws_subnet.pri_sub1.id
}
output "pri_sub2_id" {
  value = aws_subnet.pri_sub2.id
}

output "public_key" {
  value = aws_key_pair.public-key.key_name
}

output "private_key" {
  value = tls_private_key.key.private_key_pem
}

output "vpc_cidr_block" {
  value = aws_vpc.vpc.cidr_block
}