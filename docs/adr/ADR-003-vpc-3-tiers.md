# ADR-003 : Architecture réseau VPC en 3 couches

**Date** : Mars 2026  
**Statut** : Accepté  
**Décideurs** : Équipe Groupe 2 MT5

## Contexte

L'infrastructure doit séparer proprement les composants exposés à Internet, les workloads applicatifs, et les bases de données. Le cahier des charges exige une architecture multi-AZ sur 3 zones de disponibilité.

## Décision

Nous utilisons un **VPC unique avec 3 couches de subnets** (Public, Private, Data) réparties sur 3 AZ.

## Architecture

```
VPC: 10.0.0.0/16
├─ Public Layer  (10.0.0.0/20)  → ALB, NAT Gateways, Bastion
├─ Private Layer (10.0.16.0/20) → EKS Nodes (pods applicatifs)
├─ Data Layer    (10.0.32.0/21) → RDS PostgreSQL
└─ Réservé       (10.0.40.0/21) → Futur (Cache, VPN)
```

## Alternatives considérées

| Solution | Avantages | Inconvénients | Verdict |
|---|---|---|---|
| **VPC 3 couches** | Isolation claire, NACLs par couche, simple à comprendre | Plus de subnets à gérer | ✅ Choisi |
| VPC 2 couches (public/private) | Plus simple | La DB est sur le même niveau que les apps — pas d'isolation data | ❌ Rejeté |
| Multi-VPC (1 par service) | Isolation maximale | Complexité du VPC peering, coûts NAT multipliés, overkill pour le projet | ❌ Rejeté |
| Un seul subnet public | Le plus simple | Aucune sécurité réseau, tout est exposé à Internet | ❌ Rejeté |

## Conséquences

- 9 subnets au total (3 tiers × 3 AZ)
- Les données (RDS) ne sont accessibles que depuis les subnets privés
- Le coût NAT Gateway est significatif (~45€/mois par NAT)
  - Prod : 1 NAT par AZ (haute dispo)
  - Dev : 1 seul NAT (économie)
- Le CIDR `/16` laisse de la marge pour ajouter des couches futures (cache, VPN)
