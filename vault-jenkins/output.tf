output "jenkins_public_ip" {
  value = aws_instance.jenkins_server.public_ip
}

output "vault_public_ip" {
  value = aws_instance.vault_server.public_ip
}

output "jenkins_elb_dns" {
  value = aws_elb.elb_jenkins.dns_name
}

output "vault_elb_dns" {
  value = aws_elb.vault_elb.dns_name
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.acm_cert.arn
}
