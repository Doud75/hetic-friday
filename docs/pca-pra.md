# Plan de Continuité et de Reprise d'Activité (PCA/PRA)

**Projet MT5 — HETIC**
**Équipe G2 — Avril 2026**

---

## 1. Objet du document

Ce document définit les stratégies, les mécanismes et les procédures mis en place pour assurer la continuité de service de la plateforme e-commerce Black Friday Survival en cas de défaillance partielle ou totale de l'infrastructure. Il couvre à la fois le Plan de Continuité d'Activité (PCA), qui décrit comment le système maintient sa disponibilité malgré une panne, et le Plan de Reprise d'Activité (PRA), qui décrit comment restaurer le système après un sinistre majeur.

L'objectif opérationnel de cette plateforme est de supporter 90 000 utilisateurs simultanés avec une latence au 95e percentile inférieure à deux secondes et un taux d'erreur inférieur à un pour cent. Le PCA/PRA est conçu pour maintenir ces engagements dans la mesure du possible, et pour définir des conditions dégradées acceptables lorsque le maintien nominal n'est plus réalisable.

---

## 2. Classification des risques

Avant de détailler les mesures de continuité et de reprise, il est nécessaire d'identifier les scénarios de défaillance auxquels l'infrastructure est exposée. Ces scénarios ont été classés par niveau de gravité en fonction de leur impact sur le service et de leur probabilité d'occurrence.

### 2.1 Risques de niveau 1 — Défaillance d'un composant unitaire

Ce niveau correspond à la perte d'un pod applicatif, d'un conteneur ou d'un nœud de calcul isolé. La probabilité est élevée en environnement Kubernetes, où les pods peuvent être détruits par le HPA, par un OOMKill, par un redéploiement ou par un évènement Spot. L'impact sur le service est nul ou négligeable tant que les mécanismes de réplication sont en place.

### 2.2 Risques de niveau 2 — Défaillance d'une zone de disponibilité

Ce niveau correspond à la perte complète d'une zone de disponibilité AWS (par exemple eu-central-1a). La probabilité est faible mais non nulle ; AWS a connu des incidents de zone documentés publiquement. L'impact est significatif car un tiers des ressources de calcul, de réseau et de données devient indisponible simultanément.

### 2.3 Risques de niveau 3 — Défaillance d'un service AWS managé

Ce niveau correspond à une panne du service RDS, du service EKS Control Plane, ou du service ALB au niveau régional. La probabilité est très faible mais ces scénarios se sont déjà produits historiquement. L'impact est majeur car ces services constituent les fondations de l'architecture.

### 2.4 Risques de niveau 4 — Sinistre majeur ou perte totale

Ce niveau correspond à la perte complète de la région AWS, à la corruption de l'état Terraform, à une compromission de sécurité entraînant la destruction de ressources, ou à une erreur humaine ayant détruit l'infrastructure. La probabilité est extrêmement faible mais l'impact est total.

---

## 3. Plan de Continuité d'Activité (PCA)

Le PCA décrit les mécanismes architecturaux qui permettent au système de continuer à fonctionner de manière transparente lorsqu'une défaillance survient, sans intervention humaine.

### 3.1 Continuité face à la perte d'un pod (Niveau 1)

Chaque microservice est déployé avec un minimum de réplicas garantissant qu'aucun pod isolé ne constitue un point de défaillance unique. Le frontend dispose d'un minimum de vingt réplicas, le CartService de dix, et le Nginx Cache Proxy de dix. Lorsque Kubernetes détecte qu'un pod ne répond plus (via les probes de liveness configurées sur chaque Deployment), il le détruit et en recrée un automatiquement. Ce mécanisme de self-healing est natif à Kubernetes et ne nécessite aucune intervention.

Le temps de rétablissement est de l'ordre de quinze à trente secondes, correspondant au délai de détection par la probe (initialDelaySeconds + periodSeconds) suivi du temps de démarrage du nouveau conteneur. Pendant ce délai, le Service Kubernetes redistribue automatiquement le trafic vers les pods restants. L'utilisateur ne perçoit aucune interruption car la perte d'un pod sur vingt ne représente qu'une réduction de cinq pour cent de la capacité, absorbée par les réplicas survivants.

