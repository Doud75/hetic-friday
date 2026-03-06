# Post-Mortem — Déploiement EKS + Frontend hetic-friday

## Accès aux services

| Service | URL | Credentials |
|---|---|---|
| **Frontend** | http://hetic-friday-alb-1929581766.eu-central-1.elb.amazonaws.com | — |
| **Grafana** | http://hetic-friday-alb-1929581766.eu-central-1.elb.amazonaws.com:3000 | admin / admin123! |
| **Prometheus** | `kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090` puis http://localhost:9090 | — |

> ⚠️ Le frontend est en HTTP (port 80). Certains réseaux d'entreprise/école bloquent le port 80 sortant — tester depuis un réseau 4G si le site est inaccessible.

---

## Contexte

Déploiement d'un cluster EKS en **Auto Mode** sur AWS (eu-central-1) avec Terraform/Terragrunt.  
Application : Online Boutique (Google microservices demo), namespace `hetic-friday`.  
Problème central : l'ALB ne pouvait pas être créé automatiquement par EKS (restriction au niveau du compte AWS).  
Solution : création manuelle de l'ALB depuis la console et le CLI AWS.

---

## Problèmes rencontrés et solutions

### 1. Erreur `sts:TagSession` au démarrage du cluster

**Symptôme :** La création du cluster échouait avec une erreur de permission IAM.  
**Cause :** La policy trust du rôle IAM du cluster n'incluait pas `sts:TagSession`, requis par EKS Auto Mode.  
**Fix :** Ajout de `sts:TagSession` dans le `assume_role_policy` du rôle IAM → **déjà en place dans le code Terraform** (`eks/main.tf` ligne 8).

---

### 2. Nœuds non découverts par Auto Mode (pods en `Pending`)

**Symptôme :** Après création du cluster, tous les pods restaient en `Pending`.  
**Cause :** Les subnets privés n'avaient pas le tag requis par EKS Auto Mode pour la découverte automatique.  
**Fix manuel appliqué :**
```bash
aws ec2 create-tags \
  --resources <subnet-id-1> <subnet-id-2> ... \
  --tags Key=kubernetes.io/cluster/hetic_friday_g2-prod,Value=owned
```
> ⚠️ **Ce tag doit être ajouté dans le module Terraform `vpc`** (voir section Améliorations).

---

### 3. `AddressLimitExceeded` — IPv4 élastiques orphelines

**Symptôme :** Création du cluster impossible à cause d'une limite EIP dépassée.  
**Cause :** Des Elastic IPs orphelines d'anciennes sessions Terraform traînaient dans le compte.  
**Fix manuel :**
```bash
# Lister les EIPs non associées
aws ec2 describe-addresses --region eu-central-1 --query 'Addresses[?AssociationId==null]'
# Libérer chaque EIP orpheline
aws ec2 release-address --allocation-id <alloc-id> --region eu-central-1
```

---

### 4. Prometheus en `Pending` (PVC non provisionné)

**Symptôme :** Le pod Prometheus ne démarrait pas, le PVC restait `Pending`.  
**Cause :** La StorageClass par défaut (`gp2`) n'était pas compatible avec EKS Auto Mode. Il faut utiliser `ebs-auto` avec le driver `ebs.csi.eks.amazonaws.com`.  
**Fix appliqué dans le code** (`monitoring-k8s/main.tf`) :
```hcl
set {
  name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
  value = "ebs-auto"
}
```

---

### 5. Timeout Helm trop court

**Symptôme :** Helm échouait avec un timeout lors du déploiement du monitoring stack.  
**Cause :** EKS Auto Mode provisionne les nœuds à la volée, ce qui prend plus de temps que les 600s par défaut.  
**Fix appliqué dans le code** (`monitoring-k8s/main.tf`) :
```hcl
timeout = 900
```

---

### 6. ALB non créable automatiquement (`OperationNotPermitted`)

**Symptôme :** Le service Kubernetes de type `LoadBalancer` restait en `Pending` indéfiniment.  
**Cause :** Le compte AWS avait une restriction qui empêchait EKS Auto Mode de créer des Load Balancers automatiquement.  
**Solution :** Création manuelle de toute la stack ALB (voir section suivante).

---

## Création manuelle de l'ALB — étapes réalisées

### Architecture finale

```
Internet
   │ port 80              │ port 3000
   ▼                      ▼
hetic-friday-alb (internet-facing, public subnets)
sg-04cfb60f38c26238c (hetic-friday-alb-sg)
   - Entrée  : TCP 80, 3000 depuis 0.0.0.0/0
   - Sortie  : Tout le trafic vers 0.0.0.0/0
   │                      │
   │ port 8080             │ port 3000
   ▼                      ▼
Pod frontend           Pod Grafana
(10.0.21.71:8080)      (10.0.21.67:3000)
namespace hetic-friday  namespace monitoring
```

