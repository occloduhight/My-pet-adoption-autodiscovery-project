locals {
  name = "odochi"
}

data "aws_route53_zone" "zone" {
  name         = var.domain_name
  private_zone = false

}
# #calling acm certificate
# data "aws_acm_certificate" "cert" {
#   domain      = "odochidevops.space"
#   statuses        = ["ISSUED"]
#   most_recent = true
# }

resource "aws_acm_certificate" "cert" {
  domain_name       = "odochidevops.space"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.zone.id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
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
  # subnets        = module.vpc.pub_sub_ids
   subnets    = [module.vpc.pub_sub1_id, module.vpc.pub_sub2_id]
   certificate    = aws_acm_certificate_validation.cert_validation.certificate_arn
  hosted_zone_id = data.aws_route53_zone.zone.id
  domain_name    = var.domain_name
}

module "sonarqube" {
  source         = "./module/sonarqube"
  name           = local.name
  vpc            = module.vpc.vpc_id
  # vpc_cidr_block = "10.0.0.0/16"
  keypair        = module.vpc.public_key
  subnet_id      = module.vpc.pub_sub1_id
  subnets        = module.vpc.pub_sub1_id
  certificate    = aws_acm_certificate_validation.cert_validation.certificate_arn
  # certificate    = data.aws_acm_certificate.cert.arn
  hosted_zone_id = data.aws_route53_zone.zone.id
  domain_name    = var.domain_name
}



module "docker" {
  source     = "./module/docker"
  name       = local.name
  vpc_id     = module.vpc.vpc_id
  subnet_id  = module.vpc.pub_sub1_id
  keypair    = module.vpc.public_key
  region     = var.region
  nexus_ip   = module.nexus.nexus_ip 
  # nexus_ip   = var.nexus_ip
  nr_key     = var.nr_key
  nr_acc_id  = var.nr_acc_id
}

