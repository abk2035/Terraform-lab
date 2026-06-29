variable vpc_cidr_block {}
variable private_subnet_cidr_blocks {}
variable public_subnet_cidr_blocks {}



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