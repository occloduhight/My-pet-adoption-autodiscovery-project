output "docker_host_public_ip" {
  description = "Public IP of the Docker host instance"
  value       = aws_instance.docker_host.public_ip
}
