variable "environment" {
  type        = string
  default     = "dev"
  description = "Nom de l'environnement de déploiement"
}

variable "domain_name" {
  type        = string
  description = "Ton nom de domaine principal (ex: mon-site-wordpress.com)"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Mot de passe maître pour la base de données RDS MySQL"
}

variable "db_name" {
  type        = string
  description = "nom de la base de données RDS MySQL"
}

variable "db_username" {
  type        = string
  description = "nom d'utilisateur pour la base de données RDS MySQL"
}