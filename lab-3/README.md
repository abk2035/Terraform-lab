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


### Phase 2 : Couche de Données & Stockage (RDS & ElastiCache (Valkey & EFS))

1. **Déploiement de RDS :** Initialiser une instance MySQL en mode Multi-AZ dans le sous-réseau Data. Configurer un groupe de sécurité (Security Group) n'acceptant que le trafic provenant du futur Security Group des instances EC2 applicatives.
2. **Configuration d'ElastiCache :** Déployer un cluster Redis dans le sous-réseau Data pour le cache de sessions et d'objets WordPress.
3. **Stockage Partagé (Optionnel mais recommandé) :** Configurer un système de fichiers Amazon EFS pour centraliser le répertoire `wp-content` entre toutes les instances EC2 de l'ASG.

Voici la version finale, corrigée et mise à jour de la **Phase 2 : Couche de Données & Stockage** pour ton README, en intégrant parfaitement toutes nos récentes discussions sur l'optimisation des coûts (Free Tier), l'utilisation de Valkey dans sa nouvelle interface, et la sécurisation des accès.

---

Cette phase consiste à déployer les briques étanches de persistance et de performance au sein de tes sous-réseaux privés Data. L'accès à ces ressources est strictement limité à l'aide de groupes de sécurité imbriqués.

> 💡 **Note sur l'optimisation des coûts (Laboratoire FinOps) :**
> Afin de maintenir ce déploiement dans le cadre du **Free Tier AWS** ou de minimiser la facturation, la base de données est configurée en mode Single-AZ (Instance unique). Pour le cache, ce projet utilise **Valkey** (le successeur open-source officiel d'ElastiCache) configuré sans réplica, ce qui permet de réduire les coûts d'environ 33 % par rapport à Redis.
> 
> 

#### Création préalable des Groupes de Sécurité (Security Groups)

Avant de lancer les bases de données ou le stockage, il est impératif de définir les barrières de sécurité réseau au sein du service **VPC** > **Security Groups**.

##### Groupe de Sécurité pour les instances WordPress (SG-App)

Ce groupe servira de badge d'accès pour les futures instances EC2 WordPress.

* Clique sur **Create security group**.
* **Security group name :** `wordpress-app-sg`
* **VPC :** `wordpress-vpc`
* **Inbound rules :** Laisse vide pour l'instant (l'Application Load Balancer y sera connecté plus tard).


* Sauvegarde le groupe de sécurité.

##### Groupe de Sécurité pour la Base de Données (SG-DB)

* Clique sur **Create security group**.
* **Security group name :** `wordpress-db-sg`
* **VPC :** `wordpress-vpc`
* **Inbound rules :** Ajoute une règle :
* *Type :* `MySQL/Aurora (3306)`
* *Source :* Sélectionne le groupe de sécurité `wordpress-app-sg` (en saisissant son identifiant `sg-xxxxxx`).




* Sauvegarde. Seules les machines portant le badge `wordpress-app-sg` pourront interroger la base de données.



##### Groupe de Sécurité pour le Cache Valkey (SG-Cache)

* Clique sur **Create security group**.
* **Security group name :** `wordpress-cache-sg`
* **VPC :** `wordpress-vpc`
* **Inbound rules :** Ajoute une règle :
* *Type :* `Custom TCP`
* *Port range :* `6379` (Port par défaut de Valkey / Redis).


* *Source :* Sélectionne le groupe de sécurité `wordpress-app-sg`.


* Sauvegarde.

##### Groupe de Sécurité pour le Stockage Partagé (SG-EFS)

* Clique sur **Create security group**.
* **Security group name :** `wordpress-efs-sg`
* **VPC :** `wordpress-vpc`
* **Inbound rules :** Ajoute une règle :
* *Type :* `NFS (2049)`
* *Source :* Sélectionne le groupe de sécurité `wordpress-app-sg`.


* Sauvegarde.

#### Déploiement de la Base de Données Amazon RDS (MySQL)

##### Configuration du Groupe de Sous-réseaux (Subnet Group)

RDS a besoin de connaître les sous-réseaux privés où il a le droit de s'exécuter.

* Va dans le service **RDS** > **Subnet groups**.
* Clique sur **Create DB subnet group**.
* **Name :** `wordpress-db-subnet-group`
* **VPC :** `wordpress-vpc`
* **Availability Zones :** Sélectionne `us-east-1a` et `us-east-1b`.
* **Subnets :** Coche les deux plages correspondant à tes sous-réseaux Data (`10.0.3.0/24` et `10.0.13.0/24`).
* Clique sur **Create**.

