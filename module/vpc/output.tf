output "vpc_id" {
  value = aws_vpc.vpc.id
}
output "public_subnet_ids" {
  value = [aws_subnet.pub-sub1.id, aws_subnet.pub-sub2.id]
}
output "private_subnet_ids" {
  value = [aws_subnet.priv-sub1.id, aws_subnet.priv-sub2.id]
}
output "keypair_name" {
  value = aws_key_pair.public_key.key_name
}
output "private_key" {
  value = tls_private_key.key.private_key_pem
}