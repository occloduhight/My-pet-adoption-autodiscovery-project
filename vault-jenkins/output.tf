output "jenkins_public_ip" {
  description = "Public IP address of the Jenkins EC2 instance"
  value       = aws_instance.jenkins_server.public_ip
}

output "vault_public_ip" {
  description = "Public IP address of the Vault EC2 instance"
  value       = aws_instance.vault.public_ip
}

output "certificate_arn" {
  description = "ARN of the validated ACM certificate for the domain"
  value       = aws_acm_certificate_validation.cert_validation.certificate_arn
}

output "hosted_zone_id" {
  description = "ID of the Route53 hosted zone associated with the domain"
  value       = data.aws_route53_zone.zone.id
}
