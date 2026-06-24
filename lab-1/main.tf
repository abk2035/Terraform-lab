provider "aws" {
  region = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

variable "access_key" {
  description = "AWS access key"
  type        = string
  default     = "YOUR_ACCESS_KEY"
}

variable "secret_key" {
  description = "AWS secret key"
  type        = string
  default     = "YOUR_SECRET_KEY"
}

resource "aws_vpc" "development_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "development"
  }
}

resource "aws_subnet" "development_subnet" {
  vpc_id            = aws_vpc.development_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"
    tags = {
        Name = "subnet-1-dev"
    }  
}

data "aws_vpc" "existing_vpc" {
  default = true
}

