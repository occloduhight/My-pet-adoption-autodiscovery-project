output "bastion_asg_name" {
  description = "Bastion ASG Name"
  value       = aws_autoscaling_group.bastion_asg.name
}

# output "bastion_sg_id" {
#   description = "Bastion Security Group ID"
#   value       = aws_security_group.bastion_sg.id
# }

output "bastion_iam_instance_profile" {
  description = "Bastion IAM instance profile name"
  value       = aws_iam_instance_profile.bastion_ssm_profile.name
}
output "bastion_sg" {
  description = "Security group ID of the bastion host"
  value       = aws_security_group.bastion_sg.id
}

