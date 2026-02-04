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

### Réseau (Subnet Tiers)

```
VPC: 10.0.0.0/16
├─ Public Layer  (10.0.0.0/20)  → ALB, NAT, Bastion
├─ Private Layer (10.0.16.0/20) → EKS Nodes
├─ Data Layer    (10.0.32.0/21) → RDS
└─ Réservé       (10.0.40.0/21) → Cache, VPN
```

**Multi-AZ** : 3 zones (eu-central-1a/b/c) pour haute disponibilité

---

### 📁 Structure du Projet

```
hetic-friday/
├── live/                             # Infrastructure déployée "Live"
│   ├── root.hcl                      # Config racine (backend S3)
<<<<<<< HEAD
<<<<<<< HEAD
│   ├── dev/                          # Env Dev
│   │   └── monitoring/
│   │       └── terragrunt.hcl
│   │   └── networking/
│   │       └── terragrunt.hcl        
│   │       └── secrets.yaml
│   ├── prod/                         # Env Prod
│   │   └── monitoring/
│   │       └── terragrunt.hcl
│   │   └── networking/
│   │       └── terragrunt.hcl        
│   │       └── secrets.yaml
=======
=======
>>>>>>> edf3cca (update readme config informations)
│   ├── dev/
│   │   └── secrets.hcl
│   │   └── vpc/
│   │       └── terragrunt.hcl        # Env Dev
│   │   └── rds/
│   │       └── terragrunt.hcl
│   │   └── security/
│   │       └── terragrunt.hcl
│   └── prod/
│       └── secrets.hcl
│       └── vpc/
│           └── terragrunt.hcl        # Env Prod
│       └── rds/
│           └── terragrunt.hcl
│       └── security/
│           └── terragrunt.hcl
<<<<<<< HEAD
>>>>>>> 7557546 (feat: add terraform modules for rds and security)
=======
=======
│   ├── dev/                          # Env Dev
│   │   └── monitoring/
│   │       └── terragrunt.hcl
│   │   └── networking/
│   │       └── terragrunt.hcl        
│   │       └── secrets.yaml
│   ├── prod/                         # Env Prod
│   │   └── monitoring/
│   │       └── terragrunt.hcl
│   │   └── networking/
│   │       └── terragrunt.hcl        
│   │       └── secrets.yaml
>>>>>>> 7d05924 (update readme config informations)
>>>>>>> edf3cca (update readme config informations)
├── terraform/                        # Code source des modules
│   └── modules/
│       └── vpc/
│           ├── main.tf
│           └── ...
└── .gitignore
```

### Config

Ajouter le fichier secrets.yaml en dev et en prod avec ces variables :

```
alert_email: "exemple@email.com"
```

### 🛠️ Déploiement

**1. Environnement de Dev (Recommandé)**
Si bucket S3 n'est pas créé :

```bash
cd live/dev/
terragrunt run --all --backend-bootstrap init
```

ou

```bash
cd live/dev/
terragrunt run --all apply
```

**2. Environnement de Prod**

```bash
cd live/prod/
terragrunt run --all apply
```

### 💥 Destruction (Nettoyage)

**1. Détruire les ressources AWS**

```bash
cd live/dev/
terragrunt run --all destroy
```

**2. Destruction Totale (State inclus)**
Pour tout supprimer définitivement (y compris le backend S3) :

1. Détruire l'environnement (`terragrunt destroy`).
2. Utiliser le script de nettoyage fourni pour vider le bucket versionné :

```bash
chmod +x scripts/empty_bucket.sh
./scripts/empty_bucket.sh hetic-friday-g2-terraform-state
```

3. Supprimer le bucket et la table DynamoDB et Cloud Watch:

```bash
aws s3 rb s3://hetic-friday-g2-terraform-state --force
aws dynamodb delete-table --table-name hetic-friday-g2-terraform-locks --region eu-central-1
aws logs delete-log-group --log-group-name /aws/vpc/hetic_friday_g2-dev --region eu-central-1
```

---

## 📚 Documentation

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Google Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo)

---

## 👥 Équipe

**Groupe 2** - HETIC MT5  
Naming convention : `hetic_friday_g2`
