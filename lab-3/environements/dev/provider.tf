# Provider principal (Région de ton choix, ex: Paris)
provider "aws" {
  region = "us-east-1"
}

# Provider esclave requis uniquement pour le certificat SSL CloudFront
# provider "aws" {
#   alias  = "us-east-1"
#   region = "us-east-1"
# }