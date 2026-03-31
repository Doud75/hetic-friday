# Documentation — ADRs et Runbooks Opérationnels

## Contexte

Le cahier des charges exige une **documentation technique complète** pour la soutenance. Les documents doivent démontrer la capacité de l'équipe à justifier ses choix et à opérer l'infrastructure en situation de crise.

## Ce qui a été implémenté

### 1. Architecture Decision Records (ADRs)

Les ADRs documentent les **décisions techniques majeures** avec leur contexte, les alternatives considérées, et les conséquences.

**Pourquoi les ADRs ?**

| Approche doc | Verdict | Raison |
|---|---|---|
| **ADRs (Markdown)** ✅ | Choisi | Format standardisé (Michael Nygard), versionné avec le code, facile à relire |
| Confluence/Notion | Rejeté | Externe au repo, risque de désynchronisation avec le code |
| README géant | Rejeté | Non structuré, mélange les décisions avec le mode d'emploi |
| Pas de doc | ❌ | Perte de points en soutenance, impossible de justifier les choix |

#### ADRs créés

| ADR | Sujet | Choix principal |
|---|---|---|
| ADR-001 | Multi-environnement | Terragrunt (vs Workspaces, Pulumi) |
| ADR-002 | Orchestration K8s | EKS Auto Mode (vs Managed Node Groups, Karpenter) |
| ADR-003 | Architecture réseau | VPC 3 couches (vs 2 couches, multi-VPC) |
| ADR-004 | Monitoring | kube-prometheus-stack (vs Datadog, CloudWatch) |
| ADR-005 | Gestion des secrets | External Secrets Operator (vs Vault, Sealed Secrets) |
| ADR-006 | Exposition services | ALB Terraform + WAF (vs Nginx Ingress, CloudFront) |

### 2. Runbooks Opérationnels

Les runbooks sont des **procédures étape par étape** pour les opérations récurrentes et les situations d'urgence.

#### Runbooks créés

| Runbook | Usage | Contenu clé |
|---|---|---|
| `deployment.md` | Déploiement de l'infra | Ordre des dépendances entre modules, commandes Terragrunt |
| `black-friday-war-room.md` | Jour J du test de charge | Checklist T-24h, dashboards à ouvrir, procédure de pre-warm ALB |
| `incident-response.md` | Réponse aux incidents | Classification P1-P4, arbres de décision, playbooks spécifiques |

## Structure des fichiers

```
docs/
├── adr/
│   ├── ADR-001-terragrunt.md
│   ├── ADR-002-eks-auto-mode.md
│   ├── ADR-003-vpc-3-tiers.md
│   ├── ADR-004-monitoring-stack.md
│   ├── ADR-005-external-secrets.md
│   └── ADR-006-alb-waf.md
└── runbooks/
    ├── deployment.md
    ├── black-friday-war-room.md
    └── incident-response.md
```

## Pourquoi séparer ADRs et Runbooks ?

- Les **ADRs** répondent à "**Pourquoi** avons-nous fait ce choix ?" → Utiles pour la soutenance, les nouveaux membres, le post-mortem
- Les **Runbooks** répondent à "**Comment** faire cette opération ?" → Utiles en situation de stress (Black Friday), quand on n'a pas le temps de réfléchir

## Impact pour la soutenance

Ces documents couvrent plusieurs critères de notation :
- **IaC (25 pts)** : ADRs justifient les choix Terraform/Terragrunt
- **Sécurité (20 pts)** : ADR-005/006 justifient les choix de sécurité
- **Observabilité (15 pts)** : ADR-004 + runbook War Room
- **Documentation (bonus)** : Structure formelle ADR + runbooks opérationnels