### Ressources créées manuellement

#### Groupe de sécurité ALB

| Attribut | Valeur |
|---|---|
| Nom | `hetic-friday-alb-sg` |
| ID | `sg-04cfb60f38c26238c` |
| VPC | `vpc-07305b2349bbee9fd` |
| Règles entrantes | TCP 80 et TCP 3000, source `0.0.0.0/0` |
| Règle sortante | Tout le trafic, `0.0.0.0/0` |

#### Application Load Balancer

| Attribut | Valeur |
|---|---|
| Nom | `hetic-friday-alb` |
| ARN | `arn:aws:elasticloadbalancing:eu-central-1:622333992348:loadbalancer/app/hetic-friday-alb/0de32d420df90ec2` |
| Scheme | `internet-facing` |
| Subnets | `subnet-0ccad9021648e3195` (1a), `subnet-08225ea0743c8af42` (1b), `subnet-0883c088073f297a2` (1c) |
| SG | `sg-04cfb60f38c26238c` |

#### Target Group Frontend (IP)

| Attribut | Valeur |
|---|---|
| Nom | `hetic-friday-frontend-ip-tg` |
| ARN | `arn:aws:elasticloadbalancing:eu-central-1:622333992348:targetgroup/hetic-friday-frontend-ip-tg/505a6bcafafb975d` |
| Type | `ip` |
| Port | `8080` |
| Health check | `GET /` |
| Cible | `10.0.21.71:8080` (pod frontend) |

#### Target Group Grafana (IP)

| Attribut | Valeur |
|---|---|
| Nom | `hetic-friday-grafana-tg` |
| ARN | `arn:aws:elasticloadbalancing:eu-central-1:622333992348:targetgroup/hetic-friday-grafana-tg/08115c6d140291b5` |
| Type | `ip` |
| Port | `3000` |
| Health check | `GET /api/health` |
| Cible | `10.0.21.67:3000` (pod Grafana) |

#### Règles SG ajoutées sur le cluster (`sg-080a1507ba355aee6`)

```bash
# Port 8080 pour le frontend
aws ec2 authorize-security-group-ingress \
  --group-id sg-080a1507ba355aee6 --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region eu-central-1

# Port 3000 pour Grafana
aws ec2 authorize-security-group-ingress \
  --group-id sg-080a1507ba355aee6 --protocol tcp --port 3000 --cidr 0.0.0.0/0 --region eu-central-1
```

#### Écouteurs ALB

| Port | Action |
|---|---|
| 80 | forward → `hetic-friday-frontend-ip-tg` |
| 3000 | forward → `hetic-friday-grafana-tg` |

---

## Améliorations à apporter dans le code Terraform

### 1. Tags subnet pour EKS Auto Mode — `terraform/modules/vpc/main.tf`

Ajouter le tag sur les subnets pour que EKS Auto Mode les découvre automatiquement :

```hcl
# Dans la ressource aws_subnet (private)
tags = merge(var.tags, {
  Name                                        = "..."
  "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  "kubernetes.io/role/internal-elb"           = "1"
})

# Dans la ressource aws_subnet (public)
tags = merge(var.tags, {
  Name                                    = "..."
  "kubernetes.io/role/elb"                = "1"
})
```

### 2. Automatiser l'ALB — nouveau module `terraform/modules/alb-frontend`

Créer un module Terraform dédié pour provisionner l'ALB, le Target Group et le SG :

```hcl
# modules/alb-frontend/main.tf

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB frontend public"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "frontend" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-frontend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_security_group_rule" "cluster_allow_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = var.cluster_security_group_id
  source_security_group_id = aws_security_group.alb.id
}
```

### 3. Grafana en `ClusterIP` au lieu de `LoadBalancer` en prod

Dans `monitoring-k8s/main.tf`, changer :

```hcl
set {
  name  = "grafana.service.type"
  value = "ClusterIP"  # L'ALB gère l'exposition publique
}
```

### 4. ⚠️ Attention au redémarrage des pods

Les Target Groups pointent sur les **IPs des pods** (`10.0.21.71`, `10.0.21.67`). Si les pods redémarrent, leurs IPs changent et les Target Groups deviennent `Unhealthy`. Il faudra alors re-enregistrer les nouvelles IPs manuellement — ou migrer vers le module Terraform avec `target_type = "instance"` et un NodePort stable.
