# Observabilité — Tracing Distribué et Alerting

## Contexte

Le cahier des charges consacre **15% de la note** à l'observabilité. L'audit initial a montré que Prometheus + Grafana étaient en place, mais deux éléments clés manquaient : le **tracing distribué** (Jaeger) et les **alertes applicatives** (PrometheusRule).

Avec 11 microservices, comprendre le parcours d'une requête est essentiel pour identifier les goulots de performance pendant le Black Friday.

## Ce qui a été implémenté

### 1. Jaeger — Tracing distribué

**Fichier modifié** : `terraform/modules/monitoring-k8s/main.tf`

Jaeger est déployé via Helm dans le namespace `monitoring`, en mode **all-in-one** (un seul pod contenant collector, query et stockage).

#### Configuration choisie

| Paramètre | Valeur | Pourquoi |
|---|---|---|
| Mode | `allInOne` | Un seul pod = moins de ressources, suffisant pour le projet |
| Stockage | `memory` | Pas besoin de Cassandra ou Elasticsearch pour un projet pédagogique |
| Max traces | 10 000 | Garde les 10K dernières traces en mémoire (~500 Mo max) |
| Agent séparé | Désactivé | Le all-in-one intègre déjà le collector |

#### Pourquoi Jaeger vs les alternatives ?

| Solution | Verdict | Raison |
|---|---|---|
| **Jaeger** ✅ | Choisi | Open source (CNCF graduated), léger en mode all-in-one, UI intégrée, supporte OpenTelemetry nativement |
| Zipkin | Rejeté | Plus ancien, moins de fonctionnalités (pas de DAG des services), communauté moins active |
| AWS X-Ray | Rejeté | Propriétaire AWS, coût par trace (~5 USD/million), nécessite le X-Ray SDK dans chaque microservice |
| Tempo (Grafana) | Alternatif viable | Excellent choix si on veut tout intégrer dans Grafana, mais nécessite un backend S3/GCS et plus de configuration |

#### Pourquoi le mode all-in-one ?

En production réelle, on séparerait Collector / Query / Storage (Cassandra ou Elasticsearch). Pour notre projet :
- **Budget limité** : Un seul pod au lieu de 5+
- **Données éphémères** : On n'a pas besoin de garder les traces 30 jours — le test de charge dure 8h
- **Simplicité** : Pas de dépendance externe (Cassandra = 3 nodes minimum)

#### Comment accéder à Jaeger ?

```bash
# Port-forward vers l'UI Jaeger
kubectl port-forward svc/jaeger-query -n monitoring 16686:16686

# Ouvrir http://localhost:16686
```

L'UI permet de :
- Visualiser le parcours complet d'une requête à travers les 11 microservices
- Identifier les services les plus lents (waterfall view)
- Comparer les latences entre différentes périodes de charge

### 2. PrometheusRule — Alertes applicatives Black Friday

**Fichier modifié** : `terraform/modules/monitoring-k8s/main.tf`

6 alertes alignées sur les critères du cahier des charges :

#### Alertes critiques (doivent être résolues immédiatement)

| Alerte | Seuil | Lien cahier des charges |
|---|---|---|
| `HighLatencyP95` | P95 > 2 secondes pendant 2 min | "latence < 2s" — critère d'évaluation Performance |
| `HighErrorRate` | Erreurs 5xx > 1% pendant 2 min | "erreurs < 1%" — critère d'évaluation Performance |
| `HPAMaxedOut` | HPA au max replicas pendant 10 min | Indique que le scaling est insuffisant — il faut augmenter les limites |

#### Alertes warning (à surveiller, action préventive)

| Alerte | Seuil | Pourquoi |
|---|---|---|
| `PodCrashLooping` | > 3 restarts en 15 min | Détecte les pods instables avant que ça impacte le service |
| `HighMemoryUsage` | > 90% de la limite mémoire | Anticipe les OOMKill — permet de rightsizer avant le crash |
| `HighCPUUsage` | > 90% de la limite CPU | Vérifie que l'HPA réagit bien — si le CPU est à 90% et l'HPA ne scale pas, il y a un problème |

#### Pourquoi ces seuils précis ?

- **Latence 2s** et **erreurs 1%** : Ce sont les critères exacts du cahier des charges pour les 25 points de Performance
- **`for: 2m`** sur les critiques : Évite les faux positifs (un spike de 30s n'est pas un incident)
- **`for: 10m`** sur HPAMaxedOut : Si l'HPA est bloqué au max pendant 10 min, c'est un vrai problème, pas un pic temporaire

#### Comment les alertes sont-elles routées ?

```
PrometheusRule → Prometheus → AlertManager → (email via SNS / Slack / PagerDuty)
```

AlertManager est déjà activé dans le stack. Les alertes apparaissent dans :
1. **Grafana** → Alerting → Alert Rules
2. **AlertManager UI** : `kubectl port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 9093:9093`

## Stack d'observabilité complète après cette branche

| Pilier | Outil | État |
|---|---|---|
| **Metrics** | Prometheus + Grafana | ✅ (existant) |
| **Logs** | CloudWatch (NAT alarms) | ✅ (existant - basique) |
| **Tracing** | Jaeger | ✅ (nouveau) |
| **Alerting** | PrometheusRule + AlertManager | ✅ (nouveau) |

## Vérification

```bash
# Valider le module Terraform
cd terraform/modules/monitoring-k8s
terraform init -backend=false && terraform validate

# Vérifier le déploiement de Jaeger
kubectl get pods -n monitoring -l app.kubernetes.io/name=jaeger

# Vérifier les alertes Prometheus
kubectl get prometheusrule -n monitoring
```
