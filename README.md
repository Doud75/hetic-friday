# Black Friday Survival - Projet HETIC MT5

Simulation de crise e-commerce sur AWS avec Google Online Boutique.

**Objectif** : Tenir 90K utilisateurs simultanés sans crash

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
├── live/
│   ├── root.hcl
│   ├── dev/
│   │   ├── secrets.hcl
│   │   ├── vpc/
│   │   │   └── terragrunt.hcl
│   │   ├── security/
│   │   │   └── terragrunt.hcl
│   │   ├── rds/
│   │   │   └── terragrunt.hcl
│   │   ├── eks/
│   │   │   └── terragrunt.hcl
│   │   └── monitoring/
│   │       └── terragrunt.hcl
│   └── prod/
│       ├── secrets.hcl
│       ├── vpc/
│       │   └── terragrunt.hcl
│       ├── security/
│       │   └── terragrunt.hcl
│       ├── rds/
│       │   └── terragrunt.hcl
│       ├── eks/
│       │   └── terragrunt.hcl
│       └── monitoring/
│           └── terragrunt.hcl
├── terraform/
│   └── modules/
│       ├── vpc/
│       ├── security/
│       ├── rds/
│       ├── monitoring/
│       └── eks/
└── .gitignore
```

---

## ⚙️ Configuration Initiale

### 1. Créer les fichiers secrets

Les credentials RDS sont stockés dans des fichiers `secrets.hcl` (non versionnés dans Git).

**Pour dev :**
```bash
cat > live/dev/secrets.hcl << 'EOF'
inputs = {
  db_username = "admin"
  db_password = "VotreMotDePasseSecure123!"
  ip_publique = "0.0.0.0/0"
  alert_email = "exemple@email.com"
  map_users = [
    {
      userarn  = "arn:aws:iam::123456789101:user/NOM-Prénom"
      username = "username"
      groups   = ["system:masters"]
    }...
  ]
}
EOF
```

**Pour prod :**
```bash
cat > live/prod/secrets.hcl << 'EOF'
inputs = {
  db_username = "admin"
  db_password = "UnAutreMotDePasseTresSecure456!"
  ip_publique = "ip.from.your.place/please"
  alert_email = "exemple@email.com"
  map_users = [
    {
      userarn  = "arn:aws:iam::123456789101:user/NOM-Prénom"
      username = "username"
      groups   = ["system:masters"]
    }...
  ]
}
EOF
```

⚠️ **Important** : Ces fichiers sont dans `.gitignore` et ne doivent **jamais** être commités.


### Modification du manifest Kubernetes

Après avoir modifié le composants Kubernetes, il faut regénérer le manifest global :
```bash
cd app/
TAG=v0.10.4 REPO_PREFIX=us-central1-docker.pkg.dev/google-samples/microservices-demo ./docs/releasing/make-release-artifacts.sh

```

---

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

**3. Configurer EKS**
```bash
aws eks update-kubeconfig --name hetic_friday_g2-prod --region eu-central-1

kubectl apply -f ../../app/release/kubernetes-manifests.yaml

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**4. Seed de la base produits (première installation uniquement)**

À exécuter après que le module `eso` a déployé le secret `rds-credentials` dans le cluster :

```bash
kubectl apply -f app/kubernetes-manifests/seed-products.yaml
kubectl wait --for=condition=complete job/seed-products --timeout=120s
```

Le Job se nettoie automatiquement 5 minutes après succès. Il est idempotent : relancer la commande ne duplique pas les données.

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

3. Supprimer le bucket et la table DynamoDB :

```bash
aws s3 rb s3://hetic-friday-g2-terraform-state --force
aws dynamodb delete-table --table-name hetic-friday-g2-terraform-locks --region eu-central-1
```

---

### 📈 Mise en place des tests de charge

**1. Environnement de Dev (Recommandé)**
1. Installer les dépendences  k6 sur aws

```bash
helm repo add k6-operator https://grafana.github.io/helm-charts
helm repo update
helm install k6-operator k6-operator/k6-operator
```

**2. Appliquer le script de montée de charge sur EKS**
Attention : Le test de montée de charge s'executera directement à la suite de ces commandes
```bash
kubectl create configmap k6-script --from-file=scripts/load_test.js
kubectl apply -f .\app\kubernetes-manifests\load-test.yaml
```

**3. Monitorer la progression du test**
```bash
# Récupérer le nom de l'instance de test (ex: ecommerce-load-test-1-57r25)
kubectl get pods 
kubectl logs -f <INSTANCE-DE-TEST>
```

**4. Mettre à jour le script de montée de charge**
```bash
kubectl delete -f .\app\kubernetes-manifests\load-test.yaml
kubectl delete configmap k6-script
```


---

## 📚 Documentation

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Google Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo)

---

## 👥 Équipe

**Groupe 2** - HETIC MT5  
Naming convention : `hetic_friday_g2`
