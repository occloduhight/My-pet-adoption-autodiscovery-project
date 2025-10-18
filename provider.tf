provider "aws" {
  region  = "eu-west-3"
  
}

terraform {
  backend "s3" {
    bucket       = "auto-discovery-odochi2025"
    use_lockfile = true
    key          = "infrastructure/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    
  }
}
