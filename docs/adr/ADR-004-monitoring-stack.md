# ADR-004 : Stratégie de monitoring avec kube-prometheus-stack

**Date** : Mars 2026  
**Statut** : Accepté  
**Décideurs** : Équipe Groupe 2 MT5

## Contexte

Le Black Friday nécessite une observabilité temps réel : métriques de performance, alertes automatiques, et dashboards pour la War Room. Le cahier des charges exige Prometheus + Grafana + un système d'alertes.

## Décision

Nous utilisons le **kube-prometheus-stack** (chart Helm de la communauté Prometheus) qui déploie en un seul chart : Prometheus, Grafana, AlertManager, node-exporter, et kube-state-metrics.

## Alternatives considérées

| Solution | Avantages | Inconvénients | Verdict |
|---|---|---|---|
| **kube-prometheus-stack** | Tout-en-un, dashboards K8s pré-installés, AlertManager intégré, standard CNCF | Chart lourd (~20 CRDs), configuration par `set` Helm verbeuse | ✅ Choisi |
| Prometheus + Grafana séparés | Plus de contrôle par composant | Plus de Helm releases à gérer, pas de dashboards pré-configurés | ❌ Rejeté |
| CloudWatch Container Insights | Natif AWS, pas de composant à gérer | Coûts par métrique, pas de PromQL, dashboards limités | ❌ Rejeté |
| Datadog | UI excellent, APM intégré | Coût élevé (~15 USD/host/mois), propriétaire | ❌ Rejeté |
| Grafana Cloud (free tier) | Hébergé, métriques + logs + traces | Limité à 10K métriques/mois, dépendance externe | ❌ Rejeté |

## Conséquences

- Prometheus stocke les métriques sur EBS (`ebs-auto`, rétention 15j en prod)
- Grafana est exposé via l'ALB sur `/grafana` (ClusterIP + path-based routing)
- AlertManager est activé pour router les alertes
- `serviceMonitorSelectorNilUsesHelmValues = false` permet de scraper toutes les apps du cluster
- Les node-exporters ont des tolerations pour tourner sur les nodes system (taint `CriticalAddonsOnly`)
