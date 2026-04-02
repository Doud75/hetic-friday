# Rapport FinOps — Black Friday Survival
**Projet MT5 — HETIC**
**Équipe G2 — Avril 2026**

---

## Introduction

Ce rapport présente la stratégie FinOps mise en œuvre pour le projet Black Friday Survival, une simulation d'infrastructure e-commerce à haute disponibilité déployée sur AWS. L'objectif technique était de tenir 90 000 utilisateurs simultanés sans défaillance ; l'objectif financier, d'y parvenir dans une enveloppe budgétaire de 1 500 à 2 000 €, répartie sur trois semaines de construction et deux jours de démo finale.

La démarche FinOps adoptée repose sur trois piliers : **visibilité** (savoir ce qui est dépensé et pourquoi), **optimisation** (choisir les bons types de ressources au bon moment), et **gouvernance** (alertes et limites pour éviter les dépassements). Ces trois dimensions sont détaillées dans les sections suivantes.

---

## 1. Principes directeurs de la gestion des coûts

### Différencier dev et prod

L'une des décisions les plus structurantes a été de traiter les environnements `dev` et `prod` de manière asymétrique. En développement, la disponibilité n'est pas critique : on peut accepter un point de défaillance unique sur le réseau pour économiser. En production, la résilience prime.

Concrètement, cela se traduit par :
- Un **seul NAT Gateway** en dev contre **trois en prod** (un par zone de disponibilité). La différence de coût est d'environ 64 €/mois, mais elle achète la garantie que la perte d'une AZ ne coupe pas l'accès Internet des nœuds EKS.
- Une RDS **Single-AZ** en dev contre **Multi-AZ** en prod, ce qui double le coût de la base mais assure le basculement automatique en cas de défaillance matérielle.
- Des **budgets AWS distincts** : 250\$/mois pour le dev, 600\$/mois pour la prod, avec des alertes indépendantes.

Cette séparation nette évite le gaspillage classique consistant à maintenir un environnement de développement au niveau de la production.

### Spot Instances pour les charges applicatives

Les nœuds EKS sont divisés en deux groupes de fonctions avec des stratégies d'achat différentes.

Le **groupe système** (qui héberge CoreDNS, les ingress controllers, les agents de logs) tourne sur des instances On-Demand. Ces composants sont critiques et ne peuvent se permettre d'être interrompus par AWS avec deux minutes de préavis. Le coût plus élevé est justifié par la stabilité qu'ils apportent à l'ensemble du cluster.

Le **groupe applicatif** (qui héberge les onze microservices de la boutique) utilise des **Spot Instances**. AWS peut récupérer ces instances en cas de manque de capacité, mais Kubernetes gère automatiquement la migration des pods vers d'autres nœuds. La réduction de coût est substantielle : entre 60 et 70 % par rapport au tarif On-Demand pour des types d'instances équivalents. Sur un cluster dimensionné pour 90 000 utilisateurs, cela représente plusieurs centaines d'euros d'économies sur la durée du projet.

---

## 2. Architecture réseau et implications budgétaires

### VPC et subnets

Le réseau est découpé en trois couches sur trois zones de disponibilité (eu-central-1a, eu-central-1b, eu-central-1c) :

- **Couche publique** (10.0.0.0/20) : ALB, NAT Gateways, Bastion Host
- **Couche privée** (10.0.16.0/20) : nœuds EKS worker
- **Couche données** (10.0.32.0/21) : RDS PostgreSQL

Cette segmentation a un impact direct sur les coûts : les nœuds EKS dans les subnets privés doivent passer par les NAT Gateways pour accéder à Internet (images Docker, API AWS, etc.). Chaque gigaoctet de trafic sortant coûte 0,045 \$/GB en transfert NAT. Pendant les phases de charge intense (tests à 50K puis 90K utilisateurs), ce poste peut monter rapidement.

Pour limiter ce coût, des **VPC Endpoints** ont été configurés pour les services AWS les plus sollicités (ECR, S3, CloudWatch Logs). Ces endpoints permettent au trafic de rester sur le réseau privé AWS sans passer par les NAT Gateways — les endpoints de type *gateway* pour S3 sont gratuits, ce qui est particulièrement intéressant pour les téléchargements d'images depuis ECR.

### Load Balancer et WAF

L'Application Load Balancer coûte environ 16,43 \$/mois en charge fixe, auxquels s'ajoutent les LCUs (Load Balancer Capacity Units) proportionnels au trafic. Lors du pic à 90K utilisateurs, ce poste est non négligeable mais difficile à réduire sans compromettre la disponibilité.

Le WAF (Web Application Firewall) ajoute 5 \$/mois de base plus 0,60 $ par million de requêtes. Son rôle ici dépasse la sécurité pure : il protège également le budget en limitant le trafic abusif qui consommerait inutilement des LCUs et des ressources de compute. Une règle de rate-limiting à 2 000 requêtes par tranche de 5 minutes par IP a été configurée, avec une whitelist pour les IPs de load testing afin de ne pas bloquer les scénarios Locust légitimes.

