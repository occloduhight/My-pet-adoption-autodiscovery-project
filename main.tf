locals {
  name = "odochi"
}
module "vpc" {
  source = "./module/vpc"
  name   = local.name
}

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

module "bastion" {
  source     = "./module/bastion"
  name       = local.name
  vpc        = module.vpc.vpc_id
  subnets    = [module.vpc.public_subnet_1_id, module.vpc.public_subnet_2_id]
  keypair    = module.vpc.public_key
  privatekey = module.vpc.private_key
  nr-acc-id  = var.nr-acc-id
  nr-key     = var.nr-key
}

module "ansible" {
  source      = "./module/ansible"
  name        = local.name
  keypair     = module.vpc.public_key
  subnet_id   = module.vpc.pri_sub1_id
  vpc         = module.vpc.vpc_id
  bastion_key     = module.bastion.bastion-sg
  private-key = module.vpc.private_key
  nexus-ip    = module.nexus.nexus_ip
  nr-key      = var.nr-key
  nr-acc-id   = var.nr-acc-id
}

module "nexus" {
  source         = "./module/nexus"
  name           = local.name
  vpc            = module.vpc.vpc_id
  keypair        = module.vpc.public_key
  subnet_id      = module.vpc.public_subnet_1_id
  subnets        = module.vpc.public_subnet_1_id
  certificate    = data.aws_acm_certificate.cert.arn
  hosted_zone_id = data.aws_route53_zone.zone.id
  domain_name    = var.domain_name
}