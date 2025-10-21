variable "domain" {}
variable "nr_key" {}
variable "nr_acc_id" {}
variable "region" {}
  
variable "name" {
  description = "Project name prefix"
  type        = string
  default     = "odochi"
}


variable "az1" {
  description = "Availability Zone 1"
  type        = string
  default     = "eu-west-3a"
}

variable "az2" {
  description = "Availability Zone 2"
  type        = string
  default     = "eu-west-3b"
}
