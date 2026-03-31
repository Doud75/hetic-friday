# Security Hardening — Renforcement de la sécurité Cloud

## Contexte

Le cahier des charges consacre **20% de la note** à la sécurité cloud. L'audit initial a révélé que les couches fondamentales (Security Groups, WAF, Secrets Manager) étaient en place, mais plusieurs éléments explicitement demandés manquaient : NACLs, vulnerability scanning, encryption at rest, et audit réseau.

## Ce qui a été implémenté

### 1. Network ACLs (NACLs) — Défense en profondeur

**Fichier modifié** : `terraform/modules/vpc/main.tf`

Les NACLs ajoutent une couche de sécurité **stateless** au niveau du subnet, en complément des Security Groups (stateful au niveau de l'instance).

#### 3 NACLs créées

| NACL | Subnets | Logique |
|---|---|---|
| **Public** | Subnets publics (ALB, NAT, Bastion) | Autorise HTTP/HTTPS/SSH entrant + éphémères pour les réponses |
| **Private** | Subnets privés (EKS nodes) | Autorise tout le trafic intra-VPC + éphémères depuis Internet (réponses NAT) |
| **Data** | Subnets data (RDS) | N'autorise **que** PostgreSQL (5432) depuis les subnets privés — isolation maximale |

#### Pourquoi NACLs + Security Groups ?

C'est le principe de **défense en profondeur** recommandé par le AWS Well-Architected Framework :

```
Internet → NACL (stateless, subnet) → Security Group (stateful, instance) → Application
```

- Les **NACLs** filtrent le trafic au niveau du subnet (avant même d'atteindre l'instance)
- Les **Security Groups** filtrent au niveau de l'instance/ENI avec du suivi d'état

Si un Security Group est mal configuré (ex: quelqu'un ouvre 0.0.0.0/0 par erreur), la NACL empêche quand même le trafic non autorisé.

#### NACL Data — le choix le plus important

La NACL `data` est la plus restrictive : elle n'autorise **que** le port 5432 (PostgreSQL) depuis les CIDRs des subnets privés. Même si un attaquant compromet un pod dans le cluster, il ne peut pas scanner d'autres ports sur la base de données.

### 2. VPC Flow Logs — Audit réseau

**Fichier modifié** : `terraform/modules/vpc/main.tf`

Les VPC Flow Logs capturent **tout le trafic réseau** (ACCEPT + REJECT) et l'envoient vers CloudWatch Logs.

#### Pourquoi c'est essentiel ?

- **Debugging** : Identifier pourquoi une connexion échoue (SG ou NACL qui bloque ?)
- **Audit sécurité** : Détecter les tentatives de connexion suspectes
- **Post-mortem** : Après un incident, analyser exactement quel trafic a circulé
- **Compliance** : Exigence standard pour les environnements de production

#### Rétention

| Environnement | Rétention | Pourquoi |
|---|---|---|
| Prod | 30 jours | Assez pour couvrir le cycle du Black Friday + post-mortem |
| Dev | 7 jours | Suffisant pour le debugging, réduit les coûts CloudWatch |

#### Pourquoi CloudWatch Logs vs S3 ?

| Destination | Verdict | Raison |
|---|---|---|
| **CloudWatch Logs** ✅ | Choisi | Recherche en temps réel via Logs Insights, intégration native avec les alarmes, pas besoin de setup supplémentaire |
| S3 | Rejeté | Moins cher pour le stockage long terme, mais nécessite Athena ou un ETL pour analyser |
| Kinesis | Rejeté | Overkill pour notre volume de trafic |

### 3. Encryption at rest — RDS

**Fichier modifié** : `terraform/modules/rds/main.tf`

```hcl
storage_encrypted = true
```

Active le chiffrement AES-256 sur les disques de la base de données, via la clé KMS managée par AWS (`aws/rds`).

#### Pourquoi la clé managée par AWS plutôt qu'une CMK ?

| Option | Verdict | Raison |
|---|---|---|
| **Clé managée AWS** ✅ | Choisi | Gratuit, pas de rotation à gérer, suffisant pour notre use case pédagogique |
| CMK (Customer Managed Key) | Rejeté | Plus de contrôle (politique de rotation, accès granulaire), mais coût supplémentaire (~1 USD/mois) et complexité de gestion |

#### Performance Insights ajouté

```hcl
performance_insights_enabled          = true
performance_insights_retention_period = 7
```

Gratuit sur `db.t3.micro`, permet de visualiser les requêtes SQL lentes et les goulots de performance — utile pendant les tests de charge.

### 4. Trivy — Scan de vulnérabilités des images Docker

**Fichier modifié** : `.github/workflows/ci-main.yaml`

Ajout d'un step **Trivy** entre le build et le push de l'image Docker :

```yaml
- name: Trivy vulnerability scan
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: <image>
    format: 'table'
    exit-code: '1'           # Fait échouer le build si CVE trouvée
    severity: 'CRITICAL,HIGH'
    ignore-unfixed: true     # Ignore les CVEs sans correctif disponible
```

#### Pourquoi Trivy vs les alternatives ?

| Outil | Verdict | Raison |
|---|---|---|
| **Trivy** ✅ | Choisi | Open source, rapide (~30s), base de CVE mise à jour quotidiennement, GitHub Action officielle, scan OS + dépendances |
| Snyk | Rejeté | Excellent mais freemium — limité en nombre de scans sur le plan gratuit |
| Grype (Anchore) | Rejeté | Bon outil mais moins mature que Trivy, communauté plus petite |
| AWS ECR scan natif | Rejeté | Basique (Clair sous le capot), pas de contrôle sur les seuils de sévérité |
| OWASP ZAP | Complémentaire | ZAP scanne les **applications web** en runtime (DAST), pas les images. C'est un scan différent, pas une alternative à Trivy |

#### Choix de configuration

- **`exit-code: '1'`** : Le build échoue si Trivy trouve des CRITICAL ou HIGH. Force l'équipe à corriger avant de pousser en prod.
- **`ignore-unfixed: true`** : Pragmatique — ne bloque pas sur des CVEs pour lesquelles aucun correctif n'existe encore.
- **`severity: 'CRITICAL,HIGH'`** : On ne bloque pas sur MEDIUM/LOW pour ne pas paralyser le CI.

## Impact sur la note

| Critère sécurité (20 pts) | Avant | Après |
|---|---|---|
| NACLs | ❌ | ✅ |
| VPC Flow Logs | ❌ | ✅ |
| Encryption at rest | ❌ | ✅ |
| Vulnerability Scanning (Trivy) | ❌ | ✅ |
| **Gain estimé** | — | **+4-5 points** |

## Vérification

```bash
# Valider le module VPC modifié
cd terraform/modules/vpc && terraform init -backend=false && terraform validate

# Valider le module RDS modifié
cd terraform/modules/rds && terraform init -backend=false && terraform validate
```
