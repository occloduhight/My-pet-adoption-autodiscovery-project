# variable "domain" {}
# variable "nr_key" {}
# variable "nr_acc_id" {}
# variable "region" {} 
# variable "name" {}
# variable "az1" {}
# variable "az2" {}
# variable "keypair" {}
# variable "privatekey {}
#  variable "certificate" {}
# # variable "hosted_zone_id" {}
 
 variable "domain" {
  description = "Root domain for Route53 records"
  type        = string
}

variable "nr_key" {
  description = "New Relic license key"
  type        = string
}

variable "nr_acc_id" {
  description = "New Relic account ID"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "name" {
  description = "Project name prefix"
  type        = string
}

variable "az1" {
  description = "Availability zone 1"
  type        = string
}

variable "az2" {
  description = "Availability zone 2"
  type        = string
}

variable "keypair" {
  description = "Name of EC2 key pair"
  type        = string
}

# variable "jenkins_instance_id" {
#   type = string
# }

# variable "privatekey" {
#   description = "Path to private key (.pem)"
#   type        = string
# }

# variable "certificate_arn" {
#   description = "ACM certificate ARN for HTTPS"
#   type        = string
# }

# variable "hosted_zone_id" {
#   description = "Route53 Hosted Zone ID"
#   type        = string
# }
