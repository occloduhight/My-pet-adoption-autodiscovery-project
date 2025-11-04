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

module "sonarqube" {
  source           = "./module/sonarqube"
  subnet           = module.vpc.public_subnet_ids[1]
  name             = local.name
  key_name         = module.vpc.public_key
  vpc_id           = module.vpc.vpc_id
  nr_key = var.nr_key
  nr_acc_id    = var.nr_acc_id
  subnets_elb      = [module.vpc.public_subnet_ids[0], module.vpc.public_subnet_ids[1]]
  domain      = var.domain
}

module "nexus" {
  source           = "./module/nexus"
  name             = local.name
  subnet           = module.vpc.public_subnet_ids[0]
  key_name         = module.vpc.public_key
  vpc_id           = module.vpc.vpc_id
 nr_key = var.nr_key
  nr_acc_id    = var.nr_acc_id
  subnets_elb      = [module.vpc.public_subnet_ids[0], module.vpc.public_subnet_ids[1]]
  domain     = var.domain
  region           = local.region
   private_key_pem = module.vpc.private_key_pem
}


module "ansible" {
  source      = "./module/ansible"
  name        = local.name
  subnet      = module.vpc.private_subnet_ids[0]
  key_name    = module.vpc.public_key
  vpc_id      = module.vpc.vpc_id
  private_key = module.vpc.private_key_pem
  bastion_sg  = module.bastion.bastion_sg
  nexus_ip    = module.nexus.nexus_ip
  s3_bucket   = "auto-discovery-odo2025"
}

module "database" {
  source      = "./module/database"
  name        = local.name
  db_subnets  = [module.vpc.private_subnet_ids[0], module.vpc.private_subnet_ids[1]]
  vpc_id      = module.vpc.vpc_id
  stage_sg    = module.prod.prod_sg
  prod_sg     = module.stage.stage_sg
  db_username = data.vault_generic_secret.database.data["username"]
  db_password = data.vault_generic_secret.database.data["password"]
}