Le Horizontal Pod Autoscaler complète ce mécanisme en réajustant le nombre de réplicas à la hausse si la charge CPU ou mémoire des pods restants augmente suite à la perte d'un réplica. La politique de scale-up permet une augmentation de 200 pour cent du nombre de pods toutes les quinze secondes, garantissant une réaction rapide en cas de perte simultanée de plusieurs pods.

Les pods du CartService intègrent un hook preStop avec un délai de quinze secondes, laissant le temps aux connexions gRPC en cours de se terminer proprement avant l'arrêt du conteneur. Le terminationGracePeriodSeconds est fixé à cent vingt secondes pour couvrir les requêtes longues. Ce mécanisme évite les erreurs de connexion côté client lors de la destruction planifiée d'un pod (scale-down, rolling update).

### 3.2 Continuité face à la perte d'un nœud de calcul (Niveau 1)

EKS Auto Mode surveille en permanence l'état des nœuds EC2. Si un nœud devient NotReady (panne matérielle, perte réseau, arrêt de l'instance Spot), Kubernetes marque tous ses pods comme défaillants et les reprogramme sur les nœuds restants. Si la capacité restante est insuffisante, EKS Auto Mode provisionne automatiquement de nouveaux nœuds EC2 en deux à quatre minutes.

Les pods sont répartis sur les trois zones de disponibilité par le scheduler Kubernetes, assurant qu'aucune zone ne concentre tous les réplicas d'un même service. La perte d'un nœud dans une zone n'affecte donc qu'une fraction des réplicas de chaque service.

Pour les charges de travail applicatives, l'utilisation d'instances Spot réduit les coûts de 60 à 70 pour cent par rapport aux instances On-Demand. La contrepartie est que AWS peut réclamer ces instances avec un préavis de deux minutes. EKS Auto Mode gère cette situation en provisionnant des instances de remplacement avant la terminaison effective, minimisant la fenêtre de réduction de capacité.

### 3.3 Continuité face à la perte d'une zone de disponibilité (Niveau 2)

L'architecture a été conçue dès l'origine pour survivre à la perte d'une zone de disponibilité complète sans interruption de service. Cette résilience repose sur trois mécanismes complémentaires déployés sur les trois couches de l'infrastructure.

Au niveau réseau, chaque zone de disponibilité dispose de son propre NAT Gateway en production. Si la zone eu-central-1a devient indisponible, les pods des zones eu-central-1b et eu-central-1c continuent d'accéder à Internet via leurs NAT Gateways respectifs. Les tables de routage sont configurées par zone : chaque subnet privé route vers le NAT Gateway de sa propre zone, évitant toute dépendance inter-zone pour le trafic sortant. L'Application Load Balancer est déployé sur les trois subnets publics et retire automatiquement la zone défaillante de sa rotation d'adresses IP, sans intervention.

Au niveau calcul, les pods Kubernetes sont répartis sur les nœuds des trois zones. La perte d'une zone entraîne la perte d'environ un tiers des réplicas de chaque service. Les réplicas survivants dans les deux zones restantes absorbent la charge supplémentaire, et le HPA provisionne de nouveaux réplicas qui seront placés sur les nœuds des zones fonctionnelles. La surcapacité initiale (vingt réplicas pour le frontend alors que dix suffiraient en temps normal) a été dimensionnée pour tolérer cette situation sans dégradation notable.

Au niveau données, l'instance RDS PostgreSQL fonctionne en mode Multi-AZ. AWS maintient une réplique synchrone de la base de données dans une zone de disponibilité différente de l'instance primaire. En cas de défaillance de la zone hébergeant l'instance primaire, AWS bascule automatiquement vers la réplique standby. Le failover prend entre soixante et cent vingt secondes, pendant lesquelles les connexions à la base de données sont interrompues. Le productcatalogservice, qui utilise des connexions PostgreSQL, recevra des erreurs de connexion pendant cette fenêtre. Les retry applicatifs et le cache Nginx (qui sert les pages récentes pendant deux minutes via stale-while-revalidate) atténuent l'impact sur l'utilisateur final.

Le cache Redis du CartService constitue un point de vigilance lors d'une perte de zone. Redis est déployé comme un pod unique avec un stockage emptyDir, ce qui signifie que la perte du nœud hébergeant Redis entraîne la perte de tous les paniers en cours. Les utilisateurs affectés devront reconstituer leur panier. Ce compromis a été accepté car le déploiement d'un cluster Redis HA (Sentinel ou Redis Cluster) aurait ajouté une complexité significative pour un bénéfice limité dans le contexte du projet. En production réelle, un service managé ElastiCache avec réplication Multi-AZ serait recommandé.

