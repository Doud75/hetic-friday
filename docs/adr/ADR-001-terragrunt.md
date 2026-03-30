# ADR-001 : Choix de Terragrunt pour la gestion multi-environnement

**Date** : Mars 2026  
**Statut** : Accepté  
**Décideurs** : Équipe Groupe 2 MT5

## Contexte

Le projet nécessite deux environnements distincts (dev et prod) avec des configurations différentes (taille des instances, nombre de NAT Gateways, budgets). Il faut un moyen de partager le code Terraform entre les environnements sans duplication.

## Décision

Nous utilisons **Terragrunt** comme wrapper autour de Terraform pour gérer le DRY (Don't Repeat Yourself) entre les environnements.

## Alternatives considérées

| Solution | Avantages | Inconvénients | Verdict |
|---|---|---|---|
| **Terragrunt** | DRY natif, dépendances entre modules, backend automatique | Couche supplémentaire, courbe d'apprentissage | ✅ Choisi |
| Terraform Workspaces | Natif Terraform, pas de dépendance externe | State partagé (risqué), pas de DRY sur les variables | ❌ Rejeté |
| Terraform + tfvars par env | Simple, pas de dépendance | Duplication du code backend, pas de gestion des dépendances inter-modules | ❌ Rejeté |
| Pulumi | Language de programmation complet (TypeScript/Python) | Équipe non formée, écosystème moins mature pour AWS | ❌ Rejeté |

## Conséquences

- Structure `live/{env}/{module}/terragrunt.hcl` pour chaque environnement
- `root.hcl` centralise la config backend (S3 + DynamoDB)
- `secrets.hcl` par environnement pour les credentials (hors Git)
- Les modules Terraform dans `terraform/modules/` sont réutilisés tel quel
