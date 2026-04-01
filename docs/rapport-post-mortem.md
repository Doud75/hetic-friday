# Rapport Post-Mortem — Analyse post-incident

**Projet MT5 — HETIC**
**Équipe G2 — Avril 2026**

---

## 1. Synthèse des incidents

Au cours du cycle de vie du projet, sept incidents majeurs ont été identifiés, diagnostiqués et résolus. Chaque incident est analysé ci-dessous selon une structure normalisée : contexte de détection, chronologie, impact sur le service, analyse de la cause racine, résolution appliquée, mesures correctives et enseignements.

| # | Incident | Sévérité | Durée d'impact | Cause racine | Détection |
|---|---|---|---|---|---|
| 1 | Échec de création du cluster EKS | P1 — Critique | ~2h | Permission `sts:TagSession` manquante | Terraform apply échoué |
| 2 | Pods bloqués en Pending (nœuds non provisionnés) | P1 — Critique | ~3h | Tag `kubernetes.io/cluster` absent des subnets | kubectl get pods |
| 3 | Limite d'Elastic IPs atteinte | P2 — Majeur | ~1h | EIPs orphelines de sessions Terraform avortées | Terraform apply échoué |
| 4 | Prometheus bloqué en Pending | P3 — Mineur | ~2h | StorageClass `gp2` incompatible avec EKS Auto Mode | kubectl get pvc |
| 5 | Timeouts Helm du stack monitoring | P3 — Mineur | ~1h | Timeout par défaut (600s) trop court pour EKS Auto Mode | Helm apply échoué |
| 6 | ALB non provisionnable automatiquement | P1 — Critique | ~5 jours (résolution complète) | Restriction `OperationNotPermitted` au niveau du compte AWS | Service K8s en Pending |
| 7 | Erreurs 500 sous forte charge (CartService) | P2 — Majeur | Récurrent pendant les tests | Scale-down prématuré du HPA provoquant des coupures gRPC | Métriques Prometheus + k6 |

---

## 2. Analyse détaillée des incidents

### Incident 1 — Échec de création du cluster EKS (`sts:TagSession`)

**Contexte de détection.** Lors de la première exécution de `terragrunt apply` sur le module EKS, Terraform a retourné une erreur IAM empêchant la création du cluster. L'ensemble de la chaîne de déploiement était bloqué puisque tous les modules suivants (monitoring, ALB, ESO) dépendent de l'existence du cluster.

**Chronologie.**  
Le déploiement initial du cluster a été lancé après la création réussie du VPC et des Security Groups. La commande `terragrunt apply` dans le module EKS a échoué au bout de quelques minutes avec un message d'erreur cryptique mentionnant une permission STS insuffisante. La première hypothèse de l'équipe était un problème de credentials AWS locales. Après vérification que les credentials étaient valides, l'attention s'est portée sur la trust policy du rôle IAM du cluster.

**Analyse de la cause racine.** EKS Auto Mode requiert la permission `sts:TagSession` dans la trust policy du rôle IAM du cluster. Cette permission permet au service EKS de taguer les sessions d'authentification lors du provisionnement automatique des nœuds. La documentation AWS mentionne cette exigence dans une sous-section de la page EKS Auto Mode, mais ne la signale pas comme un prérequis explicite dans le guide de démarrage rapide. Le rôle IAM, construit à partir d'exemples Terraform standards pour EKS classique, n'incluait pas cette permission car elle n'est pas nécessaire en dehors du mode Auto.

**Impact.** Total. Aucun composant ne pouvait être déployé tant que le cluster n'existait pas. L'équipe a été bloquée pendant environ deux heures, le temps de diagnostiquer, corriger et relancer le déploiement.

**Résolution.** L'ajout de `sts:TagSession` dans le bloc `assume_role_policy` du rôle IAM du cluster a résolu l'erreur immédiatement. Le cluster a été créé avec succès au second essai.