---

## 3. Auto-scaling et élasticité

### Horizontal Pod Autoscaler (HPA)

L'un des leviers les plus puissants pour optimiser les coûts en période de charge variable est l'autoscaling horizontal des pods. Plutôt que de provisionner au maximum en permanence, les HPAs permettent d'ajuster dynamiquement le nombre de répliques en fonction de la charge réelle.

La stratégie retenue pour ce projet utilise deux métriques déclenchantes :
- CPU à 70 % d'utilisation
- Mémoire à 80 % d'utilisation

Les seuils de scaling par service ont été calibrés en fonction de leur criticité et de leur consommation de ressources :

| Service | Min répliques | Max répliques | Justification |
|---|---|---|---|
| Frontend (nginx-cache-proxy) | 20 | 200 | Point d'entrée unique, trafic maximal |
| Cartservice | 5 | 100 | Opérations fréquentes, état Redis |
| ProductCatalogservice | 5 | 80 | Lectures intensives, cache possible |
| CurrencyService | 3 | 50 | Haute fréquence de requêtes |
| RecommendationService | 3 | 60 | Calculs ML intensifs |
| CheckoutService | 3 | 40 | Critique mais moins sollicité |

La politique de scale-up est volontairement agressive (doublement toutes les 15 secondes) pour absorber les montées en charge brusques typiques d'un Black Friday. La politique de scale-down est plus conservatrice (fenêtre de stabilisation de 5 minutes) pour éviter de détruire des pods encore utiles lors de brèves accalmies.

### Cluster Autoscaler

Au niveau des nœuds EC2, le Cluster Autoscaler surveille les pods en état `Pending` (ceux qui ne trouvent pas de nœud avec suffisamment de ressources) et provisionne automatiquement de nouveaux nœuds Spot. Inversement, il déprovisionne les nœuds sous-utilisés en dehors des pics de charge. Cette mécanique garantit que le cluster ne tourne pas avec des nœuds idle coûteux pendant les phases de faible activité.

---

## 4. Base de données et stockage

### RDS PostgreSQL

La base de données utilise une instance `db.t3.micro`, le tier le plus bas de la famille T3. Ce choix s'explique par le fait que Online Boutique est une application qui utilise principalement Redis pour le panier et des fichiers JSON pour le catalogue : la charge effective sur PostgreSQL est modérée. Le coût est d'environ 12 \$/mois pour une instance Single-AZ, doublé en Multi-AZ en production.

Performance Insights est activé avec une rétention de 7 jours (inclus dans le prix pour les instances T3). Cela a permis d'identifier et corriger des requêtes lentes pendant les tests de charge, sans coût additionnel.

### Prometheus et stockage EBS

Le stack de monitoring (Prometheus + Grafana) stocke ses données sur des volumes EBS. La rétention a été calibrée finement : 7 jours en développement, 15 jours en production. Ces valeurs sont suffisantes pour analyser les incidents post-test tout en limitant le stockage (et donc le coût EBS à 0,10 \$/GB/mois).

Jaeger, l'outil de tracing distribué, fonctionne en mode *all-in-one* avec un stockage en mémoire limité à 10 000 traces. Cette décision délibérément pragmatique évite d'avoir à provisionner un cluster Cassandra ou Elasticsearch, qui représenterait plusieurs centaines d'euros mensuels supplémentaires pour un usage ponctuel en contexte projet.

---

## 5. Gouvernance budgétaire

### AWS Budgets

Quatre alertes sont configurées sur le budget mensuel global :

1. **50 % consommé** : alerte informative, signal que la moitié du mois est probablement atteinte
2. **80 % consommé** : alerte d'avertissement, invite à vérifier les ressources inutilement actives
3. **100 % consommé** : alerte critique, le budget est dépassé
4. **100 % prévu** (forecast) : alerte prédictive basée sur la tendance de consommation actuelle, permet d'agir avant d'atteindre la limite

Des budgets par service (EKS, EC2, RDS) complètent le dispositif avec une alerte unique à 80 %, ce qui permet d'isoler rapidement le service qui consomme anormalement sans noyer l'équipe sous les notifications.

### Tagging des ressources

Toutes les ressources AWS sont taguées avec un ensemble minimal de métadonnées : `Project`, `Environment`, `ManagedBy` (Terraform), et `Team`. Ces tags permettent d'utiliser AWS Cost Explorer pour filtrer et analyser les coûts par dimension, ce qui est essentiel pour les reporting hebdomadaires et pour identifier les anomalies.

---

## 6. État de la gestion du Terraform et coûts annexes

### Backend S3 + DynamoDB

L'état Terraform est stocké dans un bucket S3 (`hetic-friday-g2-terraform-state`) avec verrouillage via DynamoDB. Ces deux services ont un coût marginal : quelques centimes par mois pour le stockage S3 (moins de 100 Mo d'état) et environ 1,25 \$/mois pour DynamoDB en mode on-demand. Le versioning S3 est activé, ce qui permet de revenir en arrière sur l'état en cas d'opération destructrice — une assurance raisonnable pour un coût négligeable.

