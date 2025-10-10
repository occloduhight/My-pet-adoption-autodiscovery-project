provider "aws" {
  region = "eu-west-3"
  profile = "default"
}

# terraform {
#     backend "s3" {
#         bucket = "auto-discovery"
#         key    = "vault-jenkins/terraform.tfstate"
#         region = "eu-west-3"
#         encrypt = true
#         profile = "default"
#         encrypt = true
#         use_lockfile = true

#     }
# }

terraform {
  backend "s3" {
    bucket  = "auto-discovery-odochi2025"
    key     = "vault-jenkins/terraform.tfstate"
    region  = "eu-west-3"
    profile = "default"
    encrypt = true
  }
}