### 3.4 Continuité du monitoring

Le stack de monitoring est déployé dans un namespace dédié, indépendant du namespace applicatif. La perte de pods de monitoring n'affecte pas le fonctionnement de l'application. Prometheus stocke ses métriques sur un volume EBS persistant (StorageClass ebs-auto), ce qui garantit la survie des données métriques même en cas de destruction et recréation du pod Prometheus.

Les alertes PrometheusRule continuent de fonctionner tant que Prometheus et AlertManager sont opérationnels. En cas de perte du monitoring lui-même, les alarmes CloudWatch (NAT Gateway, budgets) constituent un filet de sécurité indépendant car elles sont gérées entièrement par AWS, sans dépendance au cluster Kubernetes.

### 3.5 Continuité face aux attaques (sécurité)

Le WAF v2 placé devant l'ALB constitue la première ligne de défense contre les attaques volumétriques et applicatives. Le rate-limiting à 2 000 requêtes par cinq minutes par adresse IP bloque les attaques par déni de service de faible intensité. Les règles managées AWS (Common Rule Set, Known Bad Inputs, SQL Injection) sont mises à jour automatiquement par AWS lorsque de nouvelles vulnérabilités sont découvertes.

En cas d'attaque DDoS de grande ampleur, AWS Shield Standard (inclus gratuitement) protège la couche 3/4 (volumétrique, SYN flood). L'ALB absorbe naturellement les pics de trafic grâce à son élasticité managée. Si l'attaque cible la couche applicative (HTTP flood), le rate-limiting WAF entre en action.

La compromission d'un pod applicatif est limitée par les SecurityContexts restrictifs (pas de root, filesystem en lecture seule, aucune capability Linux) et par IRSA qui empêche un pod compromis d'accéder à des services AWS non autorisés. La NACL de la couche données empêche tout mouvement latéral vers la base de données sur un port autre que 5432, même si le Security Group est contourné.

### 3.6 Continuité face au cache froid

Lors d'un redémarrage massif des pods Nginx Cache Proxy (rolling update, scaling event), le cache en mémoire est perdu et toutes les requêtes atteignent directement le frontend. Ce scénario de "cache froid" peut provoquer un pic de charge sur le frontend. Deux mécanismes atténuent cet impact.

Le premier est le proxy_cache_lock, qui garantit qu'une seule requête à la fois est envoyée au frontend pour chaque URL. Les requêtes suivantes pour la même URL attendent que le cache soit rempli plutôt que de saturer le backend. Le second est le dimensionnement du frontend à vingt réplicas minimum, une capacité suffisante pour absorber le trafic direct le temps que le cache se reconstitue (environ deux minutes pour le cache dynamique).

---

## 4. Plan de Reprise d'Activité (PRA)

Le PRA décrit les procédures à suivre lorsque les mécanismes automatiques du PCA ne suffisent pas et qu'une intervention humaine est nécessaire pour restaurer le service.

### 4.1 Objectifs de reprise

Les objectifs de reprise ont été définis en fonction de la criticité de chaque composant et des contraintes techniques de l'infrastructure.

Le RTO (Recovery Time Objective) représente la durée maximale acceptable d'interruption de service. Pour la couche applicative (pods Kubernetes), le RTO cible est de cinq minutes, correspondant au temps de provisionnement d'un nœud EKS et de démarrage des pods. Pour la base de données, le RTO cible est de dix minutes, correspondant au temps de restauration d'un snapshot RDS. Pour l'infrastructure complète (reconstruction depuis zéro via Terragrunt), le RTO cible est de quarante-cinq minutes, correspondant au temps d'exécution d'un `terragrunt run-all apply` complet.

Le RPO (Recovery Point Objective) représente la quantité maximale de données qu'il est acceptable de perdre. Pour la base de données RDS, le RPO est de zéro en fonctionnement Multi-AZ normal (réplication synchrone), et de vingt-quatre heures en cas de restauration depuis un snapshot automatique (AWS effectue un snapshot quotidien). Pour les données de cache Redis, le RPO est de la totalité des paniers en cours car Redis fonctionne sans persistance disque. Pour les métriques Prometheus, le RPO est de quinze jours en production (durée de rétention configurée), mais les données sont perdues si le volume EBS est détruit.

