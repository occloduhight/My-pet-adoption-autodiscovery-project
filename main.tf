locals {
  name = "autodiscovery-odochi2025"
}

# data "aws_acm_certificate" "jenkins" {
#   domain       = var.domain
#   most_recent  = true
#   statuses     = ["ISSUED"]
# }
# Look up the public hosted zone for your domain
# data "aws_route53_zone" "zone" {
#   name         = var.domain
#   private_zone = false
# }

# # Look up the most recent ACM certificate for your domain
# data "aws_acm_certificate" "cert" {
#   domain      = var.domain
#   statuses    = ["ISSUED"]       # <– ensures only issued certs are returned
#   types       = ["AMAZON_ISSUED"]
#   most_recent = true
# }

# Call the VPC module
module "vpc" {
  source = "./vpc"

  name = var.name
  region = var.region
  az1 = var.az1
  az2 = var.az2
}