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
# # VPC Module
# module "vpc" {
#   source     = "./module/vpc"
#   name       = local.name
#   key_name   = "${local.name}-key"
#   private_key = "${local.name}-key.pem"
# }

# Bastion Module
module "bastion" {
  source      = "./module/bastion"
  name        = local.name
  key_name    = module.vpc.keypair_name             # Correct VPC output
  # subnet_id   = module.vpc.public_subnet_ids[0]    # First public subnet
  subnets     = module.vpc.public_subnet_ids
  private_key = module.vpc.private_key             # Correct VPC output
  vpc_id      = module.vpc.vpc_id
  nr_key      = var.nr_key
  nr_acc_id   = var.nr_acc_id
}

# Nexus Module
module "nexus" {
  source      = "./module/nexus"
  name        = local.name
  vpc_id      = module.vpc.vpc_id
  subnet_id   = module.vpc.public_subnet_ids[0]
  subnet_ids  = module.vpc.public_subnet_ids
  key_name    = module.vpc.keypair_name
  domain_name = var.domain_name
  nr_key      = var.nr_key
  nr_acc_id   = var.nr_acc_id
  certificate_arn = var.certificate_arn 
}

# Ansible Module
module "ansible" {
  source        = "./module/ansible"
  name          = local.name
  vpc_id        = module.vpc.vpc_id
  # subnet_id     = module.vpc.public_subnet_ids[0]
  subnet_id = module.vpc.public_subnet_ids
  key_name      = module.vpc.keypair_name
  private_key   = module.vpc.private_key
  nr_key        = var.nr_key
  nr_acc_id     = var.nr_acc_id
  s3_bucket_name = var.s3_bucket_name
  nexus_ip            = module.nexus.nexus_ip
}

# Prod ASG Module
module "prod_asg" {
  source         = "./module/prod_asg"
  name           = local.name
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnet_ids
  private_subnets = module.vpc.private_subnet_ids
  key            = module.vpc.keypair_name
  bastion_sg     = module.bastion.bastion_sg
  ansible_sg     = module.ansible.ansible_sg
  nr_key         = var.nr_key
  nr_acc_id      = var.nr_acc_id
  certificate_arn = var.certificate_arn
  domain_name     = var.domain_name
}

# Stage ASG Module
module "stage_asg" {
  source         = "./module/stage_asg"
  name           = local.name
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnet_ids
  private_subnets = module.vpc.private_subnet_ids
  key_name       = module.vpc.keypair_name
  bastion_sg     = module.bastion.bastion_sg
  ansible_sg     = module.ansible.ansible_sg
 nexus_ip            = module.nexus.nexus_ip
  nr_key         = var.nr_key
  nr_acc_id      = var.nr_acc_id
  certificate_arn = var.certificate_arn
  domain_name     = var.domain_name
}

# Sonar Module
module "sonar" {
  source         = "./module/sonar"
  name           = local.name
  vpc_id         = module.vpc.vpc_id
  key_name       = module.vpc.keypair_name
  subnet_id      = module.vpc.public_subnet_ids[0]
  public_subnets = module.vpc.public_subnet_ids
  nr_key         = var.nr_key
  nr_acc_id      = var.nr_acc_id
  domain_name    = var.domain_name
  # certificate_arn = var.certificate_arn 
}

# Database Module
module "database" {
  source      = "./module/database"
  name        = local.name
  vpc_id      = module.vpc.vpc_id
  db_subnets  = module.vpc.private_subnet_ids
  stage_sg    = module.stage_asg.stage_sg
  prod_sg     = module.prod_asg.prod_sg
  db_username = var.db_username
  db_password = var.db_password
}


# # module "vpc" {
# # source = "./module/vpc"
# # name = local.name
# # key_name = "${local.name}-key"
# # private_key = "${local.name}-key.pem"
# # }

# # module "bastion" {
# #   source      = "./module/bastion"
# #   name        = local.name
# #   key_name    = module.vpc.public_key
# #    subnet_id = module.vpc.public_subnet_ids[0]
# #   subnets     = module.vpc.public_subnet_ids
# #   private_key = module.vpc.private_key
# #   vpc_id      = module.vpc.vpc_id
# #   nr_key     = var.nr_key
# #   nr_acc_id  = var.nr_acc_id
  
# # }

# module "bastion" {
#   source      = "./module/bastion"
#   name        = local.name
#   key_name    = module.vpc.keypair_name         # <--- fixed
#   # subnet_id   = module.vpc.public_subnet_ids[0]
#   subnets     = module.vpc.public_subnet_ids
#   private_key = module.vpc.private_key         # <--- already correct
#   vpc_id      = module.vpc.vpc_id
#   nr_key      = var.nr_key
#   nr_acc_id   = var.nr_acc_id
# }

# module "nexus" {
#   source      = "./module/nexus"

#   name        = local.name
#   vpc_id      = module.vpc.vpc_id          # reference to your VPC module
#   subnet_id   = module.vpc.public_subnets[0]
#   subnet_ids  = module.vpc.public_subnets
#   # key_name    = module.vpc.key_name
#     key_name   = module.vpc.keypair_name
#   domain_name = var.domain_name
#   nr_key      = var.nr_key
#   nr_acc_id   = var.nr_acc_id
# }