**Mesures correctives.** La correction a été intégrée dans le module Terraform `eks/main.tf` de manière permanente. Un commentaire explicite a été ajouté dans le code pour documenter cette dépendance non évidente, évitant que l'équipe ne supprime cette permission par erreur lors d'un refactoring futur.

**Enseignement.** Les modes managés avancés des services AWS (Auto Mode, Fargate, etc.) imposent souvent des prérequis IAM qui ne figurent pas dans les guides d'utilisation standard. Lorsqu'on utilise un mode récent d'un service AWS, il est préférable de consulter la page IAM Permissions dédiée plutôt que de s'appuyer sur les politiques IAM des exemples communautaires.

---

### Incident 2 — Pods bloqués en Pending (nœuds non provisionnés)

**Contexte de détection.** Après la création réussie du cluster EKS, les manifests Kubernetes ont été appliqués. L'ensemble des pods restaient en état `Pending` sans aucune progression. La commande `kubectl get nodes` ne retournait aucun nœud, alors qu'EKS Auto Mode est censé les provisionner automatiquement à la demande.

**Chronologie.** Les manifests ont été appliqués immédiatement après la création du cluster. Après dix minutes d'attente sans qu'aucun nœud n'apparaisse, l'équipe a exécuté `kubectl describe pod` sur un pod en Pending. Les événements indiquaient que le scheduler ne trouvait aucun nœud éligible, mais ne donnaient pas d'explication sur l'absence de provisionnement. L'investigation a nécessité de consulter les logs du contrôleur EKS Auto Mode (via CloudWatch), qui ont révélé que le contrôleur ne trouvait aucun subnet valide pour lancer des instances EC2.

**Analyse de la cause racine.** EKS Auto Mode découvre les subnets dans lesquels il est autorisé à provisionner des nœuds via le tag `kubernetes.io/cluster/<cluster-name>=owned`. Ce tag est ajouté automatiquement lorsque le VPC est créé via `eksctl` ou la console AWS, mais pas lorsqu'il est créé indépendamment via Terraform. Le module VPC Terraform du projet ne posait pas ce tag, car il avait été développé avant le choix d'EKS Auto Mode.

**Impact.** Total. L'application était intégralement indisponible. Aucun pod ne pouvait démarrer et aucune requête utilisateur ne pouvait être servie. L'incident a duré environ trois heures, le temps d'identifier la cause (deux heures de diagnostic) et d'appliquer la correction (trente minutes pour taguer les subnets et attendre le provisionnement des nœuds).

**Résolution.** L'ajout immédiat du tag via `aws ec2 create-tags` sur les six subnets privés a permis à EKS Auto Mode de détecter les subnets et de lancer les premiers nœuds EC2 en deux minutes. Les pods ont commencé à être schedulés dans les cinq minutes suivantes.

**Mesures correctives.** Le tag a été ajouté dans le module Terraform VPC (`vpc/main.tf`) sur toutes les ressources `aws_subnet` privées, avec une interpolation dynamique du nom du cluster. Le tag `kubernetes.io/role/internal-elb=1` a également été ajouté sur les subnets privés et `kubernetes.io/role/elb=1` sur les subnets publics, qui sont requis par le contrôleur de load balancing d'EKS pour savoir où créer les load balancers internes et publics.

**Enseignement.** Lorsqu'on compose des modules Terraform indépendants (VPC d'un côté, EKS de l'autre), les contrats implicites entre services AWS — comme les tags de découverte — ne sont pas appliqués automatiquement. Il est essentiel de documenter ces contrats dans les variables d'output/input entre modules et de les tester systématiquement lors de l'intégration.

---

### Incident 3 — Limite d'Elastic IPs atteinte (`AddressLimitExceeded`)

**Contexte de détection.** Lors d'une reconstruction de l'infrastructure (après une modification du module VPC nécessitant une recréation), `terragrunt apply` a échoué avec l'erreur `AddressLimitExceeded` lors de la création des NAT Gateways.

