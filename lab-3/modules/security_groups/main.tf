# 1. Security Group pour l'Application Load Balancer (ouvert sur le web)
resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Autorise le trafic HTTP et HTTPS entrant vers l'ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS public"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Autorise tout le trafic sortant"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-alb-sg" }
}

# 2. Security Group pour les instances EC2 WordPress
resource "aws_security_group" "ec2" {
  name        = "${var.environment}-ec2-sg"
  description = "Autorise le trafic venant uniquement de l'ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP depuis l'ALB uniquement"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Autorise tout le trafic sortant"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-ec2-sg" }
}

# 3. Security Group pour la base de données RDS MySQL
resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-sg"
  description = "Autorise MySQL uniquement depuis les instances EC2 WordPress"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL depuis les EC2 applicatives"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-rds-sg" }
}

# 4. Security Group pour le système de fichiers partagé EFS
resource "aws_security_group" "efs" {
  name        = "${var.environment}-efs-sg"
  description = "Autorise le trafic NFS (EFS) depuis les instances EC2 WordPress"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS depuis les EC2 applicatives"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-efs-sg" }
}