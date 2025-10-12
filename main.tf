locals {
  name = "team-1"
}
module "vpc" {
  source = "./module/vpc"
  name   = local.name
}
