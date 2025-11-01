 locals {
   name = "autodisc-infra"
region = "eu-west-3"
 }



module "vpc" {
  source      = "./module/vpc"
  name        = local.name
  key_name    = "${local.name}-key"
  private_key = "${local.name}-key.pem"
}

module "bastion" {
  source           = "./module/bastion"
  name             = local.name
  key_name         = module.vpc.public_key
  vpc_id           = module.vpc.vpc_id
  subnet           = [module.vpc.public_subnet_ids[0], module.vpc.public_subnet_ids[1]]
  private_key      = module.vpc.private_key_pem
  nr_key = var.nr_key
  nr_acc_id = var.nr_acc_id
  region = var.region
}
