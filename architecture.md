# Architecture Cloud - Hetic Friday (Black Friday Simulation)

Ce document décrit en détail l'infrastructure cloud déployée sur AWS pour supporter le projet Google Online Boutique avec une charge cible de 90K utilisateurs.

---

## 1. Stratégie Globale

L'architecture est conçue autour de trois piliers principaux :
1.  **Haute Disponibilité (HA)** : Résilience à la perte d'une zone de disponibilité (AZ).
2.  **Scalabilité Élastique** : Capacité à absorber des pics de trafic massifs (Black Friday).
3.  **Optimisation des Coûts (FinOps)** : Utilisation intelligente des ressources (Spot, sizing).

### Environnements
Nous utilisons une stratégie multi-comptes ou multi-environnements logiques :
*   **Dev** : Environnement de test et d'intégration.
    *   *Optimisation* : 1 seul NAT Gateway, instances Spot, taille réduite.
    *   *Objectif* : Valider le code et l'infrastructure à moindre coût.
*   **Prod** : Environnement de production critique.
    *   *Architecture* : Multi-AZ complet (3 zones), instances On-Demand + Spot, Database Multi-AZ.
    *   *Objectif* : Performance et disponibilité maximale (SLA 99.9%).

---

## 2. Réseau (AWS VPC)

Le réseau est la fondation de l'infrastructure. Nous utilisons une topologie "Hub & Spoke" simplifiée au sein d'un VPC unique par environnement.

### 2.1. Découpage IP (Architecture en Couches)
Nous utilisons un découpage CIDR strict pour garantir l'évolutivité et la sécurité.
*   **VPC CIDR** : `10.0.0.0/16` (65 536 IPs disponibles).

Les sous-réseaux sont organisés en couches logiques (Tiers) :
*   **Public Layer (`10.0.0.0/20`)** :
    *   Contient : Load Balancers (ALB), NAT Gateways, Bastion.
    *   *Pourquoi ?* Ce sont les seuls composants qui doivent être exposés (directement ou indirectement) à Internet.
*   **Private Layer (`10.0.16.0/20`)** :
    *   Contient : Nodes Kubernetes (EKS), Pods applicatifs.
    *   *Pourquoi ?* Les applications ne doivent jamais être accessibles directement. Elles passent par l'ALB.
*   **Data Layer (`10.0.32.0/21`)** :
    *   Contient : Bases de données (RDS), Cache (ElastiCache).
    *   *Pourquoi ?* Isolation maximale. Pas de route vers Internet, uniquement accessible depuis le Private Layer.

### 2.2. Connectivité
*   **Internet Gateway (IGW)** : Permet le trafic entrant/sortant pour le Public Layer.
*   **NAT Gateway** : Permet aux instances privées (EKS) d'accéder à Internet (ex: télécharger des images Docker, mises à jour) sans être exposées.
    *   *Prod* : 1 NAT par AZ (Haute dispo). Si une AZ tombe, les autres continuent de fonctionner.
    *   *Dev* : 1 seul NAT (Économie ~60€/mois).

---

## 3. Compute (Amazon EKS)

Nous utilisons **Elastic Kubernetes Service (EKS)** pour orchestrer les microservices.

### 3.1. Control Plane
Géré par AWS. Nous ne voyons pas les masters nodes. AWS assure leur réplication et leur sécurité.

### 3.2. Data Plane (Worker Nodes)
Nous utilisons des **Managed Node Groups** pour simplifier la gestion (mises à jour, scaling).

**Stratégie Mixte (On-Demand + Spot) :**
Nous créons deux groupes de nœuds distincts :
1.  **System Node Group (On-Demand)** :
    *   Héberge les pods critiques (CoreDNS, Ingress Controller, Logging agents).
    *   *Pourquoi ?* On ne veut pas que ces services soient interrompus. On paye le prix fort pour la stabilité.
2.  **App Node Group (Spot Instances)** :
    *   Héberge les pods de l'application (Frontend, Cart, ProductCatalog...).
    *   *Pourquoi ?* Les instances Spot coûtent **-70%**. Kubernetes est conçu pour gérer la perte de nœuds (les pods sont replanifiés ailleurs). C'est idéal pour le Black Friday.

### 3.3. Autoscaling
*   **HPA (Horizontal Pod Autoscaler)** : Ajoute des Pods quand le CPU/RAM dépasse 70%.
*   **Cluster Autoscaler** : Ajoute des Nodes (EC2) quand les Pods n'ont plus de place.

---

## 4. Données (Bases de données)

### 4.1. RDS PostgreSQL
Le service de panier et de commande nécessite de la persistance.
*   **Engine** : PostgreSQL (robuste, open-source).
*   **Multi-AZ (Prod)** : Une instance primaire + une instance standby dans une autre AZ. Replication synchrone.
    *   *Pourquoi ?* Si l'AZ primaire brûle, bascule automatique sur la standby sans perte de données.
*   **Storage** : GP3 (General Purpose SSD) pour un bon équilibre perf/prix.

### 4.2. ElastiCache (Redis)
Utilisé pour le caching rapide (session utilisateur, catalogue produits fréquents).
*   *Pourquoi ?* Réduit la charge sur la base de données principale et accélère le temps de réponse.

---

## 5. Sécurité ("Défense en Profondeur")

### 5.1. Network Security
*   **NACLs** : Pare-feu sans état au niveau des subnets (filtrage large).
*   **Security Groups** : Pare-feu avec état au niveau des instances (filtrage fin).
    *   *Règle d'or* : Un SG ne s'ouvre que vers un autre SG (ex: RDS n'accepte que le trafic venant du SG EKS).

### 5.2. IAM & Identité
*   **IRSA (IAM Roles for Service Accounts)** : C'est une fonctionnalité clé d'EKS.
    *   Au lieu de donner les permissions au Nœud (EC2), on les donne au **Pod**.
    *   *Exemple* : Seul le pod "S3-Service" a le droit d'écrire dans S3. Les autres pods ne peuvent pas. C'est le principe du moindre privilège.

### 5.3. Protection Edge
*   **WAF (Web Application Firewall)** : Placé devant l'ALB. Protège contre les attaques SQL Injection, XSS, et le DDoS basique.
*   **AWS Shield Standard** : Protection DDoS native d'AWS.

---

## 6. Observabilité

Pour comprendre ce qui se passe durant le crash test :
*   **Metrics** : Prometheus (récolte) + Grafana (visualisation). On suit CPU, RAM, Latence, Requêtes/sec.
*   **Logs** : CloudWatch Logs (centralisation).
*   **Tracing** : Jaeger ou AWS X-Ray (optionnel) pour suivre une requête à travers les microservices.

---

## Résumé des Choix Techniques

| Choix | Alternative rejetée | Pourquoi ? |
| :--- | :--- | :--- |
| **Terragrunt** | Terraform pur | Pour le DRY (éviter de copier-coller le code entre dev et prod). |
| **EKS** | ECS / EC2 | Standard de l'industrie, écosystème immense (Helm, opérateurs). |
| **Spot Instances** | Tout On-Demand | Réduction drastique des coûts (-70%) pour la charge massive. |
| **PostgreSQL** | MySQL / NoSQL | Fiabilité des transactions (ACID) critique pour les commandes/paiements. |
