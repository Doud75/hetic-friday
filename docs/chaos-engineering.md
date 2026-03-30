# Chaos Engineering — Ingénierie du chaos avec Chaos Mesh

## Contexte

Le cahier des charges exige des **tests de résilience** démontrant que l'infrastructure peut survivre à des pannes. L'ingénierie du chaos consiste à injecter intentionnellement des défaillances pour vérifier que le système se rétablit automatiquement.

## Ce qui a été implémenté

### Module Terraform `chaos-mesh`

Un module dédié dans `terraform/modules/chaos-mesh/` qui déploie **Chaos Mesh** (CNCF Incubating) via Helm, avec 3 expériences pré-configurées.

### Pourquoi Chaos Mesh vs les alternatives ?

| Outil | Verdict | Raison |
|---|---|---|
| **Chaos Mesh** ✅ | Choisi | CNCF Incubating, Kubernetes-native (CRDs), dashboard intégré, expériences déclaratives YAML |
| LitmusChaos | Rejeté | Plus lourd (nécessite MongoDB), UI moins intuitive, plus d'opinionated sur les workflows |
| Gremlin | Rejeté | Commercial, coûteux, nécessite un agent par node |
| `kubectl delete pod` | Insuffisant | Pas de scheduler, pas de métriques, pas reproductible, pas de réseau ou CPU chaos |
| AWS Fault Injection Service | Alternatif viable | Couvre les pannes AWS-level (AZ, EC2), mais ne couvre pas le niveau pod/container |

### Configuration choisie

| Paramètre | Valeur | Pourquoi |
|---|---|---|
| Version | 2.7.1 | Dernière stable, compatible K8s 1.28+ |
| `securityMode` | false | Pas d'authentification dans le dashboard — suffisant pour un projet pédagogique |
| `targetNamespace` | hetic-friday | Limite le chaos au namespace applicatif — empêche de casser monitoring ou kube-system |
| Dashboard | Activé | Interface graphique pour lancer et visualiser les expériences |

### Pourquoi limiter le chaos à un namespace ?

C'est une bonne pratique et un guard-rail essentiel :
- **Si on casse Prometheus**, on ne peut plus observer les effets du chaos → inutile
- **Si on casse kube-system**, le cluster entier est instable → dangereux
- **Cible = hetic-friday** : les 11 microservices de la boutique, là où le chaos est pertinent

## Expériences pré-configurées

### 1. `pod-kill-random` — Tuer un pod aléatoire

**Type** : PodChaos  
**Durée** : 30 secondes  
**Mode** : Un seul pod aléatoire

**Ce qu'on teste** :
- Le Deployment recrée-t-il le pod automatiquement ?
- Le service reste-t-il disponible grâce aux replicas ?
- Le HPA réagit-il au changement de charge ?

**Résultat attendu** :
- Le pod est recréé en < 30s (self-healing Kubernetes)
- Zéro downtime si au moins 2 replicas sont configurées
- Les requêtes sont redistribuées vers les pods survivants

### 2. `network-delay-200ms` — Latence réseau

**Type** : NetworkChaos  
**Durée** : 2 minutes  
**Cible** : Pods du frontend  
**Latence** : 200ms ± 50ms (jitter)

**Ce qu'on teste** :
- L'impact de la latence réseau sur l'expérience utilisateur
- Le frontend gère-t-il les timeouts correctement ?
- L'alerte `HighLatencyP95` se déclenche-t-elle dans Prometheus ?

**Résultat attendu** :
- La latence P95 augmente au-dessus de 2s → l'alerte Prometheus se déclenche
- Le site reste fonctionnel (pas de crash)
- Après la fin de l'expérience, la latence revient à la normale

### 3. `cpu-stress-frontend` — Stress CPU

**Type** : StressChaos  
**Durée** : 3 minutes  
**Cible** : Un pod frontend  
**Charge** : 2 workers à 80% CPU

**Ce qu'on teste** :
- Le HPA détecte-t-il l'augmentation de CPU ?
- De nouveaux pods sont-ils créés automatiquement ?
- L'alerte `HighCPUUsage` se déclenche-t-elle ?

**Résultat attendu** :
- Le HPA augmente les replicas du frontend
- Les nouveaux pods absorbent la charge
- Après la fin du stress, le HPA réduit les replicas (cooldown)

## Comment utiliser

### Accéder au dashboard

```bash
kubectl port-forward svc/chaos-dashboard -n chaos-mesh 2333:2333
# Ouvrir http://localhost:2333
```

### Lancer une expérience manuellement

```bash
# Appliquer une expérience
kubectl apply -f <experiment.yaml> -n chaos-mesh

# Ou via le dashboard : New Experiment → choisir le type
```

### Lancer via Terraform (déclaratif)

Les 3 expériences sont déjà créées par Terraform. Pour les activer :
1. Aller dans le dashboard
2. Les expériences sont en état "Paused" par défaut
3. Cliquer sur "Run" pour les lancer

### Vérifier les résultats

```bash
# Voir les expériences actives
kubectl get podchaos,networkchaos,stresschaos -n chaos-mesh

# Voir les événements
kubectl get events -n chaos-mesh --sort-by='.lastTimestamp'
```

## Séquence recommandée pour le test de charge

```
1. Lancer le test de charge k6 (baseline, 5 min)
2. Lancer pod-kill-random → observer le self-healing
3. Attendre 2 min de stabilisation
4. Lancer network-delay-200ms → observer la latence
5. Attendre 2 min de stabilisation
6. Lancer cpu-stress-frontend → observer le HPA
7. Documenter les résultats pour la soutenance
```

## Déploiement

```bash
cd live/prod/chaos-mesh
terragrunt apply
```

## Vérification

```bash
# Valider le module
cd terraform/modules/chaos-mesh
terraform init -backend=false && terraform validate

# Après déploiement
kubectl get pods -n chaos-mesh
kubectl get crd | grep chaos-mesh
```
