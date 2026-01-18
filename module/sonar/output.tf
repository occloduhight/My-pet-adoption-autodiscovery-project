output "sonar-ip" {
  value = aws_instance.sonar_server.public_ip
}