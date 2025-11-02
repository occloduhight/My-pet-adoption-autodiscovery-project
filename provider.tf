provider "aws" {
  region = "eu-west-3"
}

terraform {
  backend "s3" {
    bucket       = "auto-discovery-odo2025"           # Your new bucket
    key          = "infrastructure/terraform.tfstate" # Path in the bucket for state
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true # Explicitly enable lockfile
  }
}

# provider "vault" {
#   token = 
#   address = "https://vault.odochidevops.space"
# }

# data "vault_generic_secret" "database" {
#   path = "secret/database"
# }


