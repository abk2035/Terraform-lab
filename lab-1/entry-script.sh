#!/bin/bash

# Mettre à jour les paquets
apt update -y

# Installer Docker
apt install -y docker.io

# Démarrer Docker
systemctl start docker

# Activer Docker au démarrage
systemctl enable docker

# Ajouter l'utilisateur ubuntu au groupe docker
usermod -aG docker ubuntu

# Lancer un conteneur nginx
docker run -d --name nginx -p 8080:80 nginx