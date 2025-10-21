variable "name" {
  description = "Project name prefix"
  type        = string
}

variable "vpc" {
  description = "VPC ID"
  type        = string
}

variable "subnets" {
  description = "List of subnet IDs for the Bastion ASG"
  type        = list(string)
}

variable "keypair" {
  description = "EC2 Key Pair name"
  type        = string
}

variable "privatekey" {
  description = "Private key content for userdata"
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

variable "region" {}
