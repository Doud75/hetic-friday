# Black Friday Survival - Projet HETIC MT5

Simulation de crise e-commerce sur AWS avec Google Online Boutique.

**Objectif** : Tenir 90K utilisateurs simultanés sans crash  
**Durée** : 3 semaines + 2 jours de démo  
**Budget** : 1 500€ - 2 000€

---

## 🏗️ Architecture

### Infrastructure
- **Cloud Provider** : AWS (région `eu-central-1` - Frankfurt)
- **IaC** : Terraform + Terragrunt
- **Orchestration** : Amazon EKS (Kubernetes)
- **Database** : RDS PostgreSQL (Multi-AZ + Read Replicas)
- **Monitoring** : CloudWatch + Prometheus + Grafana

### Réseau (CIDR Bataillons)
```
VPC: 10.0.0.0/16
├─ Bataillon Public  (10.0.0.0/20)  → ALB, NAT, Bastion
├─ Bataillon Private (10.0.16.0/20) → EKS Nodes
├─ Bataillon Data    (10.0.32.0/21) → RDS
└─ Réservé           (10.0.40.0/21) → Cache, VPN
```

**Multi-AZ** : 3 zones (eu-central-1a/b/c) pour haute disponibilité

---

## 📁 Structure du Projet

```
hetic-friday/
├── terragrunt.hcl                    # Config racine (backend S3)
├── terraform/
│   └── modules/
│       └── networking/               # Module VPC ✅
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── versions.tf
├── environments/
│   ├── dev/
│   │   └── networking/
│   │       └── terragrunt.hcl       # 1 NAT Gateway
│   └── prod/
│       └── networking/
│           └── terragrunt.hcl       # 3 NAT Gateways (1/AZ)
└── .gitignore
```

---

## 🚀 Démarrage Rapide

### Prérequis
- **AWS CLI** configuré (`aws configure`)
- **Terragrunt** installé (`brew install terragrunt`)

### 🛠️ Déploiement

**1. Environnement de Dev (Recommandé)**
```bash
cd environments/dev/networking
terragrunt apply
```
*Note : Si Terragrunt demande de créer le bucket S3, répondez `y`.*

**2. Environnement de Prod**
```bash
cd environments/prod/networking
terragrunt apply
```

### 💥 Destruction (Nettoyage)

**1. Détruire les ressources AWS**
Cela supprime l'infrastructure (VPC, NAT, etc.) mais conserve l'état dans S3 :
```bash
cd environments/dev/networking
terragrunt destroy
```

**2. Destruction Totale (State inclus)**
Pour tout supprimer définitivement (y compris le backend S3) :
1. Détruire l'environnement (`terragrunt destroy`).
2. Utiliser le script de nettoyage fourni pour vider le bucket versionné :
```bash
chmod +x scripts/empty_bucket.sh
./scripts/empty_bucket.sh hetic-friday-g2-terraform-state
```
3. Supprimer le bucket et la table DynamoDB :
```bash
aws s3 rb s3://hetic-friday-g2-terraform-state --force
aws dynamodb delete-table --table-name hetic-friday-g2-terraform-locks --region eu-central-1
```

---

## 📚 Documentation

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Google Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo)

---

## 👥 Équipe

**Groupe 2** - HETIC MT5  
Naming convention : `hetic_friday_g2`
