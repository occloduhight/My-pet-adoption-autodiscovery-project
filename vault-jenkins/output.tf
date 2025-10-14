output "jenkins_public_ip" {
  value = aws_instance.jenkins_server.public_ip
}

output "vault_public_ip" {
  value = aws_instance.vault.public_ip
}
output "jenkins_url" {
  description = "URL to access Jenkins through the Load Balancer"
  value       = "https://${aws_elb.elb_jenkins.dns_name}"
}
