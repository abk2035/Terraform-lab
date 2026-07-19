terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80.0"
    }
  }
}

# Provider principal (Région de ton choix, ex: Virginie du Nord)
provider "aws" {
  region = "us-east-1"
}

# Provider esclave requis uniquement pour le certificat SSL CloudFront
# provider "aws" {
#   alias  = "us-east-1"
#   region = "us-east-1"
# }