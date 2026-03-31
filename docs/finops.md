# FinOps — Suivi des coûts AWS

## Contexte

Le cahier des charges impose un budget total de **1 500 € – 2 000 €** réparti sur 3 semaines + 2 jours de démo. Sans mécanisme de suivi automatisé, le risque de dépassement est réel — surtout en Semaine 3 (pre-Black Friday) et lors de la démo où les ressources EKS scalent massivement.

## Ce qui a été implémenté

### 1. Module Terraform `finops`

Un module dédié dans `terraform/modules/finops/` qui crée des **AWS Budgets** pour suivre la consommation en temps réel.

#### Budgets créés

| Budget | Prod | Dev | Pourquoi |
|---|---|---|---|
| **Total mensuel** | 600 USD | 250 USD | Limite globale alignée sur le budget semaine 2–3 du cahier des charges |
| **EKS** | 250 USD | 100 USD | Service le plus coûteux (nodes EC2, networking) |
| **EC2** | 250 USD | 100 USD | Compute brut des worker nodes |
| **RDS** | 50 USD | 30 USD | Base PostgreSQL Multi-AZ |

#### Alertes configurées

Le budget mensuel total déclenche **4 alertes par email** :

| Seuil | Type | Pourquoi |
|---|---|---|
| **50%** | Consommation réelle | Checkpoint mi-parcours — permet d'anticiper |
| **80%** | Consommation réelle | Signal d'alarme — il faut optimiser ou réduire |
| **100%** | Consommation réelle | Budget dépassé — action immédiate requise |
| **100%** | Prévision (forecast) | AWS prédit un dépassement avant qu'il n'arrive |

Les budgets par service (EKS, EC2, RDS) alertent uniquement à **80%** pour éviter le spam.

### 2. Terragrunt configs

- `live/prod/finops/terragrunt.hcl` — Budgets de production
- `live/dev/finops/terragrunt.hcl` — Budgets de développement (plus bas)

Les emails d'alerte sont récupérés depuis `secrets.hcl` (variable `alert_email`).

## Choix techniques et alternatives

### Pourquoi AWS Budgets vs autres solutions ?

| Solution | Verdict | Raison |
|---|---|---|
| **AWS Budgets** ✅ | Choisi | Natif AWS, gratuit (les 2 premiers budgets), intégré à l'écosystème IAM, alertes email natives |
| AWS Cost Explorer API | Rejeté | Plus complexe, nécessite un dashboard custom, coût d'API calls |
| Infracost (open source) | Rejeté | Estime les coûts avant le `terraform apply` — utile en CI/CD mais ne suit pas la consommation réelle |
| Kubecost | Rejeté | Excellent pour le cost par namespace K8s, mais ajoute un composant à maintenir et ne couvre pas les services AWS hors EKS |

### Pourquoi des budgets par service ?

Le budget total seul ne suffit pas. Si EKS consomme 90% du budget à cause d'un autoscaling incontrôlé, on veut le savoir **avant** que le budget global soit épuisé. Les budgets par service permettent d'identifier **quel composant** dérive.

### Pourquoi les seuils 50/80/100 ?

- **50%** : Inspiré des bonnes pratiques AWS Well-Architected (FinOps pillar). Donne une visibilité à mi-parcours.
- **80%** : Seuil d'alerte standard dans l'industrie. Laisse une marge de manœuvre (~20%) pour réagir.
- **100%** : Alerte de dépassement — déclenche les mesures d'urgence (arrêt des ressources non critiques).
- **Forecast 100%** : C'est la plus utile — AWS prédit le dépassement **avant** qu'il n'arrive, basé sur la tendance de consommation.

## Ce qui reste à faire (hors scope de cette branche)

- **Spot Instances** : Réduction de 60-70% sur les worker nodes EKS. Nécessite une configuration EKS Node Groups avec `capacity_type = "SPOT"`.
- **Tags de cost allocation** : Ajouter `Project`, `Team`, `CostCenter` sur toutes les ressources pour le reporting AWS Cost Explorer.
- **Extinction automatique hors horaires** : Lambda + EventBridge pour éteindre le cluster dev la nuit et le week-end.
- **Rightsizing** : Analyser les métriques CloudWatch pour ajuster les tailles d'instances après les premiers tests de charge.

## Déploiement

```bash
# Appliquer les budgets en prod
cd live/prod/finops
terragrunt apply

# Appliquer les budgets en dev
cd live/dev/finops
terragrunt apply
```

Après le déploiement, vérifier dans la console AWS :
**AWS Console → Billing → Budgets** — les 4 budgets doivent apparaître.
