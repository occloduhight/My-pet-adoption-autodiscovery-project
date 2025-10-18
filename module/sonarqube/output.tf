output "sonarqube_instance_public_ip" {
  description = "Public IP of the SonarQube instance"
  value       = aws_instance.sonarqube-server.public_ip
}