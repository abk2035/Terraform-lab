variable "environment" {
  type        = string
  description = "Nom de l'environnement"
}

variable "vpc_id" {
  type        = string
  description = "ID du VPC créé par le module reseau"
}