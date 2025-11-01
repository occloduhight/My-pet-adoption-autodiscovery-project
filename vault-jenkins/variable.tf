variable "domain" {
  default = "odochidevops.space"
}
variable "region" {
  default = "eu-west-3"
}
variable "nr_key" {}
variable "nr_acc_id" {}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS connections"
  default     = "arn:aws:acm:eu-west-3:015937138823:certificate/6fd8d6eb-dd5f-493f-89c9-ac911fdf063a"
}

