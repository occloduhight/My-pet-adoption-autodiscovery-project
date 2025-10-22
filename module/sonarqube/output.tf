output "sonarqube-ip" {
  value = aws_instance.sonarqube_server.public_ip
}