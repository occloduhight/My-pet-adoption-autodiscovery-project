 locals {
  name ="app"
}

data "aws_acm_certificate" "jenkins" {
  domain   = "*.odochidevops.space"
  statuses = ["ISSUED"]
  most_recent = true
}

module "vpc" {
  source      = "./module/vpc"
  name        = local.name
}


# module "vpc" {
# source = "./module/vpc"
# name = local.name
# key_name = "${local.name}-key"
# private_key = "${local.name}-key.pem"
# }

module "bastion" {
  source      = "./module/bastion"
  name        = local.name
  key_name    = module.vpc.public_key
  subnets     = module.vpc.public_subnet_ids
  private_key = module.vpc.private_key
  vpc_id      = module.vpc.vpc_id
  nr_key     = var.nr_key
  nr_acc_id  = var.nr_acc_id
  
}
module "nexus" {
  source      = "./module/nexus"

  name        = local.name
  vpc_id      = module.vpc.vpc_id          # reference to your VPC module
  subnet_id   = module.vpc.public_subnets[0]
  subnet_ids  = module.vpc.public_subnets
  key_name    = module.vpc.key_name
  domain_name = var.domain_name
  nr_key      = var.nr_key
  nr_acc_id   = var.nr_acc_id
}

module "ansible" {
  source = "./module/ansible"

  name             = local.name
  vpc_id           = module.vpc.vpc_id       # from your VPC module
  subnet_id        = module.vpc.public_subnets
  key_name         = module.vpc.key_name
  private_key      = module.vpc.private_key_path
  nr_key           = var.nr_key
  nr_acc_id        = var.nr_acc_id
  s3_bucket_name   = var.s3_bucket_name
  nexus_ip         = module.nexus.nexus_instance_private_ip            # e.g., module.nexus.nexus_instance_private_ip
}
module "prod_sg" {
  source = "./module/prod_sg"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnets    = module.vpc.public_subnets
  private_subnets   = module.vpc.private_subnets
  key_name          = module.vpc.key_name
  bastion_sg        = module.bastion.bastion_sg_id
  ansible_sg        = module.ansible.ansible_sg_id
  nexus_ip          = module.nexus.nexus_instance_private_ip
  nr_key           = var.nr_key
  nr_acc_id        = var.nr_acc_id
  certificate_arn   = var.certificate_arn
  domain_name       = var.domain_name
}


module "stage_asg" {
  source = "./module/stage_asg"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnets    = module.vpc.public_subnets
  private_subnets   = module.vpc.private_subnets
  key_name          = module.vpc.key_name
  bastion_sg        = module.bastion.bastion_sg_id
  ansible_sg        = module.ansible.ansible_sg_id
  nexus_ip          = module.nexus.nexus_instance_private_ip
  nr_key           = var.nr_key
  nr_acc_id        = var.nr_acc_id
  certificate_arn   = var.certificate_arn
  domain_name       = var.domain_name
}

# module "sonar" {
#   source = "./module/sona"

#   name            = local.name
#   vpc_id          = module.vpc.vpc_id
#   public_subnets  = module.vpc.public_subnets
#   subnet_id       = module.vpc.public_subnets[0]
#   key_name        = module.vpc.key_name
#   certificate_arn = var.certificate_arn
#   domain_name     = var.domain_name
# }

module "sonar" {
  source = "./module/sonar"
  name      = local.name
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_ids[1]
   key_name          = module.vpc.key_name
  domain_name = var.domain_name
  public_subnets = [module.vpc.public_subnet_ids[0], module.vpc.public_subnet_ids[1]]
  nr_key           = var.nr_key
  nr_acc_id        = var.nr_acc_id
}

module "database" {
  source = "./module/database"

  name        = local.name
  vpc_id      = module.vpc.vpc_id
  db_subnets  = module.vpc.private_subnets
  stage_sg    = module.stage.stage_sg_id
  prod_sg     = module.prod.prod_sg_id
  db_username = var.db_username
  db_password = var.db_password
}
