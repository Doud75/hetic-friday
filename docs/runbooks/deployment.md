# Runbook : Déploiement de l'infrastructure

## Prérequis

- AWS CLI v2 configuré (`aws sts get-caller-identity`)
- Terraform >= 1.9
- Terragrunt >= 0.68
- kubectl configuré pour le cluster
- Accès au bucket S3 de backend Terraform

## Ordre de déploiement

Les modules ont des dépendances. **Respecter cet ordre** :

```
1. VPC          → Pas de dépendance
2. Security     → Dépend de VPC (vpc_id)
3. EKS          → Dépend de VPC (subnets) + Security (SG)
4. RDS          → Dépend de VPC (data subnets) + Security (SG-DB)
5. Monitoring   → Dépend de VPC (subnets)
6. ALB          → Dépend de VPC + EKS + Security
7. ESO          → Dépend de EKS
8. ESO Config   → Dépend de ESO + RDS (secret ARN)
9. Monitoring-K8s → Dépend de EKS
10. FinOps      → Pas de dépendance (standalone)
```

## Déploiement complet (depuis zéro)

```bash
# 1. Initialiser tous les modules
cd live/prod
terragrunt run-all init

# 2. Appliquer dans l'ordre des dépendances
terragrunt run-all apply --terragrunt-non-interactive

# OU module par module :
cd live/prod/vpc && terragrunt apply
cd live/prod/security && terragrunt apply
cd live/prod/eks && terragrunt apply
# ... etc.
```

## Déploiement d'un seul module

```bash
cd live/prod/<module>
terragrunt plan    # Vérifier les changements
terragrunt apply   # Appliquer
```

## Destruction (attention !)

```bash
# Détruire un module spécifique
cd live/prod/<module>
terragrunt destroy

# Détruire TOUT (ordre inverse des dépendances)
cd live/prod
terragrunt run-all destroy --terragrunt-non-interactive
```

> ⚠️ **ATTENTION** : `run-all destroy` détruit TOUTE l'infrastructure. Vérifier 3 fois avant d'exécuter en prod.

## Rollback

Terraform gère le state. Si un `apply` échoue à mi-chemin :

```bash
# Voir le state actuel
terragrunt state list

# Recréer les ressources manquantes
terragrunt apply

# Si le state est corrompu, importer manuellement :
terragrunt import <resource_type>.<name> <aws_resource_id>
```

## Déploiement des applications K8s

```bash
# Appliquer les manifests Kubernetes
kubectl apply -f app/kubernetes-manifests/ -n hetic-friday

# Vérifier le déploiement
kubectl get pods -n hetic-friday
kubectl get hpa -n hetic-friday
```