##### Création de l'Instance MySQL (Mode Free Tier)

* Va dans **Databases** > **Create database**.
* **Choose a database creation method :** `Standard create`
* **Engine options :** `MySQL`

* **Templates :** Choisis explicitement **`Free Tier`**.
* **Availability and durability :** L'option bascule automatiquement sur *Single DB instance* pour respecter la gratuité.
* **Settings :**
* *DB instance identifier :* `wordpress-rds`
* *Master username :* `admin`
* *Master password :* Définis un mot de passe robuste.


* **Connectivity :**
* *VPC :* `wordpress-vpc`
* *DB subnet group :* Sélectionne `wordpress-db-subnet-group`.
* *Public access :* Choisis impérativement **No**.


* *Existing VPC security groups :* Retire le groupe `default` et sélectionne uniquement `wordpress-db-sg`.




* Clique sur **Create database**. Note l'**Endpoint** (l'adresse de connexion DNS) une fois le statut *Available* atteint.

#### Configuration d'Amazon ElastiCache (Valkey)

##### Configuration du Groupe de Sous-réseaux ElastiCache

* Va dans le service **ElastiCache** > **Subnet groups**.
* Clique sur **Create subnet group**.
* **Name :** `wordpress-cache-subnet-group`
* **VPC :** `wordpress-vpc`
* **Subnets :** Sélectionne tes sous-réseaux Data (`10.0.3.0/24` et `10.0.13.0/24`).
* Clique sur **Create**.

##### Création du Cluster Valkey (Nouvelle Interface AWS)

