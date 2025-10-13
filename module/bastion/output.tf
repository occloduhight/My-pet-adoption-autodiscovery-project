# output "bastion-sg" {
#   value = aws_security_group.bastion-sg.id
# }
# data "aws_instances" "bastion_instances" {
#   filter {
#     name   = "tag:Name"
#     values = ["${var.name}-bastion-asg"]
#   }
#   filter {
#     name   = "instance-state-name"
#     values = ["running"]
#   }
#   depends_on = [aws_autoscaling_group.bastion_asg]
# }
# output "bastion_public_ip" {
#   value       = data.aws_instances.bastion_instances.public_ips[0]
#   description = "The public IP address of the bastion instance"
# }

output "bastion_public_ip" {
  description = "Public IP address of the running Bastion instance"
  value       = try(data.aws_instances.bastion_instances.public_ips[0], null)
}
output "bastion_sg" {
  description = "ID of the Bastion Host Security Group"
  value       = aws_security_group.bastion_sg.id
}