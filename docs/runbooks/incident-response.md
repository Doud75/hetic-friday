# Runbook : Réponse aux incidents

## Classification des incidents

| Sévérité | Description | Temps de réponse | Exemples |
|---|---|---|---|
| **P1 - Critique** | Service complètement down | < 5 min | Site inaccessible, ALB 503, DB down |
| **P2 - Majeur** | Dégradation significative | < 15 min | Latence > 5s, erreurs > 5%, pods CrashLoop |
| **P3 - Mineur** | Impact limité | < 1h | Un microservice lent, monitoring down |
| **P4 - Cosmétique** | Pas d'impact utilisateur | Best effort | Dashboard cassé, logs manquants |

## Procédure générale

```
1. DÉTECTER  → Alerte Prometheus/CloudWatch ou constat utilisateur
2. QUALIFIER → Identifier la sévérité (P1-P4)
3. TRIER     → Identifier le composant en cause
4. RÉSOUDRE  → Appliquer le fix
5. VÉRIFIER  → Confirmer le retour à la normale
6. DOCUMENTER → Post-mortem (pour P1/P2)
```

## Diagnostic rapide

### L'application ne répond plus (P1)

```bash
# 1. Vérifier si les pods tournent
kubectl get pods -n hetic-friday

# 2. Vérifier les nodes
kubectl get nodes

# 3. Vérifier l'ALB
aws elbv2 describe-target-health --target-group-arn <ARN>

# 4. Vérifier le DNS/routing
curl -I http://<ALB_DNS>/
```

### Arbre de décision

```
Site inaccessible ?
├─ ALB retourne 503 ?
│  ├─ Target Group unhealthy → Pods down → kubectl rollout restart
│  └─ WAF bloque → Vérifier les règles WAF dans la console
├─ DNS ne résout pas ?
│  └─ Vérifier l'ALB dans la console EC2
└─ Timeout ?
   ├─ NAT Gateway saturé → Vérifier CloudWatch metric NAT
   └─ Nodes at capacity → kubectl get pods --field-selector=status.phase=Pending
```

## Playbooks spécifiques

### Pods en CrashLoopBackOff

```bash
# Identifier les pods en erreur
kubectl get pods -n hetic-friday | grep -v Running

# Voir la raison du crash
kubectl describe pod <pod> -n hetic-friday

# Voir les logs du dernier crash
kubectl logs <pod> -n hetic-friday --previous

# Fix commun : OOMKilled → augmenter la mémoire
kubectl patch deployment <deploy> -n hetic-friday -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","resources":{"limits":{"memory":"512Mi"}}}]}}}}'
```

### RDS saturée (connexions/CPU)

```bash
# Vérifier avec Performance Insights dans la console AWS
# AWS Console → RDS → Performance Insights

# Vérifier les connexions actives
kubectl exec -it <productcatalog-pod> -n hetic-friday -- \
  psql -h <RDS_HOST> -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Si trop de connexions → restart les pods pour libérer
kubectl rollout restart deployment/productcatalogservice -n hetic-friday
```

### WAF bloque le trafic légitime

```bash
# Vérifier les logs WAF
aws wafv2 get-logging-configuration --resource-arn <WEB_ACL_ARN>

# Vérifier les métriques WAF
# AWS Console → WAF → Web ACLs → Sampled Requests

# Si le rate-limit bloque k6 :
# Ajouter l'IP du runner k6 dans la whitelist du module ALB
```

### HPA ne scale pas

```bash
# Vérifier le status HPA
kubectl describe hpa <service>-hpa -n hetic-friday

# Causes communes :
# 1. Metrics server down → kubectl get pods -n kube-system | grep metrics
# 2. Target CPU trop élevé → baisser le target (ex: 70% → 50%)
# 3. Resource limits non définis → l'HPA ne peut pas calculer le %

# Fix : forcer le scaling manuel temporaire
kubectl scale deployment <service> -n hetic-friday --replicas=5
```

## Contacts et escalade

| Rôle | Responsabilité |
|---|---|
| **On-call engineer** | Premier répondant, diagnostic et fix rapide |
| **Team lead** | Escalade si P1 non résolu en 15 min |
| **Formateur** | Escalade si problème de budget ou accès AWS |