Pour l'état Terraform, le RPO est de zéro grâce au versioning S3. Chaque modification du state est versionnée automatiquement, permettant un rollback à n'importe quel état antérieur.

### 4.2 Procédure de reprise — Perte d'un service applicatif

Si un ou plusieurs microservices sont en erreur persistante (CrashLoopBackOff) et que le self-healing Kubernetes ne résout pas le problème, la procédure de reprise consiste d'abord à diagnostiquer la cause via les logs du pod (`kubectl logs <pod> --previous` pour voir les logs du dernier crash) et les événements (`kubectl describe pod <pod>`).

Si la cause est un OOMKill (dépassement de la limite mémoire), la résolution immédiate est d'augmenter la limite mémoire du Deployment via `kubectl patch`. Si la cause est une erreur applicative (dépendance indisponible, configuration incorrecte), un rollback vers la version précédente via `kubectl rollout undo deployment/<service>` permet de restaurer un état fonctionnel en moins d'une minute.

Si le redémarrage complet d'un service est nécessaire, la commande `kubectl rollout restart deployment/<service>` déclenche un rolling update qui remplace tous les pods un par un, sans interruption de service (grâce au paramètre maxUnavailable par défaut de 25 pour cent).

### 4.3 Procédure de reprise — Perte de la base de données

En cas de corruption irréversible de la base de données ou de suppression accidentelle, la procédure de reprise suit trois étapes.

La première étape est la restauration d'un snapshot. AWS crée automatiquement un snapshot quotidien de l'instance RDS. La restauration crée une nouvelle instance RDS à partir de ce snapshot, avec un nouveau endpoint. Le temps de restauration dépend de la taille de la base de données, mais est généralement inférieur à dix minutes pour une instance de vingt Go.

La deuxième étape est la mise à jour de la configuration. Le nouvel endpoint RDS doit être mis à jour dans AWS Secrets Manager, soit manuellement, soit en modifiant le secret dans le module Terraform RDS et en réappliquant. External Secrets Operator détectera le changement lors de son prochain cycle de synchronisation (maximum une heure) ou peut être forcé via la suppression du Secret Kubernetes qui déclenche une re-synchronisation immédiate.

La troisième étape est le re-seed des données produits. Le Job Kubernetes `seed-products` doit être relancé pour réinsérer les neuf produits dans la base restaurée. La clause `ON CONFLICT DO NOTHING` du script SQL garantit l'idempotence de cette opération : elle peut être exécutée plusieurs fois sans risque de duplication.

### 4.4 Procédure de reprise — Reconstruction totale de l'infrastructure

En cas de perte complète de l'infrastructure (suppression accidentelle, compromission de sécurité, corruption du state Terraform), la reconstruction suit une procédure ordonnée rendue possible par l'Infrastructure as Code.

La condition préalable est de disposer du code source (repository Git) et des fichiers `secrets.hcl` (stockés hors Git). Le state Terraform, stocké dans S3 avec versioning activé, peut être restauré à une version antérieure si le bucket existe encore.

Si le state est irrécupérable, une reconstruction complète est lancée via `terragrunt run-all apply` depuis le répertoire `live/prod/`. Terragrunt résout automatiquement les dépendances entre modules et les déploie dans l'ordre correct : VPC en premier, puis Security et EKS en parallèle, puis RDS et ALB une fois leurs dépendances satisfaites, et enfin les modules de monitoring et d'opérations.

Le temps total de reconstruction a été mesuré à environ quarante-cinq minutes, dont la majeure partie est consommée par la création du cluster EKS (douze à quinze minutes), de l'instance RDS Multi-AZ (huit à dix minutes) et des NAT Gateways (trois à cinq minutes chacun).

Après la reconstruction de l'infrastructure, les manifests Kubernetes doivent être réappliqués via le pipeline CD (workflow_dispatch) ou manuellement via `kubectl apply -f app/kubernetes-manifests/`. Le Job seed-products réinjecte les données produits dans la base.

### 4.5 Procédure de reprise — Compromission de sécurité

