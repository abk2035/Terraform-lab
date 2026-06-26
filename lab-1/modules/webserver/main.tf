resource "aws_default_security_group" "default-sg" {
    vpc_id = var.vpc_id


    # Règle entrante (Ingress)

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        # Autorise uniquement cette adresse IP à se connecter
        cidr_blocks = [var.my_ip]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        #Autorise toutes les adresses IP à se connecter
        #Deconseillé en production, mais pratique pour les tests
        #On peut par exemple mettre l'adresse du frontend de l'application
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name = "${var.env_prefix}-default-sg"
    }
}


# Recherche automatique de la dernière AMI Amazon Linux
data "aws_ami" "latest-amazon-linux-image" {

    # Sélectionne l'image la plus récente
    most_recent = true

    # Recherche uniquement parmi les images officielles AWS
    owners = ["amazon"]

    # Filtre sur le nom de l'image
    filter {
        name = "name"

        # Nom défini dans une variable Terraform
        values = [var.image_name]
    }

    # Filtre sur le type de virtualisation
    filter {
        name = "virtualization-type"

        # HVM est le standard recommandé par AWS
        values = ["hvm"]
    }
}

# Création d'une paire de clés SSH pour notre EC2
#pour la generer taper 
# dans le powershell taper : ssh-keygen -t ed25519 -f $HOME\.ssh\aws-server-key
resource "aws_key_pair" "ssh-key" {

    # Nom de la clé visible dans AWS
    key_name = "server-key"

    # Lecture de la clé publique depuis le poste local
    public_key = file(var.public_key_location)
}

resource "aws_instance" "my_app-server" {
    ami = data.aws_ami.latest-amazon-linux-image.id
    instance_type = var.instance_type

    subnet_id = var.subnet_id
    vpc_security_group_ids = [aws_default_security_group.default-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    key_name = aws_key_pair.ssh-key.key_name

    # user_data = file("entry-script.sh")

    tags = {
        Name = "${var.env_prefix}-server"
    }
}
