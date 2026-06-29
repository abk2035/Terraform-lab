# Projet Terraform - Déploiement d'un cluster EKS sur AWS

Ce projet Terraform provisionne une infrastructure AWS complète pour héberger une application simple sur Kubernetes. Il crée :

- une VPC avec sous-réseaux publics et privés,
- une passerelle NAT,
- un cluster Amazon EKS,
- un groupe de nœuds géré par EKS,
- un déploiement NGINX exposé via un service LoadBalancer.

## Objectif

Le but de ce laboratoire est de démontrer la création automatisée d'un environnement Kubernetes sur AWS avec Terraform, en utilisant des modules Terraform officiels et des ressources AWS gérées.

## Architecture déployée

Le projet est basé sur les composants suivants :

- VPC : provisionnée via le module Terraform `terraform-aws-modules/vpc/aws`
- EKS : provisionné via le module `terraform-aws-modules/eks/aws`
- Région AWS : `us-east-1`
- Cluster EKS : `myapp-eks-cluster`
- Groupe de nœuds : `dev`
- Type d'instance : `t3.small`

L'infrastructure comprend :

- 3 sous-réseaux publics
- 3 sous-réseaux privés
- 1 passerelle NAT
- 1 cluster EKS avec un groupe de nœuds géré

## Structure du projet

- `variables.tf` : définitions des variables Terraform utilisées par le projet
- `terraform.tfvars` : valeurs des variables (CIDR, sous-réseaux, credentials AWS)
- `vpc.tf` : création de la VPC et des sous-réseaux via un module Terraform
- `eks-cluster.tf` : création du cluster EKS et du groupe de nœuds
- `nginx-config.yml` : manifeste Kubernetes pour déployer NGINX

## Prérequis

Avant de lancer le déploiement, assurez-vous d'avoir :

- Terraform installé
- l'interface de ligne AWS configurée (`aws configure` ou un profil AWS valide)
- `kubectl` installé
- accès à un compte AWS avec les droits nécessaires pour créer des ressources EKS et VPC

## Variables importantes

Le projet attend les variables suivantes :

- `vpc_cidr_block`
- `private_subnet_cidr_blocks`
- `public_subnet_cidr_blocks`
- `access_key`
- `secret_key`

Pour des raisons de sécurité, il est recommandé de ne pas stocker les identifiants AWS directement dans le dépôt. Vous pouvez utiliser un profil AWS déjà configuré ou des variables d'environnement.

## Déploiement

1. Initialiser Terraform :

```bash
terraform init
```

2. Vérifier le plan d'infrastructure :

```bash
terraform plan -var-file=terraform.tfvars
```

3. Appliquer la configuration :

```bash
terraform apply -var-file=terraform.tfvars
```

4. Récupérer la configuration Kubernetes du cluster :

```bash
aws eks update-kubeconfig --name myapp-eks-cluster --region us-east-1
```

5. Déployer l'application NGINX :

```bash
kubectl apply -f nginx-config.yml
```

6. Vérifier le service exposé :

```bash
kubectl get svc nginx
```

## Nettoyage

Pour supprimer toutes les ressources créées :

```bash
terraform destroy -var-file=terraform.tfvars
```

## Notes

- Le déploiement peut prendre plusieurs minutes selon la taille et la disponibilité des ressources AWS.
- Le manifeste NGINX crée un service de type `LoadBalancer` qui permet d'exposer l'application à l'extérieur du cluster.
- Ce laboratoire est pensé comme une base de départ pour apprendre la provisionning d'infrastructures cloud avec Terraform et EKS.