# module "ansible" {
#   source = "./module/ansible"

#   name             = local.name
#   vpc_id           = module.vpc.vpc_id       # from your VPC module
#   subnet_id        = module.vpc.public_subnets
#   # key_name         = module.vpc.key_name
#     key_name   = module.vpc.keypair_name
#   private_key      = module.vpc.private_key_path
#   nr_key           = var.nr_key
#   nr_acc_id        = var.nr_acc_id
#   s3_bucket_name   = var.s3_bucket_name
#   nexus_ip         = module.nexus.nexus_instance_private_ip            # e.g., module.nexus.nexus_instance_private_ip
# }
# # module "prod_asg" {
# #   source = "./module/prod_asg"

# #   name              = local.name
# #   vpc_id            = module.vpc.vpc_id
# #   public_subnets    = module.vpc.public_subnets
# #   private_subnets   = module.vpc.private_subnets
# #   key_name          = module.vpc.key_name
# #   bastion_sg        = module.bastion.bastion_sg_id
# #   ansible_sg        = module.ansible.ansible_sg_id
# #   nexus_ip          = module.nexus.nexus_instance_private_ip
# #   nr_key           = var.nr_key
# #   nr_acc_id        = var.nr_acc_id
# #   certificate_arn   = var.certificate_arn
# #   domain      = var.domain_name
# # }

# module "prod_asg" {
#   source = "./module/prod_asg"

#   name             = local.name
#   vpc_id           = module.vpc.vpc_id
#   public_subnets   = module.vpc.public_subnets
#   private_subnets  = module.vpc.private_subnets
#   # key              = module.vpc.key_name
#   key             = module.vpc.keypair_name
#   bastion_sg       = module.bastion.bastion_sg_id
#   ansible_sg       = module.ansible.ansible_sg_id
#   nr_key           = var.nr_key
#   nr_acc_id        = var.nr_acc_id
#   certificate_arn  = var.certificate_arn
#   domain_name           = var.domain_name
# }

# module "stage_asg" {
#   source = "./module/stage_asg"

#   name              = local.name
#   vpc_id            = module.vpc.vpc_id
#   public_subnets    = module.vpc.public_subnets
#   private_subnets   = module.vpc.private_subnets
#    key_name          = module.vpc.key_name
#   # key             = module.vpc.keypair_name
#   bastion_sg        = module.bastion.bastion_sg_id
#   ansible_sg        = module.ansible.ansible_sg_id
#   nexus_ip          = module.nexus.nexus_instance_private_ip
#   nr_key           = var.nr_key
#   nr_acc_id        = var.nr_acc_id
#   certificate_arn   = var.certificate_arn
#   domain_name       = var.domain_name
# }

# # module "sonar" {
# #   source = "./module/sona"

# #   name            = local.name
# #   vpc_id          = module.vpc.vpc_id
# #   public_subnets  = module.vpc.public_subnets
# #   subnet_id       = module.vpc.public_subnets[0]
# #   key_name        = module.vpc.key_name
# #   certificate_arn = var.certificate_arn
# #   domain_name     = var.domain_name
# # }

# # module "sonar" {
# #   source = "./module/sonar"
# #   name      = local.name
# #   vpc_id    = module.vpc.vpc_id
# #   subnet_id = module.vpc.public_subnet_ids[1]
# #   #  key_name          = module.vpc.key_name
# #   key_name  = module.vpc.keypair_name 
# #   domain_name = var.domain_name
# #   public_subnets = [module.vpc.public_subnet_ids[0], module.vpc.public_subnet_ids[1]]
# #   nr_key           = var.nr_key
# #   nr_acc_id        = var.nr_acc_id
# # }
# module "sonar" {
#   source         = "./module/sonar"
#   name           = local.name
#   vpc_id         = module.vpc.vpc_id
#   key_name       = module.vpc.keypair_name
#   subnet_id      = module.vpc.public_subnet_ids[0]
#   public_subnets = module.vpc.public_subnet_ids
#   nr_key         = var.nr_key
#   nr_acc_id      = var.nr_acc_id
#   domain_name    = var.domain_name
# }

# # module "database" {
# #   source = "./module/database"

# #   name        = local.name
# #   vpc_id      = module.vpc.vpc_id
# #   db_subnets  = module.vpc.private_subnets
# #   stage_asg    = module.stage.stage_asg_id
# #   prod_asg     = module.prod.prod_asg_id
# #   db_username = var.db_username
# #   db_password = var.db_password
# # }
# # ==========================
# module "database" {
#   source = "./module/database"

#   name        = local.name           # Project prefix
#   vpc_id      = module.vpc.vpc_id    # VPC ID from VPC module
#   db_subnets  = module.vpc.private_subnet_ids  # Private subnets for RDS
#   stage_sg    = module.stage_asg.stage_sg_id   # Stage ASG security group
#   prod_sg     = module.prod_asg.prod_sg_id     # Prod ASG security group

#   db_username = var.db_username      # Database username
#   db_password = var.db_password      # Database password
# }