**Chronologie.** L'erreur est apparue immédiatement lors de l'allocation des Elastic IPs pour les NAT Gateways. Le compte AWS est limité à cinq Elastic IPs par région par défaut. L'infrastructure en produit trois (une par NAT Gateway en production), mais des sessions Terraform précédentes qui avaient été interrompues avaient laissé des EIPs allouées mais non associées à aucune ressource.

**Analyse de la cause racine.** Terraform alloue les Elastic IPs comme des ressources distinctes avant de les associer aux NAT Gateways. Si le `terraform apply` est interrompu entre ces deux étapes (par un timeout, un Ctrl+C, ou une erreur sur une autre ressource), les EIPs restent allouées dans le compte AWS mais ne sont pas associées. Le `terraform destroy` suivant peut échouer à les libérer si le state est devenu incohérent. Au fil des itérations de destroy/apply, quatre EIPs orphelines se sont accumulées, atteignant la limite de cinq.

**Impact.** Modéré. L'infrastructure ne pouvait pas être recréée, mais aucun service en production n'était affecté puisque l'environnement en cours était déjà détruit. L'incident a bloqué l'équipe pendant environ une heure.

**Résolution.** La commande `aws ec2 describe-addresses --query 'Addresses[?AssociationId==null]'` a permis d'identifier les quatre EIPs orphelines. Chacune a été libérée via `aws ec2 release-address`. Le déploiement a ensuite réussi.

**Mesures correctives.** Une procédure de vérification pré-déploiement a été ajoutée dans le runbook de déploiement : avant tout `terragrunt run-all apply`, vérifier l'absence de ressources orphelines (EIPs, ENIs, volumes EBS). Une demande d'augmentation de la limite EIP à dix par région a été soumise via le Service Quotas AWS.

**Enseignement.** Les interruptions de `terraform apply` ou `destroy` peuvent laisser des ressources orphelines invisibles au state Terraform. Dans un environnement partagé ou avec des limites de quotas serrées, une vérification régulière des ressources non rattachées est nécessaire. L'outil `aws-nuke` ou des scripts de nettoyage périodiques pourraient automatiser cette vérification.

---

### Incident 4 — Prometheus bloqué en Pending (StorageClass incompatible)

**Contexte de détection.** Après le déploiement réussi du chart kube-prometheus-stack via Helm, tous les pods du stack monitoring ont démarré correctement à l'exception de Prometheus. Le pod restait en `Pending` tandis que son PersistentVolumeClaim affichait l'état `Pending` indéfiniment.

**Chronologie.** L'incident a été détecté lors de la vérification post-déploiement du stack monitoring (`kubectl get pods -n monitoring`). Le premier réflexe a été de vérifier les événements du pod via `kubectl describe pod`, qui indiquaient un problème de volume. L'examen du PVC via `kubectl describe pvc` montrait que le provisionneur n'arrivait pas à créer le volume, mais le message d'erreur ne mentionnait pas explicitement la cause. L'investigation a nécessité l'inspection du contrôleur de storage EBS CSI et la comparaison des StorageClasses disponibles (`kubectl get storageclass`) avec celle demandée par le PVC.

**Analyse de la cause racine.** Le chart Helm kube-prometheus-stack utilise par défaut la StorageClass `gp2`, qui repose sur le provisionneur in-tree `kubernetes.io/aws-ebs`. Ce provisionneur est compatible avec les clusters EKS classiques mais pas avec EKS Auto Mode, qui utilise exclusivement le driver CSI `ebs.csi.eks.amazonaws.com` et expose une StorageClass nommée `ebs-auto`. Le PVC demandait un volume au provisionneur `gp2`, mais ce provisionneur n'existait pas dans le cluster Auto Mode, rendant la demande impossible à satisfaire.

**Impact.** Limité au monitoring. L'application fonctionnait normalement, mais l'absence de Prometheus signifiait l'absence de collecte de métriques, de dashboards Grafana fonctionnels, et d'alertes. Pour un projet dont l'objectif est justement de démontrer l'observabilité sous charge, cette situation était néanmoins bloquante.

