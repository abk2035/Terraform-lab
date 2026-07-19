variable "environment" { type = string }

variable "db_subnet_ids" { type = list(string) }

variable "efs_subnet_ids" { type = list(string) }

variable "db_security_group_id" { type = string }

variable "efs_security_group_id" { type = string }

variable "db_password" { 
    type = string
    sensitive = true 
}

variable "db_name" {
  type = "string"
}

variable "db_username" {
  type = "string"
}