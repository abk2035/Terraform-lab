# Architecture Haute Disponibilité : Déploiement de WordPress sur AWS

Ce dépôt contient le code et la configuration nécessaires pour déployer un site WordPress hautement disponible, sécurisé et scalable sur AWS, conformément aux standards de production.

## 1. Objectifs & Fonctionnalités du Projet

* **Réseau Isolé (VPC) :** Configuration Multi-AZ avec sous-réseaux publics (pour le routage externe) et privés (pour l'application et la base de données) afin de masquer le front-end du grand public.
* **Haute Disponibilité & Scalabilité :** Répartition de la charge via un Application Load Balancer (ALB) et mise à l'échelle automatique grâce à un Auto Scaling Group (ASG).
* **Données Persistantes & Cache :** Base de données managée multi-AZ (Amazon RDS MySQL) associée à une couche de cache en mémoire (Amazon ElastiCache Redis) pour optimiser les performances.
* **Sécurité Renforcée :** Protection applicative par AWS WAF, chiffrement des connexions via AWS Certificate Manager (ACM), et distribution sécurisée globale par Amazon CloudFront.

---

## 2. Technologies Utilisées

| Composant | Service AWS / Outil | Rôle / Justification |
| --- | --- | --- |
| **Réseau (VPC)** | AWS VPC, Internet Gateway, NAT Gateway | Isolation et routage sécurisé des flux |
| **Hébergement** | Amazon EC2 | Exécution des conteneurs/serveurs WordPress |
| **Auto-scaling** | Auto Scaling Group (ASG) | Adaptation de la capacité des nœuds selon la charge |
| **Répartition de charge** | Elastic Load Balancer (ALB) | Distribution du trafic vers les instances saines |
| **Base de données** | Amazon RDS (MySQL) | Persistance des données WordPress en mode managé |
| **Mise en cache** | Amazon ElastiCache (Redis) | Optimisation des requêtes et réduction de la charge DB |
| **Sécurité Edge** | AWS WAF | Protection contre les failles Web (OWASP Top 10) |
| **Réseau de diffusion** | Amazon CloudFront | CDN pour la mise en cache globale du contenu statique |
| **Certificats SSL** | AWS Certificate Manager (ACM) | Gestion et renouvellement automatique des certificats HTTPS |

---

## 3. Feuille de Route de Déploiement (Étapes)

### Phase 1 : Conception & Fondations Réseau (VPC)

1. **Création du VPC :** Configurer un bloc CIDR dédié (ex: `10.0.0.0/16`).
2. **Définition des Sous-réseaux (Multi-AZ) :**
* 2 sous-réseaux publics (Zone A et B) pour l'ALB et la NAT Gateway.
* 2 sous-réseaux privés Applicatifs (Zone A et B) pour les instances EC2 WordPress.
* 2 sous-réseaux privés Data (Zone A et B) pour RDS et ElastiCache.


3. **Passerelles & Routage :** Déployer une *Internet Gateway* pour les flux entrants de l'ALB, et une *NAT Gateway* dans un sous-réseau public pour permettre aux instances privées de télécharger les mises à jour en toute sécurité.


---

### Detail Phase 1 : Conception & Fondations Réseau (VPC)

Le VPC (Virtual Private Cloud) agit comme ton datacenter virtuel isolé au sein d'AWS. Pour ce projet, l'infrastructure est déployée dans la région **N. Virginia (`us-east-1`)**, en exploitant les zones de disponibilité `us-east-1a` (Zone A) et `us-east-1b` (Zone B).

#### Création du VPC

* Connecte-toi à la console AWS et ouvre le service **VPC**.
* Dans le menu de gauche, clique sur **Your VPCs**, puis sur le bouton orange **Create VPC**.
* Configure les options suivantes :
* **Resources to create :** Sélectionne **VPC only** afin de tout configurer manuellement et maîtriser chaque brique.
* **Name tag :** `wordpress-vpc`
* **IPv4 CIDR block :** Sélectionne *IPv4 CIDR manual input*.
* **IPv4 CIDR :** Saisis `10.0.0.0/16` (ce qui génère un pool de 65 536 adresses IP privées).
* **Tenancy :** `Default`


* Clique sur **Create VPC**.
* *(Recommandé)* Une fois le VPC créé, sélectionne-le, clique sur **Actions** (en haut à droite) > **Edit VPC settings**. Coche les cases **Enable DNS hostnames** et **Enable DNS support**, puis sauvegarde. Cela permet à tes ressources de s'identifier via des noms de domaine AWS plutôt que par de simples adresses IP.

#### Définition des Sous-réseaux (Multi-AZ)

Pour garantir la haute disponibilité, les sous-réseaux sont répartis sur deux zones de disponibilité distinctes et la plage globale `10.0.0.0/16` est découpée en blocs plus restreints (`/24`, soit 256 adresses IP par sous-réseau).

* Dans le menu de gauche, clique sur **Subnets**, puis sur **Create subnet**.
* Sélectionne ton VPC : `wordpress-vpc`.
* Ajoute et configure les sous-réseaux suivants en cliquant sur **Add new subnet** pour exécuter la création en une seule fois :

##### Zone de Disponibilité A (`us-east-1a`)

* **Subnet : Public-App-AZ-A**
* *Availability Zone :* `us-east-1a`
* *IPv4 CIDR block :* `10.0.1.0/24`


* **Subnet : Private-Web-AZ-A** (Dédié à l'hébergement EC2 WordPress)
* *Availability Zone :* `us-east-1a`
* *IPv4 CIDR block :* `10.0.2.0/24`


* **Subnet : Private-Data-AZ-A** (Dédié à RDS et ElastiCache)
* *Availability Zone :* `us-east-1a`
* *IPv4 CIDR block :* `10.0.3.0/24`



##### Zone de Disponibilité B (`us-east-1b`)

* **Subnet : Public-App-AZ-B**
* *Availability Zone :* `us-east-1b`
* *IPv4 CIDR block :* `10.0.11.0/24`


* **Subnet : Private-Web-AZ-B** (Dédié à l'hébergement EC2 WordPress)
* *Availability Zone :* `us-east-1b`
* *IPv4 CIDR block :* `10.0.12.0/24`


* **Subnet : Private-Data-AZ-B** (Dédié à RDS et ElastiCache)
* *Availability Zone :* `us-east-1b`
* *IPv4 CIDR block :* `10.0.13.0/24`


* Clique sur **Create subnet**.
* **Activation de l'IP publique automatique :** Sélectionne le sous-réseau `Public-App-AZ-A`, clique sur **Actions** > **Edit subnet settings**, coche la case **Enable auto-assign public IPv4 address** et sauvegarde. Répète la même opération pour le sous-réseau `Public-App-AZ-B`.

#### Déploiement des Passerelles (Internet & NAT)

##### Internet Gateway (IGW) - Pour le réseau public

L'IGW assure la liaison et la communication bidirectionnelle entre les ressources publiques du VPC et l'Internet extérieur.

* Dans le menu de gauche du service VPC, clique sur **Internet gateways**, puis sur **Create internet gateway**.
* Nomme-la : `wordpress-igw` et clique sur **Create**.
* Une fois la passerelle générée, clique sur **Actions** > **Attach to VPC**, sélectionne `wordpress-vpc` et valide l'association.

##### NAT Gateway - Pour le réseau privé

La NAT Gateway permet aux instances situées en zone privée d'initier des flux sortants (téléchargement de dépendances, paquets de sécurité ou plugins) tout en interdisant toute tentative de connexion entrante non sollicitée depuis l'extérieur.

* Dans le menu de gauche, clique sur **NAT gateways**, puis sur **Create NAT gateway**.
* Configure la ressource avec les paramètres suivants :
* **Name :** `wordpress-nat-gw`
* **Subnet :** Sélectionne votre VPC
* **Connectivity type :** `Public`
* **Elastic IP :** Clique sur le bouton **Allocate Elastic IP** pour réserver et lui lier une adresse IP publique fixe et immuable.


* Clique sur **Create NAT gateway** *(l'initialisation complète par AWS requiert généralement 2 à 3 minutes)*.

#### Configuration des Tables de Routage (Routing)

L'aiguillage des flux au sein des tables de routage détermine l'étanchéité et la nature (publique ou privée) des sous-réseaux. La table par défaut est volontairement isolée par sécurité, et des tables dédiées sont assignées aux différents tiers de l'application.

##### Sécurisation de la Main Route Table (Table par défaut)

* Dans le menu de gauche, clique sur **Route tables**.
* Identifie la table de routage liée à ton VPC affichant la valeur `Yes` dans la colonne **Main**.
* Sélectionne cette table, ouvre l'onglet **Routes** en bas et valide qu'elle contient uniquement la règle locale : `10.0.0.0/16 -> local`. N'y ajoute aucun chemin vers une passerelle externe. Tout sous-réseau créé ultérieurement sans association explicite y sera rattaché par défaut et restera ainsi hermétique à Internet.
* Renomme cette table : `main-route-table-secured-private`.

##### Configuration de la Table de Routage Publique

* Clique sur **Create route table**.
* **Name :** `public-route-table`
* **VPC :** `wordpress-vpc`


* Clique sur **Create**.
* Sélectionne la table ainsi créée, puis ouvre l'onglet **Routes** > **Edit routes**.
* Clique sur **Add route** pour définir la sortie :
* *Destination :* `0.0.0.0/0` (Tout le trafic à destination d'Internet)
* *Target :* Choisis **Internet Gateway**, puis sélectionne `wordpress-igw`.


* Clique sur **Save changes**.
* Bascule sur l'onglet **Subnet associations** > **Edit subnet associations**.
* Coche exclusivement les sous-réseaux publics `Public-App-AZ-A` et `Public-App-AZ-B`, puis valide. Ils disposent désormais d'un accès public direct.

##### Configuration de la Table de Routage Privée

* Clique à nouveau sur **Create route table**.
* **Name :** `private-route-table`
* **VPC :** `wordpress-vpc`


* Clique sur **Create**.
* Sélectionne cette table, puis accède à l'onglet **Routes** > **Edit routes**.
* Clique sur **Add route** pour rediriger les flux sortants :
* *Destination :* `0.0.0.0/0`
* *Target :* Choisis **NAT Gateway**, puis sélectionne `wordpress-nat-gw`.


* Clique sur **Save changes**.
* Accède à l'onglet **Subnet associations** > **Edit subnet associations**.
* Coche l'ensemble des 4 sous-réseaux privés restants (les tiers applicatifs et data des deux zones de disponibilité) :
* `Private-Web-AZ-A`
* `Private-Web-AZ-B`
* `Private-Data-AZ-A`
* `Private-Data-AZ-B`


* Valide l'association.

Les fondations réseau sont désormais finalisées et sécurisées, prêtes à accueillir les couches de calcul et de données.

---


### Phase 2 : Couche de Données & Stockage (RDS & ElastiCache)

1. **Déploiement de RDS :** Initialiser une instance MySQL en mode Multi-AZ dans le sous-réseau Data. Configurer un groupe de sécurité (Security Group) n'acceptant que le trafic provenant du futur Security Group des instances EC2 applicatives.
2. **Configuration d'ElastiCache :** Déployer un cluster Redis dans le sous-réseau Data pour le cache de sessions et d'objets WordPress.
3. **Stockage Partagé (Optionnel mais recommandé) :** Configurer un système de fichiers Amazon EFS pour centraliser le répertoire `wp-content` entre toutes les instances EC2 de l'ASG.

### Phase 3 : Compute & Haute Disponibilité (ALB & ASG)

1. **Préparation de la Launch Template :** Configurer un script utilisateur (*User Data*) pour installer Docker/Apache, PHP, télécharger WordPress et monter automatiquement le volume EFS ou configurer la connexion vers la base de données RDS.
2. **Configuration de l'ALB :** Placer le Load Balancer dans les sous-réseaux publics. Configurer le *Target Group* ciblant le port HTTP/HTTPS.
3. **Mise en place de l'ASG :** Lier l'ASG au Target Group de l'ALB. Définir des politiques de scaling (ex: déclencher une nouvelle instance si la consommation CPU moyenne dépasse 70%). **Placer impérativement les instances dans les sous-réseaux privés.**

### Phase 4 : Sécurisation & Front-End (ACM, CloudFront & WAF)

1. **Génération du Certificat :** Demander un certificat SSL public via ACM pour votre nom de domaine.
2. **Création de la Distribution CloudFront :** Pointer l'origine de CloudFront vers l'ALB. Configurer la redirection systématique du HTTP vers le HTTPS en y associant le certificat ACM.
3. **Activation d'AWS WAF :** Associer des règles de pare-feu managées (AWS Managed Rules) à CloudFront ou à l'ALB pour bloquer les injections SQL et les attaques par force brute courantes sur WordPress.

---

## 4. Comment Tester le Projet ?

1. Récupérez l'URL fournie par votre distribution CloudFront ou votre ALB.
2. Accédez à l'interface d'installation de WordPress via votre navigateur.
3. Simulez une panne (en coupant manuellement une instance EC2 depuis la console AWS) et observez comment l'Auto Scaling Group recrée automatiquement une nouvelle instance saine sans interruption de service.
4. Vérifiez dans la configuration réseau que vos instances EC2 n'ont pas d'adresse IP publique et restent totalement invisibles depuis l'Internet direct.








## 5. Feuille de Route de Déploiement & Architecture Terraform

on découpe le projet en modules Terraform réutilisables pour éviter le code monolithique.

### Étape 1 : Initialisation du Backend & Structure IaC

* Créer un bucket S3 et une table DynamoDB pour gérer le *Remote State* de Terraform et le *State Locking* (évite les conflits si plusieurs personnes appliquent le code).
* Structurer le projet en modules : `vpc`, `security_groups`, `rds`, `elasticache`, `compute`, `cdn_security`.

### Étape 2 : Le Module Réseau (`modules/vpc`)

* Écrire le code Terraform pour créer le VPC (ex: `10.0.0.0/16`).


* Définir les sous-réseaux (2 publics pour l'ALB/NAT, 2 privés pour les EC2, 2 privés pour la data) répartis sur deux Zones de Disponibilité (AZ) distinctes.


* Déployer l'Internet Gateway et la NAT Gateway (via Terraform) pour permettre aux instances privées de faire leurs backups ou mises à jour vers l'extérieur.



### Étape 3 : Sécurité & Données (`modules/rds` & `modules/elasticache`)

* **Security Groups :** Définir les règles strictes en code (la base de données RDS n'accepte le trafic sur le port 3306 *que* s'il provient du Security Group des instances EC2).
* 
**RDS Multi-AZ :** Provisionner l'instance RDS MySQL managée via Terraform dans le sous-réseau privé data.


* 
**ElastiCache Redis :** Déployer le cluster de cache en mémoire pour WordPress.



### Étape 4 : Serveurs & Haute Disponibilité (`modules/compute`)

* Créer une *Launch Template* EC2. Inclure dans l'argument `user_data` de Terraform un script Bash qui installe automatiquement Docker, lance le conteneur WordPress et injecte les variables d'environnement de la base de données (récupérées dynamiquement depuis le module RDS).
* Déployer l'Application Load Balancer (ALB) dans les sous-réseaux publics.


* Configurer l'Auto Scaling Group (ASG) dans les sous-réseaux privés, lié au Target Group de l'ALB, avec une politique de scaling basée sur la charge CPU.



### Étape 5 : Sécurité Edge & CDN (`modules/cdn_security`)

* Générer le certificat SSL via la ressource `aws_acm_certificate`.


* Créer la distribution Amazon CloudFront qui prend l'ALB comme origine.


* Associer une Web ACL d'AWS WAF (Web Application Firewall) à la distribution pour bloquer les attaques courantes.


---


### Commandes pour déployer

```bash
# 1. Initialiser Terraform (téléchargement des providers et des modules)
terraform init

# 2. Valider le code et voir le plan d'exécution de l'infrastructure
terraform plan

# 3. Déployer l'intégralité de l'architecture sur AWS
terraform apply -auto-approve

```

## 6. Validation Avec Terraform

1. **Réseau Privé :** Tente de te connecter en SSH directement à une instance WordPress. Cela doit échouer, prouvant que le front-end n'est pas exposé directement à l'extérieur.


2. **Haute Disponibilité :** Termine manuellement une instance EC2 depuis la console AWS. Observe Terraform et l'ASG travailler ensemble : l'ASG va recréer une instance saine en tâche de fond sans coupure pour l'utilisateur final.


3. **Nettoyage :** Une fois la démonstration terminée, détruis tout en une seule commande pour éviter les coûts inutiles :
```bash
terraform destroy -auto-approve

```