# ADR-005 : Gestion des secrets avec External Secrets Operator

**Date** : Mars 2026  
**Statut** : Accepté  
**Décideurs** : Équipe Groupe 2 MT5

## Contexte

Les microservices Kubernetes ont besoin d'accéder aux credentials RDS (host, user, password). Il faut un moyen sécurisé de synchroniser les secrets AWS Secrets Manager vers les Kubernetes Secrets, sans les stocker en clair dans le code ou les manifests.

## Décision

Nous utilisons **External Secrets Operator (ESO)** pour synchroniser les secrets AWS Secrets Manager vers Kubernetes.

## Flux

```
secrets.hcl (local, .gitignore)
    ↓ Terraform
AWS Secrets Manager (chiffré KMS)
    ↓ ESO (via IRSA)
Kubernetes Secret (namespace hetic-friday)
    ↓ Volume mount
Pod productcatalogservice
```

## Alternatives considérées

| Solution | Avantages | Inconvénients | Verdict |
|---|---|---|---|
| **External Secrets Operator** | Sync auto SM → K8s, rotation possible, IRSA (least privilege) | Composant supplémentaire à déployer | ✅ Choisi |
| Sealed Secrets (Bitnami) | Secrets chiffrés dans Git | Pas de source de vérité externe, pas de rotation auto, clé de chiffrement à gérer | ❌ Rejeté |
| `kubectl create secret` manuel | Le plus simple | Pas reproductible, pas de rotation, pas d'IaC | ❌ Rejeté |
| HashiCorp Vault | Le plus puissant (rotation, leasing, PKI) | Complexe à opérer, nécessite son propre cluster HA, overkill | ❌ Rejeté |
| Variables d'env dans le Deployment | Simple | Secrets en clair dans les manifests YAML, visible dans `kubectl describe` | ❌ Rejeté |

## Conséquences

- ESO est déployé avec IRSA (chaque pod a son propre rôle IAM)
- La policy IAM du pod ESO est limitée à `secretsmanager:GetSecretValue` sur le secret RDS uniquement
- Les secrets Kubernetes sont créés automatiquement par ESO et mis à jour si le secret AWS change
- Le module `eso` gère le déploiement Helm de l'opérateur
- Le module `eso-config` gère le `SecretStore` et les `ExternalSecret` resources
