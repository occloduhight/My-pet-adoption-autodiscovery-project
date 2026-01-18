provider "aws" {
    region = "eu-west-3"
    profile = "default"
}

terraform {
 backend "s3" {
   bucket = "autodiscproject"
   key = "infra/terraform.tfstate"
   region = "eu-west-3"
   profile = "default"
   encrypt = true
   use_lockfile = true
 } 
}

provider "vault" {
   token = var.vault_token
   address = "https://vault.odochidevops.space"
 }

 data "vault_generic_secret" "database" {
   path = "secret/database"
 }
