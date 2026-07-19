# --- CONFIGURATION AMAZON RDS (MySQL) ---

# Groupe de sous-réseaux pour la base de données Multi-AZ
resource "aws_db_subnet_group" "rds" {
  name       = "${var.environment}-rds-subnet-group"
  subnet_ids = var.db_subnet_ids
  tags       = { Name = "${var.environment}-rds-subnet-group" }
}

# Instance de base de données MySQL
resource "aws_db_instance" "mysql" {
  identifier             = "${var.environment}-wordpress-db"
  allocated_storage      = 20
  max_allocated_storage  = 100
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t4g.micro" # Type d'instance économique et performant (Graviton)
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [var.db_security_group_id]
  skip_final_snapshot    = true
  multi_az               = false # Passe à true pour de la vraie haute disponibilité en prod

  tags = { Name = "${var.environment}-wordpress-rds" }
}

# --- CONFIGURATION AMAZON EFS ---
# Système de fichiers EFS
resource "aws_efs_file_system" "wordpress_assets" {
  creation_token = "${var.environment}-wordpress-efs"
  encrypted      = true

  tags = { Name = "${var.environment}-wordpress-efs" }
}

# Points de montage EFS dans chaque sous-réseau privé applicatif
resource "aws_efs_mount_target" "target" {
  count           = length(var.efs_subnet_ids)
  file_system_id  = aws_efs_file_system.wordpress_assets.id
  subnet_id       = var.efs_subnet_ids[count.index]
  security_groups = [var.efs_security_group_id]
}