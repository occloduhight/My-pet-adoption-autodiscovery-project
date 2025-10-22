# locals {
#   name = "odochi"
# }

# # Import Jenkins remote state
# data "terraform_remote_state" "vault" {
#   backend = "s3"
#   config = {
#     bucket = "auto-discovery-odo2025"
#     key    = "vault-jenkins/terraform.tfstate"
#     region = "eu-west-3"
#   }
# }
# # VPC Module
# module "vpc" {
#   source = "./module/vpc"

#   name   = local.name
#   region = var.region
#   az1    = var.az1
#   az2    = var.az2
# }

# # ACM Certificate (root module)
# resource "aws_acm_certificate" "acm_cert" {
#   domain_name               = var.domain
#   subject_alternative_names = ["*.${var.domain}"]
#   validation_method         = "DNS"

#   lifecycle {
#     create_before_destroy = true
#   }

#   tags = {
#     Name = "${local.name}-acm-cert"
#   }
# }

# # Lookup Route53 zone
# data "aws_route53_zone" "zone" {
#   name         = var.domain
#   private_zone = false
# }

# # Create DNS validation records
# resource "aws_route53_record" "acm_validation_record" {
#   for_each = {
#     for dvo in aws_acm_certificate.acm_cert.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }

#   zone_id         = data.aws_route53_zone.zone.zone_id
#   allow_overwrite = true
#   name            = each.value.name
#   type            = each.value.type
#   ttl             = 60
#   records         = [each.value.record]

#   depends_on = [aws_acm_certificate.acm_cert]
# }

# # Validate ACM certificate
# resource "aws_acm_certificate_validation" "cert_validation" {
#   certificate_arn         = aws_acm_certificate.acm_cert.arn
#   validation_record_fqdns = [for record in aws_route53_record.acm_validation_record : record.fqdn]

#   depends_on = [aws_route53_record.acm_validation_record]
# }

# # Bastion Module
# module "bastion" {
#   source     = "./module/bastion"
#   name       = local.name
#   vpc        = module.vpc.vpc_id
#   subnets    = [module.vpc.pub_sub1_id, module.vpc.pub_sub2_id]
#   keypair    = module.vpc.public_key
#   privatekey = module.vpc.private_key
#   nr_key     = var.nr_key
#   nr_acc_id  = var.nr_acc_id
#   region     = var.region
# }

# # Nexus Module
# module "nexus" {
#   source = "./module/nexus"

#   name        = local.name
#   vpc         = module.vpc.vpc_id
#   keypair     = module.vpc.public_key
#   subnet_id   = module.vpc.pub_sub2_id
#   subnets     = [module.vpc.pub_sub1_id, module.vpc.pub_sub2_id]
#   certificate = aws_acm_certificate_validation.cert_validation.certificate_arn
#   domain      = var.domain

#   # 👇 Automatically fetch Jenkins instance ID from remote state
#   jenkins_instance_id = data.terraform_remote_state.vault.outputs.jenkins_instance_id
# }

# module "ansible" {
#   source = "./module/ansible"
#   name = local.name
#   # bastion_sg = module.bastion.bastion_sg
#   private_key = module.vpc.private_key
#   keypair = module.vpc.public_key
#   subnet_id = module.vpc.pri_sub1_id
#   nexus_ip = ""
#   vpc = module.vpc.vpc_id
#   nr_acc_id = var.nr_acc_id
#   nr_key = var.nr_key
#   bastion_sg = module.bastion.bastion_sg

# }
# # module "ansible" {
# #   source = "./module/ansible"  # path to your ansible module

# #   name             = var.name
# #   vpc              = var.vpc_id
# #   subnet_id        = var.subnet_id
# #   bastion_sg       = var.bastion_sg
# #   keypair          = var.keypair
# #   ansible_userdata = var.ansible_userdata
# # }

locals {
  name = "odochi"
}

# ---------------------------
# Import Jenkins remote state
# ---------------------------
data "terraform_remote_state" "vault" {
  backend = "s3"
  config = {
    bucket = "auto-discovery-odo2025"
    key    = "vault-jenkins/terraform.tfstate"
    region = "eu-west-3"
  }
}

# ---------------------------
# VPC Module
# ---------------------------
module "vpc" {
  source = "./module/vpc"

  name   = local.name
  region = var.region
  az1    = var.az1
  az2    = var.az2
}

# ---------------------------
# ACM Certificate (root module)
# ---------------------------
resource "aws_acm_certificate" "acm_cert" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name}-acm-cert"
  }
}

data "aws_route53_zone" "zone" {
  name         = var.domain
  private_zone = false
}

resource "aws_route53_record" "acm_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.acm_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.zone.zone_id
  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]

  depends_on = [aws_acm_certificate.acm_cert]
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.acm_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation_record : record.fqdn]

  depends_on = [aws_route53_record.acm_validation_record]
}

# ---------------------------
# Bastion Module
# ---------------------------
module "bastion" {
  source     = "./module/bastion"
  name       = local.name
  vpc        = module.vpc.vpc_id
  subnets    = [module.vpc.pub_sub1_id, module.vpc.pub_sub2_id]
  keypair    = module.vpc.public_key
  privatekey = module.vpc.private_key
  nr_key     = var.nr_key
  nr_acc_id  = var.nr_acc_id
  region     = var.region
}

# ---------------------------
# Nexus Module
# ---------------------------
module "nexus" {
  source = "./module/nexus"

  name        = local.name
  vpc         = module.vpc.vpc_id
  keypair     = module.vpc.public_key
  subnet_id   = module.vpc.pub_sub2_id
  subnets     = [module.vpc.pub_sub1_id, module.vpc.pub_sub2_id]
  certificate = aws_acm_certificate_validation.cert_validation.certificate_arn
  domain      = var.domain

  # Fetch Jenkins instance ID from vault-jenkins remote state
  jenkins_instance_id = data.terraform_remote_state.vault.outputs.jenkins_instance_id
}

# ---------------------------
# Ansible Module
# ---------------------------
module "ansible" {
  source      = "./module/ansible"
  name        = local.name
  private_key = module.vpc.private_key
  keypair     = module.vpc.public_key
  subnet_id   = module.vpc.pri_sub1_id
  nexus_ip    = ""  # Fill if needed
  vpc         = module.vpc.vpc_id
  nr_acc_id   = var.nr_acc_id
  nr_key      = var.nr_key
  bastion_sg  = module.bastion.bastion_sg
}
