# 1. Module Réseau
module "vpc" {
  source      = "../../modules/vpc"
  environment = var.environment
}

# 2. Module Sécurité Réseau
module "security_groups" {
  source      = "../../modules/security_groups"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
}

# 3. Module Stockage (RDS & EFS)
module "storage" {
  source              = "../../modules/storage"
  environment         = var.environment
  db_subnet_ids       = module.vpc.database_subnet_ids
  efs_subnet_ids      = module.vpc.private_subnet_ids
  db_security_group_id = module.security_groups.rds_sg_id
  efs_security_group_id = module.security_groups.efs_sg_id
  db_password         = var.db_password
  db_name             = var.db_name
  db_username         = var.db_username
}

# 4. Module Certificat SSL (Uniquement ACM en us-east-1)
module "security_edge" {
  source      = "../../modules/security_edge"
  environment = var.environment
  domain_name = var.domain_name 
}

# 5. Module Application (EC2, ASG, ALB, CloudFront)
module "compute" {
  source                 = "../../modules/compute"
  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  private_subnet_ids     = module.vpc.private_subnet_ids
  alb_security_group_id  = module.security_groups.alb_sg_id
  ec2_security_group_id  = module.security_groups.ec2_sg_id
  
  db_endpoint            = module.storage.db_endpoint
  db_password            = var.db_password
  efs_id                 = module.storage.efs_id
  
  acm_certificate_arn    = module.security_edge.acm_certificate_arn
  domain_name            = var.domain_name
}