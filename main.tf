locals {
  name = "odochi"
}

data "aws_route53_zone" "zone" {
  name         = var.domain_name
  private_zone = false

}
#calling acm certificate
data "aws_acm_certificate" "cert" {
  domain      = var.domain_name
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

# # Fetch existing public Route53 hosted zone
# data "aws_route53_zone" "zone" {
#   name         = var.domain_name  
#   private_zone = false
# }

# module "bastion" {
#   source     = "./module/bastion"
#   name       = local.name
#   vpc        = module.vpc.vpc_id
#   subnets    = [module.vpc.pub_sub1_id, module.vpc.pub_sub2_id]
#   keypair    = module.vpc.public_key
#   privatekey = module.vpc.private_key
#   nr-acc-id  = var.nr_acc_id
#   nr-key     = var.nr_key
# }

module "vpc" {
  source = "./module/vpc"
  name   = local.name
}

module "bastion" {
  source     = "./module/bastion"
  name       = local.name
  vpc        = module.vpc.vpc_id
  subnets    = [module.vpc.pub_sub1_id, module.vpc.pub_sub2_id]
  keypair    = module.vpc.public_key
  privatekey = module.vpc.private_key
  nr-acc-id  = var.nr_acc_id
  nr-key     = var.nr_key
  # bastion_key = module.bastion.bastion_sg_id

}

module "ansible" {
  source      = "./module/ansible"
  name        = local.name
  keypair     = module.vpc.public_key
  subnet_id   = module.vpc.pri_sub1_id
  vpc         = module.vpc.vpc_id
  bastion_key     = module.bastion.bastion_sg_id
  private-key = module.vpc.private_key
  nexus-ip    = module.nexus.nexus_ip
  nr-key      = var.nr_key
  nr-acc-id   = var.nr_acc_id
}

# module "nexus" {
#   source         = "./module/nexus"
#   name           = local.name
#   vpc            = module.vpc.vpc_id
#   keypair        = module.vpc.public_key
#   subnet_id      = module.vpc.pub_sub1_id
#   subnets   = [module.vpc.pub_sub1_id, module.vpc.pub_sub2_id]
#   # certificate    = data.aws_acm_certificate.cert.arn
#   domain_name    = var.domain_name
#   hosted_zone_id = data.aws_route53_zone.zone.id
# }
module "nexus" {
  source         = "./module/nexus"
  name           = local.name
  vpc            = module.vpc.vpc_id
  keypair        = module.vpc.public_key
  subnet_id      = module.vpc.pub_sub1_id
  subnets        = module.vpc.pub_sub1_id
  certificate    = data.aws_acm_certificate.cert.arn
  hosted_zone_id = data.aws_route53_zone.zone.id
  domain_name    = var.domain_name
}