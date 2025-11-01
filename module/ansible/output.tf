output "ansible_ip" {
  value = aws_instance.ansible_server.private_ip
}
output "ansible_sg" {
  value = aws_security_group.ansible_sg.id
}