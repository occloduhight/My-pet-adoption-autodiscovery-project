locals {
  name = "team-1"
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