Si une compromission de sécurité est détectée (accès non autorisé, comportement suspect d'un pod, exfiltration de données), la procédure de réponse suit quatre phases.

La phase de confinement consiste à isoler le composant compromis. Si un pod est suspect, sa suppression immédiate (`kubectl delete pod`) le retire du Service et coupe les connexions. Si un nœud est suspect, son cordon (`kubectl cordon`) empêche les nouveaux pods d'y être programmés, et son drain (`kubectl drain --force`) évacue les pods existants. Si les credentials de la base de données sont compromis, la rotation du secret dans AWS Secrets Manager invalide les anciens credentials. ESO synchronise les nouveaux credentials dans Kubernetes lors du prochain cycle de refresh.

La phase d'investigation exploite les VPC Flow Logs (CloudWatch Logs Insights) pour analyser le trafic réseau anormal, les logs WAF pour identifier les vecteurs d'attaque, et les traces Jaeger pour reconstituer le parcours de la requête malveillante.

La phase de remédiation peut inclure l'ajout de règles WAF pour bloquer le vecteur d'attaque identifié, la rotation des credentials, la mise à jour des images Docker si une vulnérabilité CVE est en cause, ou dans le cas extrême, la reconstruction complète de l'infrastructure depuis zéro (procédure 4.4).

La phase de post-incident produit un rapport post-mortem documentant la chronologie, la cause racine, les mesures correctives et les actions préventives.

### 4.6 Procédure de reprise — Dépassement budgétaire

Si les alertes budgétaires signalent un dépassement imminent ou réel, la procédure de reprise économique suit un ordre de priorité visant à réduire les coûts avec un impact minimal sur le service.

La première action est l'arrêt de l'environnement de développement (`cd live/dev && terragrunt run-all destroy`), qui libère immédiatement toutes les ressources dev sans aucun impact sur la production.

La deuxième action est la réduction des maxReplicas des HPAs des services non critiques (adservice, recommendationservice, emailservice) pour limiter le scaling.

La troisième action, en dernier recours, est le scale-down manuel des services critiques vers leurs minimums configurés et l'arrêt des tests de charge.

---

## 5. Matrice de correspondance risques — mesures

Le tableau suivant synthétise la correspondance entre chaque scénario de défaillance, les mesures de continuité automatiques (PCA) et les procédures de reprise manuelles (PRA) associées.

| Scénario | Probabilité | Impact | PCA (automatique) | PRA (manuel) | RTO |
|---|---|---|---|---|---|
| Perte d'un pod | Très élevée | Nul | Self-healing K8s, HPA, Service redistribution | Aucune action requise | 15-30s |
| Perte d'un nœud | Élevée | Faible | EKS Auto Mode reprovisionne, pods reprogrammés | Aucune action requise | 2-4 min |
| Perte d'une zone AZ | Faible | Moyen | Multi-AZ (NAT, ALB, RDS), HPA scale pods restants | Vérifier failover RDS, monitorer la capacité | 1-2 min |
| Panne RDS | Très faible | Élevé | Failover Multi-AZ automatique | Restauration snapshot si corruption | 10 min |
| Panne ALB | Très faible | Critique | Aucun (service managé AWS) | Recréation via Terraform | 5 min |
| Attaque DDoS L3/L4 | Moyenne | Moyen | AWS Shield Standard, ALB scaling | Activer Shield Advanced si nécessaire | Immédiat |
| Attaque applicative L7 | Moyenne | Moyen | WAF rate-limit, managed rules | Ajout de règles WAF custom | Immédiat |
| Compromission d'un pod | Faible | Élevé | SecurityContext, IRSA, NACL isolation | Confinement, investigation, remédiation | Variable |
| Perte totale région | Extrême | Total | Aucun (mono-région) | Reconstruction dans une autre région | 45+ min |
| Corruption state TF | Très faible | Élevé | Versioning S3 | Restauration version S3, ou import | 15 min |
| Dépassement budget | Moyenne | Moyen | Alertes 50/80/100%, forecast | Arrêt dev, réduction scaling | Immédiat |
| Cache froid (Nginx) | Moyenne | Faible | proxy_cache_lock, stale-while-revalidate | Aucune action, reconstitution en 2 min | 2 min |
| Perte Redis | Faible | Moyen | Aucun (pas de persistance) | Paniers perdus, reconstitution par les utilisateurs | Immédiat |

---

## 6. Tests de validation du PCA

La validité du PCA est vérifiée par des tests d'injection de pannes via Chaos Mesh, exécutés en conditions de charge réelle.

### 6.1 Test de self-healing (pod-kill-random)

L'expérience `pod-kill-random` détruit un pod applicatif aléatoire toutes les trente secondes. Le résultat attendu est l'absence d'impact utilisateur mesurable : la latence P95 ne doit pas dépasser le seuil de deux secondes et le taux d'erreur doit rester inférieur à un pour cent. Ce test valide la continuité de niveau 1.

### 6.2 Test de dégradation réseau (network-delay-200ms)

L'expérience `network-delay-200ms` injecte une latence artificielle de deux cents millisecondes sur les pods frontend pendant deux minutes. Le résultat attendu est le déclenchement de l'alerte PrometheusRule `HighLatencyP95` (validant le monitoring) et la continuité du service (le site reste fonctionnel malgré la dégradation). Ce test valide la détection et la tolérance aux dégradations de niveau 1.

### 6.3 Test de saturation CPU (cpu-stress-frontend)

L'expérience `cpu-stress-frontend` sature le CPU d'un pod frontend pendant trois minutes. Le résultat attendu est la réaction du HPA (augmentation du nombre de réplicas) et l'absorption de la charge par les nouveaux pods sans impact utilisateur. Ce test valide le mécanisme de scaling automatique qui constitue le socle du PCA de niveau 1 et 2.

### 6.4 Séquence de test recommandée

La validation complète du PCA doit être exécutée en conditions de charge réelle (au moins 15 000 utilisateurs virtuels via k6) selon la séquence suivante : établir une baseline de performance pendant cinq minutes, exécuter pod-kill-random, observer le self-healing pendant deux minutes, exécuter network-delay-200ms, vérifier le déclenchement de l'alerte et la continuité pendant deux minutes, exécuter cpu-stress-frontend, vérifier le scaling pendant trois minutes, et enfin mesurer les métriques finales (latence, erreurs, replicas) pour comparaison avec la baseline.

---

## 7. Limites identifiées et axes d'amélioration

### 7.1 Architecture mono-région

L'architecture actuelle est déployée dans la seule région eu-central-1. En cas de perte complète de la région (scénario extrême), aucun mécanisme de failover automatique n'est en place. La reconstruction dans une autre région nécessiterait de modifier les configurations Terragrunt (variable `region`), de recréer le bucket S3 de state, et de relancer un déploiement complet. En production réelle, une architecture multi-région avec une réplication active-passive de la base de données et un routage DNS (Route 53 failover) serait recommandée.

### 7.2 Redis sans persistance

Le cache Redis fonctionne avec un stockage emptyDir, ce qui signifie que toutes les données de panier sont perdues en cas de redémarrage du pod. En production réelle, l'utilisation d'Amazon ElastiCache avec réplication Multi-AZ et persistance RDB ou AOF éliminerait ce point de défaillance unique.

### 7.3 Absence de backup automatisé externalisé

Bien que RDS effectue des snapshots quotidiens automatiques, ces snapshots restent dans la même région AWS. Une stratégie de backup robuste nécessiterait la copie cross-région des snapshots RDS et l'export périodique des données vers un bucket S3 dans une région secondaire.

### 7.4 Absence de HTTPS

L'absence de chiffrement TLS entre les utilisateurs et l'ALB expose le trafic HTTP à l'interception. En production réelle, un certificat ACM associé à un listener HTTPS sur l'ALB est indispensable. Le module Terraform ALB est prêt à accueillir cette configuration mais nécessite un nom de domaine.

### 7.5 Rotation planifiée des secrets

Les credentials RDS sont actuellement statiques. External Secrets Operator supporte la rotation automatique des secrets, mais celle-ci n'est pas configurée. En production réelle, une rotation à intervalles réguliers (90 jours) réduirait le risque de compromission par des credentials volés.

---

## 8. Gouvernance et responsabilités

Le PCA/PRA est un document vivant qui doit être révisé à chaque modification structurelle de l'infrastructure (ajout d'un module Terraform, changement de dimensionnement, modification de la topologie réseau).

La validation du PCA par les tests Chaos Mesh doit être exécutée avant chaque campagne de test de charge majeure afin de confirmer que les mécanismes de continuité fonctionnent dans les conditions réelles de la charge prévue.

Le PRA doit être testé au minimum une fois en déroulant la procédure de reconstruction complète (section 4.4) sur l'environnement de développement, afin de valider les RTO annoncés et d'identifier les éventuelles dépendances non documentées.
