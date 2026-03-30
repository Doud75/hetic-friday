# ADR-002 : Choix d'EKS Auto Mode pour l'orchestration Kubernetes

**Date** : Mars 2026  
**Statut** : Accepté  
**Décideurs** : Équipe Groupe 2 MT5

## Contexte

Le projet déploie 11 microservices (Google Online Boutique) qui doivent scaler jusqu'à 90K utilisateurs simultanés. Il faut un orchestrateur capable de gérer l'auto-scaling des pods ET des nodes.

## Décision

Nous utilisons **Amazon EKS en Auto Mode** avec un node pool `general-purpose`.

## Alternatives considérées

| Solution | Avantages | Inconvénients | Verdict |
|---|---|---|---|
| **EKS Auto Mode** | Provisioning automatique des nodes, pas de node groups à gérer, Cluster Autoscaler intégré | Nouveau (GA début 2025), moins de contrôle sur les instances | ✅ Choisi |
| EKS avec Managed Node Groups | Contrôle total sur les types d'instances | Configuration manuelle du Cluster Autoscaler, plus de code Terraform | ❌ Rejeté |
| EKS avec Karpenter | Scaling très rapide, optimisation des coûts | Plus complexe à configurer, nécessite des NodePools custom | ❌ Rejeté |
| Amazon ECS (Fargate) | Serverless, pas de nodes à gérer | Pas de compatibilité Kubernetes, écosystème limité (pas de Helm, Prometheus natif) | ❌ Rejeté |
| Docker Compose sur EC2 | Simple pour le développement | Pas d'auto-scaling, pas de self-healing, ne tiendra pas 90K users | ❌ Rejeté |

## Conséquences

- Les nodes sont provisionnés automatiquement par AWS selon la charge
- Pas besoin de configurer Cluster Autoscaler manuellement
- Le tag `eks:eks-cluster-name` sur les Target Groups est nécessaire pour le LB
- Les StorageClasses doivent utiliser `ebs-auto` au lieu de `gp2`
- Certaines fonctionnalités (LB auto-provisioning) peuvent être restreintes selon le compte AWS
