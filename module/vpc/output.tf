output "vpc_id" {
  value = aws_vpc.main.id
}
output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
output "public_key" {
  value = aws_key_pair.key.id
}
output "private_key_pem" {
  value = tls_private_key.deployer.private_key_pem
}