### Secrets Manager

Les credentials de base de données sont stockés dans AWS Secrets Manager (0,40 \$/secret/mois). C'est un coût délibéré, préféré à la gestion manuelle de fichiers `.env` ou à l'injection de secrets en clair dans les manifestes Kubernetes.

---

## 7. Estimation budgétaire par semaine

Le budget alloué au projet a été découpé en phases cohérentes avec les jalons pédagogiques.

**Semaine 1 — Setup & Fondations (cible : 150-250 €)**
Durant cette phase, l'infrastructure de base est déployée : VPC, EKS, RDS. Les coûts sont faibles car le cluster tourne avec un minimum de nœuds et les tests de charge restent modestes (1 000 utilisateurs).

**Semaine 2 — Hardening & Optimisation (cible : 400-600 €)**
C'est la semaine la plus intensive en coûts variables. Les tests montent jusqu'à 50 000 utilisateurs, ce qui provoque des scale-up significatifs sur les nœuds Spot et les pods HPA. Le WAF, le monitoring complet (Prometheus, Grafana, Jaeger) et la configuration Multi-AZ sont actifs.

**Semaine 3 — Pre-Black Friday (cible : 500-700 €)**
La répétition générale à 70 000 utilisateurs et le chaos engineering (AWS FIS) représentent les pics de consommation les plus élevés avant la démo. L'optimisation des coûts (rightsizing, ajustement des limites HPA, vérification des ressources orphelines) est activement menée cette semaine.

**Jours de démo (cible : 150-250 €)**
La simulation finale sur 8 heures est coûteuse par heure mais brève. L'enjeu est de ne pas laisser tourner l'infrastructure avant ou après les créneaux de démo.

| Phase | Budget cible | Principales sources de coût |
|---|---|---|
| Semaine 1 | 150-250 € | EKS (nœuds On-Demand), RDS, VPC |
| Semaine 2 | 400-600 € | Scale-up Spot, NAT trafic, ALB LCUs |
| Semaine 3 | 500-700 € | Tests 70K, FIS, optimisation |
| Démo (2j) | 150-250 € | Pic 90K, ALB, trafic NAT |
| Marge | 120-200 € | Ressources orphelines, dépassements |
| **Total** | **1 320-2 000 €** | |

---

## 8. Bonnes pratiques appliquées et recommandations

### Ce qui a été mis en place

- Utilisation systématique de Spot Instances pour les charges non critiques
- Autoscaling horizontal et vertical configuré avec des seuils mesurés
- Séparation stricte dev/prod pour éviter le sur-provisionnement
- Monitoring budgétaire multi-niveaux (global + par service)
- Lifecycle policy ECR pour supprimer les images non taguées après 24h
- VPC Endpoints pour réduire le trafic NAT vers les services AWS

### Ce qui pourrait être amélioré

**Extinction automatique des environnements hors horaires.** Un Lambda déclenché par EventBridge pourrait éteindre le cluster dev les nuits et week-ends. Pour un cluster actif 8h/jour sur 5 jours, le gain serait de l'ordre de 60 à 80 % du coût de compute dev — soit plusieurs dizaines d'euros par semaine.

**Savings Plans ou Reserved Instances.** Si le projet devait se prolonger au-delà de son périmètre actuel, l'achat de Compute Savings Plans pour 1 an permettrait des réductions de 30 à 50 % sur les instances On-Demand du groupe système. Ce n'est pas pertinent sur 3 semaines, mais c'est une décision à anticiper pour toute continuité opérationnelle.

**Métriques custom pour l'autoscaling.** Les HPAs actuels se basent sur CPU et mémoire. Des métriques applicatives (nombre de requêtes HTTP en attente, longueur de queue Redis) permettraient un scaling plus précis et donc plus économique, évitant de sur-provisionner par précaution sur des services dont la consommation CPU n'est pas corrélée à la charge réelle.

---

## Conclusion

La stratégie FinOps mise en œuvre sur ce projet repose sur un principe de **proportionnalité** : les ressources les plus résilientes et les plus coûteuses sont concentrées là où elles apportent une valeur réelle (nœuds système On-Demand, Multi-AZ prod, WAF), tandis que les charges variables sont absorbées par des mécanismes élastiques et économiques (Spot Instances, HPA, VPC Endpoints).

Le budget estimé de 1 320 à 2 000 € est atteignable à condition de maintenir une discipline opérationnelle : éteindre les ressources inutilisées entre les phases, surveiller les alertes budgétaires et agir dès le seuil à 80 %, et éviter de laisser des NAT Gateways ou des Load Balancers actifs en dehors des fenêtres de test.

La combinaison Terraform + Terragrunt pour l'IaC garantit que l'infrastructure est reproductible et auditable, ce qui facilite également l'analyse rétrospective des coûts : chaque ressource est tracée, taguée, et peut être corrélée à une phase du projet via l'historique Git et les tags `Environment`.