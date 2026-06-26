provider "aws" {
  region = var.avail_zone
  access_key = var.access_key
  secret_key = var.secret_key
}


resource "aws_vpc" "my_app-vpc" {
    cidr_block = var.my_vpc_cidr_block
    tags = {
        Name = "${var.env_prefix}-vpc"
    }
}

module "my_app-subnet" {
    source = "./modules/subnet"
    subnet_cidr_block = var.my_subnet_cidr_block
    avail_zone = var.avail_zone
    env_prefix = var.env_prefix
    vpc_id = aws_vpc.my_app-vpc.id
    default_route_table_id = aws_vpc.my_app-vpc.default_route_table_id
}

module "my_app-server" {
    source = "./modules/webserver"
    vpc_id = aws_vpc.my_app-vpc.id
    my_ip = var.my_ip
    env_prefix = var.env_prefix
    image_name = var.image_name
    public_key_location = var.public_key_location
    instance_type = var.instance_type
    subnet_id = module.my_app-subnet.subnet.id
    avail_zone = var.avail_zone
}