**Résolution.** L'ajout d'un paramètre `set` dans la configuration Helm Terraform, spécifiant explicitement `storageClassName = ebs-auto` pour le volume de Prometheus, a résolu le problème. Le PVC a été provisionné en dix secondes après le redéploiement du chart.

**Mesures correctives.** La StorageClass a été vérifiée pour tous les autres composants du stack nécessitant du stockage persistant (AlertManager). Un commentaire dans le module Terraform monitoring-k8s documente cette incompatibilité et rappelle qu'en EKS Auto Mode, toute StorageClass doit être `ebs-auto`.

**Enseignement.** Les charts Helm communautaires sont conçus pour fonctionner dans l'environnement Kubernetes le plus courant. Lorsqu'on utilise un environnement spécifique (EKS Auto Mode, Fargate, GKE Autopilot), il faut auditer systématiquement les valeurs par défaut du chart pour identifier les hypothèses incompatibles. La StorageClass est l'un des points de friction les plus fréquents.

---

### Incident 5 — Timeouts Helm lors du déploiement du monitoring

**Contexte de détection.** Le déploiement du chart kube-prometheus-stack via `terragrunt apply` sur le module monitoring-k8s échouait de manière répétée avec un timeout Helm après 600 secondes.

**Chronologie.** Le premier déploiement a échoué après exactement dix minutes (600 secondes, timeout Helm par défaut). L'examen des pods à ce moment montrait que certains composants (AlertManager, kube-state-metrics) étaient en `Running`, mais que d'autres (Prometheus, node-exporter) étaient encore en `Pending` ou `ContainerCreating`. Le deuxième essai, lancé immédiatement après, a échoué de la même manière. L'examen des événements de cluster a révélé que des nœuds étaient en cours de provisionnement par EKS Auto Mode, mais n'étaient pas encore prêts au moment du timeout.

**Analyse de la cause racine.** L'origine du problème est la séquence de provisionnement d'EKS Auto Mode. Lors d'un déploiement initial, le chart crée simultanément une dizaine de pods (Prometheus, Grafana, AlertManager, node-exporter sur chaque nœud, kube-state-metrics, opérateurs). Ces pods demandent des ressources (CPU, mémoire) qui dépassent la capacité des nœuds existants, déclenchant le provisionnement de nouveaux nœuds EC2. Ce provisionnement prend entre deux et quatre minutes par nœud (lancement de l'instance, boot de l'OS, initialisation du kubelet, enregistrement dans le cluster, application des taints). Or, le chart contient des dépendances séquentielles : certains pods ne peuvent démarrer qu'après que d'autres soient prêts. Le cumul du provisionnement des nœuds et des dépendances inter-pods dépasse facilement les 600 secondes.

**Impact.** Limité au déploiement. Aucun service n'était affecté puisqu'il s'agissait d'un déploiement initial. L'incident a causé environ une heure de perte de temps (deux essais échoués, diagnostic, correction).

