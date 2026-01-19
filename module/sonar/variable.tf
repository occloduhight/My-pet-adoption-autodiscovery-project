variable "name" {}
variable "vpc_id" {}
variable "subnet_id" {}
variable "key_name" {}
variable "domain_name" {}
variable "public_subnets" {}
variable "nr_key" {}
variable "nr_acc_id" {}
variable "certificate_arn" {
  type        = string
  description = "ARN of the ACM certificate"
  default     = "arn:aws:acm:eu-west-3:015937138823:certificate/6fd8d6eb-dd5f-493f-89c9-ac911fdf063a"
}
