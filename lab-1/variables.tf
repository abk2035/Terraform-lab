variable my_vpc_cidr_block {}
variable my_subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable public_key_location {}
variable image_name {}


#pour se connecter à AWS, on a besoin de l'Access Key et du Secret Key. On peut les définir dans un fichier terraform.tfvars ou les passer en paramètre lors de l'exécution de la commande terraform apply.
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