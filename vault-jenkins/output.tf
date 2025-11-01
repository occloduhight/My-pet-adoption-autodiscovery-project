
output "subnet_ids" {
  value = [aws_subnet.pub_sub.id]
}

output "vault_server_ip" {
  description = "Public IP of the Vault server"
  value       = aws_instance.vault_server.public_ip
}

output "jenkins_server_ip" {
  description = "Public IP of the Jenkins server"
  value       = aws_instance.jenkins_server.public_ip
}

output "ssh_key_name" {
  description = "Name of the SSH key pair"
  value       = aws_key_pair.public_key.key_name
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.vpc.id
}