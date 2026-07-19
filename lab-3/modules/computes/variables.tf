variable "environment"           { type = string }
variable "vpc_id"                { type = string }
variable "public_subnet_ids"     { type = list(string) }
variable "private_subnet_ids"    { type = list(string) }
variable "alb_security_group_id" { type = string }
variable "ec2_security_group_id" { type = string }
variable "db_endpoint"           { type = string }
variable "db_password"{ 
    type = string
    sensitive = true 
}
variable "efs_id"                { type = string }
variable "acm_certificate_arn"   { type = string }
variable "domain_name"           { type = string }