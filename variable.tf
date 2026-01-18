variable "nr_key" {}
variable "nr_acc_id" {}
variable "domain_name" {
  description = "The domain name for SSL certificate or service endpoint"
  type        = string
}
variable "s3_bucket_name" {
  description = "The name of the S3 bucket for Ansible scripts"
  type        = string
}

variable "certificate_arn" {
  description = "Wildcard ACM certificate ARN for *.odochidevops.space"
  default     = "arn:aws:acm:eu-west-3:015937138823:certificate/6fd8d6eb-dd5f-493f-89c9-ac911fdf063a"
}

variable "db_username" {}
variable "db_password" {}

variable "vault_token" {}
