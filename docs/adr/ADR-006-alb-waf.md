# ADR-006 : ALB Terraform avec WAF pour l'exposition des services

**Date** : Mars 2026  
**Statut** : Accepté  
**Décideurs** : Équipe Groupe 2 MT5

## Contexte

EKS Auto Mode ne pouvait pas provisionner automatiquement des Load Balancers sur notre compte AWS (restriction `OperationNotPermitted`). Le frontend et Grafana doivent être accessibles via Internet. Il fallait trouver une solution pour exposer les services de manière sécurisée.

## Décision

Nous provisionons l'**ALB via Terraform** (module `alb`) avec du path-based routing et un **WAF v2** intégré.

## Architecture

```
Internet
    │
    ▼
WAF v2 (rate-limit + CRS + SQLi + Bad Inputs)
    │
    ▼
ALB (port 80)
    ├─ /         → Target Group Frontend (nginx-cache-proxy:80)
    └─ /grafana* → Target Group Grafana (grafana:3000)
```

## Alternatives considérées

| Solution | Avantages | Inconvénients | Verdict |
|---|---|---|---|
| **ALB Terraform + WAF** | Contrôle total, IaC, WAF intégré, path routing | Plus de code à maintenir | ✅ Choisi |
| EKS Auto Mode LB (Ingress) | Automatique, moins de code | Bloqué sur notre compte (OperationNotPermitted) | ❌ Impossible |
| Nginx Ingress Controller | Standard K8s, flexible | Nécessite un NLB quand même, pas de WAF natif | ❌ Rejeté |
| Service type LoadBalancer | Simple | Crée un CLB (Classic), pas de path routing, pas de WAF | ❌ Rejeté |
| CloudFront + ALB | CDN global, WAF intégré | Complexité, latence pour les requêtes dynamiques, coût CDN | ❌ Rejeté |

## Conséquences

- Le module `alb` crée l'ALB, les Target Groups, les listeners, le WAF, et les TargetGroupBindings K8s
- Le WAF protège contre : XSS (CRS), SQLi, Bad Inputs (Log4j), et rate-limiting (2000 req/5min)
- Les IPs de load testing (k6) sont whitelistées dans le WAF pour bypasser le rate-limit
- Les TargetGroupBindings lient les services K8s aux Target Groups AWS
- Pas de HTTPS pour le moment (nécessiterait un domaine + ACM certificate)