**Résolution.** Le timeout Helm a été augmenté de 600 à 900 secondes dans la configuration Terraform du module monitoring-k8s. Cette valeur offre une marge confortable pour le provisionnement des nœuds (jusqu'à cinq nœuds en séquence) tout en restant suffisamment basse pour détecter un véritable blocage.

**Mesures correctives.** Le timeout a été documenté avec un commentaire expliquant pourquoi les 600 secondes par défaut ne suffisent pas en EKS Auto Mode. Les modules Helm des autres composants (Chaos Mesh, ESO) ont été vérifiés et leurs timeouts ajustés de manière préventive.

**Enseignement.** Les timeouts par défaut des outils de déploiement (Helm, Terraform, kubectl) sont calibrés pour des clusters où les nœuds sont déjà provisionnés. Lorsque le provisionnement des nœuds est dynamique (Auto Mode, Karpenter, Cluster Autoscaler), ces timeouts doivent être ajustés pour inclure le temps de provisionnement des nœuds. Une règle empirique est d'ajouter quatre minutes par nœud potentiellement nécessaire.

---

### Incident 6 — ALB non provisionnable automatiquement (`OperationNotPermitted`)

**Contexte de détection.** Après le déploiement de l'application, le Service Kubernetes de type `LoadBalancer` est resté en état `Pending`. Aucun Load Balancer n'est apparu dans la console AWS. Sans point d'entrée réseau, l'application était déployée mais inaccessible depuis Internet.

**Chronologie.** Cet incident est celui qui a eu la durée de résolution la plus longue du projet. Il s'est déroulé en trois phases distinctes.

La phase de diagnostic (jour 1) a consisté à identifier pourquoi le Service restait en Pending. L'examen des événements du Service (`kubectl describe svc`) et des logs du contrôleur EKS ont révélé l'erreur `OperationNotPermitted`, indiquant que le compte AWS avait une restriction empêchant EKS Auto Mode de provisionner des Load Balancers. Cette restriction, propre au compte fourni dans le cadre du projet, n'était pas contournable par l'équipe.

La phase de contournement immédiat (jour 1-2) a consisté à créer manuellement un ALB via la console AWS et le CLI. L'équipe a créé un Security Group dédié, un Application Load Balancer dans les trois subnets publics, deux Target Groups de type IP (un pour le frontend sur le port 8080, un pour Grafana sur le port 3000), et les listener rules associées. Des règles de Security Group ont été ajoutées sur le SG du cluster pour autoriser le trafic depuis le SG de l'ALB vers les pods. Cette solution a rendu l'application accessible, mais elle était fragile : les Target Groups ciblaient les adresses IP des pods, qui changent à chaque redémarrage. Chaque scale-up, scale-down, ou CrashLoop rendait les targets Unhealthy jusqu'à correction manuelle.

La phase de solution définitive (jours 3 à 5) a consisté à développer un module Terraform complet pour gérer l'ALB de manière déclarative. Ce module provisionne automatiquement le Security Group, le Load Balancer, cinq Target Groups (frontend, Grafana, Prometheus, AlertManager, Jaeger), les listener rules avec routage par chemin, un WAF v2 avec quatre ensembles de règles de sécurité, et les TargetGroupBinding CRDs qui permettent à EKS de maintenir dynamiquement les IPs des pods dans les Target Groups.

**Analyse de la cause racine.** La cause fondamentale est une restriction IAM au niveau du compte AWS qui empêche le service EKS de créer des ressources Elastic Load Balancing. Ce type de restriction est courant dans les comptes AWS à usage pédagogique ou sandboxé, où certaines opérations coûteuses ou risquées sont restreintes par des Service Control Policies (SCPs). Le contrôleur de load balancing intégré à EKS Auto Mode ne dispose pas des permissions nécessaires pour appeler les API ELBv2, ce qui bloque toute création automatique de Load Balancer depuis un Service ou un Ingress Kubernetes.

**Impact.** Critique. L'application était déployée mais totalement inaccessible depuis Internet pendant le jour 1. Accessible de manière fragile pendant les jours 2-3 (nécessitant des interventions manuelles à chaque scaling event). Pleinement opérationnelle à partir du jour 5 avec le module Terraform.

**Résolution.** Le module Terraform `alb` a résolu l'ensemble des problèmes en une seule abstraction : l'ALB est créé par Terraform (contournant la restriction EKS), les TargetGroupBindings assurent la synchronisation dynamique des pods (résolvant la fragilité des IPs), et le WAF ajoute une couche de sécurité qui n'existait pas dans la version manuelle.

**Mesures correctives.** Un ADR (Architecture Decision Record) a été rédigé (ADR-006) documentant le choix de l'ALB Terraform avec WAF, les alternatives considérées (Nginx Ingress Controller, Service type LoadBalancer, CloudFront), et les raisons du rejet de chacune. Le module ALB a été intégré dans l'arbre de dépendances Terragrunt avec les variables de sortie du VPC et de l'EKS comme inputs.

**Enseignement.** Les restrictions de compte AWS ne sont généralement pas documentées à l'avance. Il est préférable de concevoir l'infrastructure en supposant que certaines opérations automatiques pourraient échouer, et de prévoir des chemins de contournement via Terraform. Par ailleurs, ce qui semblait initialement être un obstacle s'est révélé bénéfique : le module Terraform ALB offre un contrôle bien supérieur à celui du provisionnement automatique (path-based routing, WAF, gestion fine des Target Groups), et constitue une meilleure pratique en production réelle.

---

### Incident 7 — Erreurs 500 sous forte charge (scale-down prématuré du CartService)

**Contexte de détection.** Lors des premières campagnes de tests de charge k6 au-delà de 30 000 utilisateurs virtuels, des erreurs HTTP 500 intermittentes apparaissaient sur les requêtes ciblant le CartService. Les erreurs n'étaient pas constantes : elles survenaient par rafales de quelques secondes, disparaissaient, puis revenaient.

**Chronologie.** Le pattern a été identifié en corrélant trois sources de données. Les métriques k6 montraient des pics d'erreurs 500 espacés de deux à quatre minutes. Les métriques Prometheus du HPA (`kube_horizontalpodautoscaler_status_current_replicas`) montraient un comportement oscillatoire : le nombre de pods CartService augmentait rapidement, puis diminuait, puis augmentait à nouveau. Les logs Kubernetes (`kubectl get events`) montraient des cycles rapides de création et destruction de pods.

L'analyse a révélé le scénario suivant. Un pic de trafic faisait monter la CPU des pods CartService au-dessus du seuil HPA (50 pour cent). Le HPA réagissait correctement en augmentant le nombre de réplicas. Les nouveaux pods absorbaient la charge, faisant baisser la CPU moyenne en dessous du seuil. Le HPA, constatant que la CPU moyenne était redevenue basse, réduisait le nombre de réplicas. La destruction des pods entraînait deux conséquences : les connexions gRPC en cours sur ces pods étaient coupées brutalement (provoquant les erreurs 500), et la charge se reportait sur les pods survivants, faisant remonter la CPU et déclenchant un nouveau scale-up. Ce cycle se répétait indéfiniment.

**Analyse de la cause racine.** Trois facteurs ont contribué à cet incident. Le premier est l'absence de fenêtre de stabilisation au scale-down : le HPA réduisait les réplicas dès que la métrique passait sous le seuil, sans attendre de confirmer que la baisse était durable. Le deuxième est la vitesse de scale-down trop agressive : le HPA pouvait détruire un pourcentage élevé de pods en une seule opération. Le troisième est l'absence de mécanisme de terminaison gracieuse : les pods CartService étaient détruits immédiatement sans laisser le temps aux connexions gRPC en cours de se terminer, provoquant des erreurs de connexion côté client.

**Impact.** Récurrent et significatif. Chaque campagne de test au-dessus de 30 000 VUs produisait un taux d'erreur de 3 à 8 pour cent sur le CartService, dépassant le seuil de 1 pour cent défini dans le cahier des charges. L'alerte PrometheusRule `HighErrorRate` se déclenchait de manière répétée.

**Résolution.** La résolution a nécessité trois modifications complémentaires.

Le `stabilizationWindowSeconds` du comportement de scale-down du HPA a été porté à 600 secondes. Cela signifie que le HPA attend que la métrique soit restée en dessous du seuil pendant dix minutes consécutives avant de réduire les réplicas. Ce délai empêche le HPA de réagir aux variations de courte durée inhérentes au trafic web.

La vitesse de scale-down a été limitée à dix pour cent des pods actifs toutes les deux minutes, avec une politique `selectPolicy: Min` qui choisit la réduction la plus conservatrice possible. Même lorsque le HPA décide de réduire, il ne détruit qu'un petit nombre de pods à la fois.

Un hook `preStop` a été ajouté à la spécification des conteneurs CartService, exécutant un `sleep 15` avant l'arrêt du conteneur. Ce délai de quinze secondes laisse le temps au Service Kubernetes de retirer le pod de son pool d'endpoints (opération qui prend quelques secondes), puis aux connexions gRPC en cours de se terminer. Le `terminationGracePeriodSeconds` a été porté à 120 secondes pour couvrir ce mécanisme et les connexions longues.

**Mesures correctives.** La même politique de scale-down conservateur (stabilisation 600 secondes, réduction 5 à 10 pour cent max) a été appliquée à tous les HPAs du projet (Nginx Cache Proxy, frontend, CartService). Les politiques de scale-up n'ont pas été modifiées car la vitesse de réaction à la hausse reste critique pour absorber les pics de trafic.

**Enseignement.** Le comportement par défaut du HPA Kubernetes est conçu pour optimiser le coût (réduire les pods inutilisés le plus vite possible), pas la stabilité. Pour des charges de production avec du trafic fluctuant, une politique de scaling asymétrique est indispensable : agressif à la montée, conservateur à la descente. Le coût de quelques pods excédentaires pendant dix minutes est négligeable comparé au coût opérationnel et utilisateur des erreurs 500 causées par un scale-down prématuré.

---

## 3. Synthèse des actions correctives

L'ensemble des corrections apportées à la suite de ces incidents se répartit en trois catégories.

Les corrections immédiates (appliquées dans l'heure suivant l'incident) comprennent l'ajout de la permission `sts:TagSession`, le tagging manuel des subnets, la libération des EIPs orphelines, et la création manuelle de l'ALB.

Les corrections pérennes (intégrées dans le code Terraform pour éviter la récurrence) comprennent l'ajout des tags Kubernetes dans le module VPC, la spécification de la StorageClass `ebs-auto` dans le module monitoring, l'augmentation du timeout Helm, le développement complet du module ALB, et la politique de scale-down conservateur sur tous les HPAs.

Les corrections documentaires (visant à transmettre les connaissances) comprennent six ADR (Architecture Decision Records) couvrant les choix de Terragrunt, EKS Auto Mode, VPC 3-tiers, stack monitoring, External Secrets et ALB/WAF, ainsi que les runbooks de déploiement, de réponse aux incidents et de War Room Black Friday.

---

## 4. Conclusion

Au-delà des enseignements spécifiques à chaque incident, trois leçons transversales se dégagent de cette expérience.

La première concerne la maturité des services managés. EKS Auto Mode, bien que puissant, est un service récent dont les prérequis ne sont pas toujours documentés de manière explicite. Quatre des sept incidents (sts:TagSession, tags subnets, StorageClass, timeout Helm) sont directement liés à des comportements spécifiques d'EKS Auto Mode qui diffèrent du mode EKS classique. La documentation communautaire (modules Terraform, charts Helm, tutoriels) n'a pas encore intégré ces spécificités. Dans un contexte de production, ce constat plaiderait pour une approche prudente vis-à-vis des nouvelles fonctionnalités GA : les tester en environnement non-critique avant de les adopter en production.

La deuxième concerne la valeur de l'Infrastructure as Code face aux opérations manuelles. L'incident ALB illustre parfaitement cette tension. La création manuelle a permis de débloquer le projet en quelques heures, mais a introduit une fragilité opérationnelle (IPs de pods en dur dans les Target Groups). Le module Terraform a nécessité plusieurs jours de développement, mais a produit une solution robuste, reproductible et enrichie (WAF). Dans un contexte de production, la tentation de l'opération manuelle "rapide" doit être résistée autant que possible, car la dette technique qu'elle introduit se paie toujours plus cher que le temps investi dans une solution codifiée.

La troisième concerne le dimensionnement du scaling. Les paramètres par défaut de Kubernetes (HPA sans stabilisation, no preStop, timeout Helm de 600 secondes) sont calibrés pour des environnements stables à charge constante. Dès que la charge devient fluctuante, ces paramètres doivent être ajustés empiriquement via des campagnes de tests de charge. L'approche adoptée — tester, observer les métriques, ajuster, retester — est la seule méthode fiable pour calibrer le scaling d'une infrastructure cloud.
