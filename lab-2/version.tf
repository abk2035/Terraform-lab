terraform {
  required_version = ">= 1.9.0"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }

    # helm = {
    #   source  = "hashicorp/helm"
    #   version = "~> 2.17"
    # }

    # tls = {
    #   source  = "hashicorp/tls"
    #   version = "~> 4.0"
    # }

    # time = {
    #   source  = "hashicorp/time"
    #   version = "~> 0.12"
    # }

    # random = {
    #   source  = "hashicorp/random"
    #   version = "~> 3.7"
    # }
  }

  #le state distant sur un bucket S3
  backend "s3" { 
    bucket         = "myapp-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    # dynamodb_table = "terraform-locks"
    use_lockfile   = true

  }
}