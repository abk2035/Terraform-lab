# Création du VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# Internet Gateway pour les subnets publics
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.environment}-igw" }
}

# Subnets Publics (ALB)
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.environment}-public-${var.availability_zones[count.index]}" }
}

# Subnets Privés (Instances EC2 WordPress)
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 2}.0/24"
  availability_zone = var.availability_zones[count.index]

  tags = { Name = "${var.environment}-private-${var.availability_zones[count.index]}" }
}

# Subnets Base de données (RDS)
resource "aws_subnet" "database" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 4}.0/24"
  availability_zone = var.availability_zones[count.index]

  tags = { Name = "${var.environment}-db-${var.availability_zones[count.index]}" }
}

# Elastic IP pour la NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.environment}-nat-eip" }
}

# NAT Gateway (Placée dans le premier subnet public)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.environment}-nat-gw" }

  depends_on = [aws_internet_gateway.gw]
}

# Table de routage publique
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "${var.environment}-public-rt" }
}

# Table de routage privée (Passe par la NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "${var.environment}-private-rt" }
}

# Associations des tables de routage
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones) 
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}