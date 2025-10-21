# variable "name" {}
# variable "vpc" {}
# variable "subnets" { type = list(string) }
# variable "subnet_id" {}
# variable "keypair" {}
# # variable "certificate" {}
# variable "hosted_zone_id" {}
# variable "domain" {}

variable "name" {}
variable "vpc" {}
variable "keypair" {}
variable "subnet_id" {}
variable "certificate" {}
variable "domain" {}
variable "subnets" {}
# variable "jenkins_instance_id" {}
  variable "jenkins_instance_id" {
  description = "ID of the Jenkins instance to run Docker config on"
  type        = string
}
