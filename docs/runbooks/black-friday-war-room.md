# Runbook : Black Friday — War Room

## Objectif

Tenir **90 000 utilisateurs simultanés** pendant 8h avec :
- Latence P95 < 2 secondes
- Taux d'erreur < 1%
- Zéro downtime

## T-24h : Préparation

### Vérifications infrastructure

```bash
# Vérifier que tous les pods tournent
kubectl get pods -n hetic-friday -o wide
kubectl get pods -n monitoring -o wide

# Vérifier les HPA
kubectl get hpa -n hetic-friday

# Vérifier l'ALB
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN> \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,Health:TargetHealth.State}'

# Vérifier les budgets
aws budgets describe-budgets --account-id $(aws sts get-caller-identity --query Account --output text)
```

### Dashboards à ouvrir

1. **Grafana** : `http://<ALB_DNS>/grafana`
   - Dashboard "Kubernetes / Compute Resources / Namespace (Pods)"
   - Dashboard "Node Exporter / Nodes"
2. **Jaeger** : `kubectl port-forward svc/jaeger-query -n monitoring 16686:16686`
3. **AWS Console** : EC2 → Target Groups (vérifier health checks)
4. **CloudWatch** : Alarms (NAT Gateway, budget)

### Pre-warm l'ALB

L'ALB a besoin de monter en capacité. Faire un ramp-up graduel :

```bash
# k6 pre-warm : 100 → 1000 → 5000 VUs sur 15 min
k6 run --vus 100 --duration 5m scripts/load_test.js
k6 run --vus 1000 --duration 5m scripts/load_test.js
k6 run --vus 5000 --duration 5m scripts/load_test.js
```

## T-0 : Lancement du test de charge

```bash
# Lancer le test principal
k6 run scripts/load_test.js
```

## Monitoring pendant le test

### Métriques à surveiller en continu

| Métrique | Seuil OK | Seuil critique | Action |
|---|---|---|---|
| Latence P95 | < 1s | > 2s | Vérifier les traces Jaeger |
| Error rate | < 0.5% | > 1% | Identifier le service en erreur dans Grafana |
| CPU pods | < 70% | > 90% | L'HPA devrait scaler automatiquement |
| Mémoire pods | < 70% | > 90% | Risque d'OOMKill, vérifier les limits |
| HPA replicas | < max | = max | Augmenter `maxReplicas` si nécessaire |
| Node count | Variable | 0 pending pods | Si pods Pending → les nodes ne scalent pas assez vite |

### Commandes de diagnostic rapide

```bash
# Vue d'ensemble
kubectl top pods -n hetic-friday --sort-by=cpu
kubectl top nodes

# Pods en erreur
kubectl get pods -n hetic-friday --field-selector=status.phase!=Running

# Événements récents
kubectl get events -n hetic-friday --sort-by='.lastTimestamp' | tail -20

# Logs d'un pod en erreur
kubectl logs -n hetic-friday <pod-name> --tail=50

# HPA status détaillé
kubectl describe hpa -n hetic-friday
```

## Réponse aux incidents

### Incident : Latence P95 > 2s

```
1. Ouvrir Jaeger → Trouver les traces lentes
2. Identifier le service le plus lent (waterfall)
3. Vérifier si l'HPA a scalé ce service
4. Si HPA au max → augmenter maxReplicas :
   kubectl patch hpa <service>-hpa -n hetic-friday -p '{"spec":{"maxReplicas":20}}'
5. Si CPU/mémoire OK mais lent → problème applicatif (DB ?)
```

### Incident : Error rate > 1%

```
1. Identifier le service en 5xx : kubectl logs -n hetic-friday -l app=<service> --tail=100
2. Si OOMKill → augmenter les limits mémoire
3. Si CrashLoop → kubectl describe pod <pod> → Events
4. Si healthcheck fail → vérifier le targetGroup dans AWS Console
```

### Incident : Pods Pending (pas assez de nodes)

```
1. kubectl describe pod <pending-pod> → Events → raison
2. Si "Insufficient cpu/memory" :
   - EKS Auto Mode devrait provisionner un node (~2 min)
   - Vérifier : kubectl get nodes -w
3. Si pas de nouveau node après 5 min :
   - Vérifier les quotas EC2 : aws service-quotas list-service-quotas --service-code ec2
```

### Incident : Budget dépassé

```
1. Vérifier la console AWS → Billing → Budgets
2. Identifier le service le plus coûteux
3. Réduire le maxReplicas des services non-critiques
4. Si critique : arrêter l'environnement dev
```

## Post-mortem

Après le test, produire un rapport contenant :

1. **Métriques clés** : Latence P95, error rate, max VUs atteints
2. **Incidents** : Timeline, cause racine, résolution
3. **Coûts** : AWS Cost Explorer → filtre par tag `Project=hetic_friday_g2`
4. **Captures d'écran** : Grafana dashboards pendant le pic
5. **Améliorations** : Lessons learned, ce qu'on ferait différemment