* Dans le menu ElastiCache, va dans **Valkey clusters** > **Create Valkey cluster**.
* **Deployment option :** Bascule impérativement sur **Self-designed** (pour désactiver le mode Serverless par défaut et pouvoir utiliser tes propres configurations réseau et de sécurité).
* **Cluster settings :**
* *Name :* `wordpress-valkey-cache`
* *Node type :* Sélectionne **`cache.t4g.micro`** (l'instance Graviton la plus économique).
* *Number of replicas :* Règle à `0` (Pas de Multi-AZ payant pour ce laboratoire).


* **Connectivity :**
* *Network type :* `IPv4`
* *VPC :* Sélectionne `wordpress-vpc` (Étape indispensable pour débloquer les menus suivants).
* *Subnet group selection :* Choisis *Choose an existing subnet group* et sélectionne `wordpress-cache-subnet-group`.


* Clique sur **Next** en bas de la page.
* **Advanced settings (Security) :** Dans la section *Network and security*, désélectionne le groupe `default` et associe uniquement ton groupe de sécurité personnalisé **`wordpress-cache-sg`**.
* Clique sur **Create**.
* **Récupération de l'Endpoint :** Une fois le statut *Available* obtenu, clique sur le nom du cluster. Dans l'onglet *Description*, repère et copie la ligne **Configuration endpoint** (elle ressemble à `clustercfg.wordpress-valkey-cache.xxxxxx.use1.cache.amazonaws.com:6379`). C'est cette adresse (sans le port `:6379`) qu'il faudra injecter dans ton plugin WordPress.

#### Configuration du Stockage Partagé Amazon EFS

Le dossier `/wp-content` (contenant les images importées, les plugins et les thèmes) doit être identique sur toutes tes futures instances EC2. Amazon EFS permet de partager ce dossier en réseau.

* Va dans le service **EFS** > **File systems**.
* Clique sur **Create file system** puis sélectionne **Customize** pour un contrôle total.
* **General settings :** Nomme-le `wordpress-efs-share`.
* **Network access :**
* *VPC :* Sélectionne `wordpress-vpc`.
* *Mount targets (Points de montage) :*
* Pour la ligne `us-east-1a` : Sélectionne le sous-réseau applicatif privé `Private-Web-AZ-A` et remplace le Security Group par `wordpress-efs-sg`.
* Pour la ligne `us-east-1b` : Sélectionne le sous-réseau applicatif privé `Private-Web-AZ-B` et remplace le Security Group par `wordpress-efs-sg`.




* Clique sur **Next** puis sur **Create**. Note l'identifiant du système de fichiers (ex: `fs-0123456789abcdef0`).
---

### Phase 3 : Compute & Haute Disponibilité (ALB & ASG)

1. **Préparation de la Launch Template :** Configurer un script utilisateur (*User Data*) pour installer Docker/Apache, PHP, télécharger WordPress et monter automatiquement le volume EFS ou configurer la connexion vers la base de données RDS.
2. **Configuration de l'ALB :** Placer le Load Balancer dans les sous-réseaux publics. Configurer le *Target Group* ciblant le port HTTP/HTTPS.
3. **Mise en place de l'ASG :** Lier l'ASG au Target Group de l'ALB. Définir des politiques de scaling (ex: déclencher une nouvelle instance si la consommation CPU moyenne dépasse 70%). **Placer impérativement les instances dans les sous-réseaux privés.**

---

Cette phase orchestre le déploiement de la puissance de calcul. Les instances hébergeant WordPress sont isolées au sein des sous-réseaux privés, tandis qu'un Application Load Balancer (ALB) public distribue le trafic entrant et assure la tolérance aux pannes.

#### Création préalable du Groupe de Sécurité pour le Load Balancer (SG-ALB)

L'ALB étant la seule porte d'entrée publique du site, il doit disposer de son propre pare-feu avant d'être créé.

* Va dans le service **VPC** > **Security Groups**.
* Clique sur **Create security group**.
* **Security group name :** `wordpress-alb-sg`
* **VPC :** `wordpress-vpc`
* **Inbound rules :** Ajoute deux règles d'entrée pour le trafic web mondial :
* *Règle 1 :* Type `HTTP (80)` | Source `Anywhere-IPv4 (0.0.0.0/0)`
* *Règle 2 :* Type `HTTPS (443)` | Source `Anywhere-IPv4 (0.0.0.0/0)`


* Sauvegarde le groupe de sécurité.

##### Mise à jour du Groupe de Sécurité de l'Application (SG-App)

Pour une sécurité maximale, les serveurs WordPress ne doivent accepter de requêtes *uniquement* si elles proviennent du Load Balancer.

* Sélectionne le groupe `wordpress-app-sg` créé à la Phase 2.
* Clique sur **Actions** > **Edit inbound rules**.
* Ajoute une règle : Type `HTTP (80)` | Source : Sélectionne le groupe de sécurité `wordpress-alb-sg`.
* Sauvegarde. Désormais, personne ne peut contourner le Load Balancer pour attaquer directement les serveurs.

#### Configuration du Target Group (Groupe de Cibles)

Le Target Group indique au Load Balancer vers quels ports et quelles machines router le trafic, ainsi que la méthode pour vérifier la bonne santé (*Health Checks*) des instances.

* Ouvre la console **EC2**, défile dans le menu de gauche et clique sur **Target Groups**.
* Clique sur **Create target group**.
* **Choose a target type :** Sélectionne **Instances**.
* **Target group name :** `wordpress-tg`
* **Protocol & Port :** `HTTP` sur le port `80`.
* **VPC :** Sélectionne `wordpress-vpc`.
* **Health checks :** Laisse le protocole `HTTP` et le chemin par défaut `/`.
* Clique sur **Next**. À l'étape *Register targets*, ne sélectionne aucune instance (l'Auto Scaling s'en chargera automatiquement plus tard).
* Clique sur **Create target group**.

#### Déploiement de l'Application Load Balancer (ALB)

* Dans le menu de gauche d'EC2, clique sur **Load Balancers**, puis sur **Create load balancer**.
* Sous la carte **Application Load Balancer**, clique sur **Create**.
* **Load balancer name :** `wordpress-alb`
* **Scheme :** `Internet-facing` (Public)
* **IP address type :** `IPv4`
* **Network mapping :**
* *VPC :* `wordpress-vpc`
* *Mappings (Crucial) :* Coche les deux zones de disponibilité et attribue-leur impérativement les **sous-réseaux publics** :
* Zone `us-east-1a` -> Sélectionne `Public-App-AZ-A`
* Zone `us-east-1b` -> Sélectionne `Public-App-AZ-B`




* **Security groups :** Retire le groupe `default` et associe uniquement **`wordpress-alb-sg`**.
* **Listeners and routing :** Sous le Listener `HTTP:80`, configure l'action *Forward to* en sélectionnant ton Target Group **`wordpress-tg`**.
* Clique sur **Create load balancer**. Note le **DNS name** généré une fois l'ALB actif (c'est l'URL publique de ton site).

#### Préparation de la Launch Template (Modèle de Lancement)

La Launch Template définit le profil type des serveurs qui seront créés dynamiquement (système d'exploitation, taille, script de démarrage).

* Dans le menu de gauche d'EC2, clique sur **Launch Templates**, puis sur **Create launch template**.
* **Launch template name :** `wordpress-template`
* **Application and OS Images (AMI) :** Choisis **Amazon Linux 2023** (éligible au Free Tier).
* **Instance type :** Sélectionne **`t2.micro`** (ou `t3.micro` selon l'éligibilité Free Tier de ton compte).
* **Key pair (login) :** Choisis une paire de clés existante ou crée-en une pour d'éventuels accès SSH de débogage (via un bastion).
* **Network settings :**
* *Firewall (Security Groups) :* Choisis *Select existing security group* et coche **`wordpress-app-sg`**.
* **Ne spécifie aucun sous-réseau ici**, c'est l'Auto Scaling Group qui gérera la distribution dans les zones.


* **Advanced details :** Défile tout en bas jusqu'au champ **User data** (Script de démarrage automatique) et injecte le script suivant en remplaçant les variables par tes propres identifiants (EFS, RDS, Valkey) :

```bash
#!/bin/bash
# Mise à jour du système
dnf update -y

# Installation d'Apache, PHP 8.2 et du client NFS pour EFS
dnf install -y httpd wget php php-mysqlnd php-gd php-xml php-mbstring amazon-efs-utils

# Démarrage et activation d'Apache
systemctl start httpd
systemctl enable httpd

# Configuration du montage EFS automatique du dossier wp-content
mkdir -p /var/www/html/wp-content
# Remplacer FILE_SYSTEM_ID par l'identifiant réel obtenu à la Phase 2 (ex: fs-0123456)
mount -t efs -o tls FILE_SYSTEM_ID:/ /var/www/html/wp-content
echo "FILE_SYSTEM_ID:/ /var/www/html/wp-content efs defaults,_netdev,tls 0 0" >> /etc/fstab

# Téléchargement et installation de WordPress
cd /var/www/html
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz --strip-components=1
rm latest.tar.gz

# Attribution des permissions appropriées pour Apache
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

```

* Clique sur **Create launch template**.

#### Mise en place de l'Auto Scaling Group (ASG)

L'ASG gère le cycle de vie des instances, garantit la haute disponibilité sur les deux zones et ajuste la capacité selon la charge.

* Dans le menu de gauche d'EC2, clique sur **Auto Scaling Groups**, puis sur **Create Auto Scaling group**.
* **Name :** `wordpress-asg`
* **Launch template :** Sélectionne `wordpress-template` et clique sur **Next**.
* **Network :**
* *VPC :* `wordpress-vpc`
* *Availability Zones and subnets (Sécurité Maximale) :* Choisis **impérativement** les deux **sous-réseaux privés applicatifs** :
* `Private-Web-AZ-A`
* `Private-Web-AZ-B`


* Clique sur **Next**.


* **Configure advanced options :**
* *Load balancing :* Coche **Attach to an existing load balancer**.
* *Choose from your load balancer target groups :* Sélectionne **`wordpress-tg`**.
* *Health checks :* Coche **Elastic Load Balancing (ELB)** en plus d'EC2 (permet à l'ASG de remplacer une instance si le serveur Apache crashe, même si la VM reste allumée).
* Clique sur **Next**.


* **Configure group size and scaling policies :**
* *Desired capacity :* `2` (Garantit la présence constante d'une instance par AZ).
* *Minimum capacity :* `2`
* *Maximum capacity :* `4` (Limite haute pour maîtriser les coûts).
* *Scaling policies :* Sélectionne **Target tracking scaling policy**.
* *Metric type :* `Average CPU utilization`
* *Target value :* `70` (Si la moyenne CPU dépasse 70 %, une nouvelle instance est créée).


* Clique sur **Next**, passe les étapes de notifications/tags et clique sur **Create Auto Scaling group**.



L'infrastructure hautement disponible est pleinement opérationnelle. L'ASG va automatiquement démarrer tes 2 premières instances EC2 dans les sous-réseaux privés, monter le volume EFS partagé, et le Load Balancer commencera à diriger le trafic public vers elles dès que leur script d'installation aura fini de s'exécuter.

---

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
