---
title: "Dans les coulisses de l'Open Code Quest : comment j'ai implémenté le Leaderboard dans Red Hat Advanced Cluster Management"
date: 2024-10-11T00:00:00+02:00
#lastMod: 2024-10-11T00:00:00+02:00
opensource:
- Kubernetes
- Prometheus
- Grafana
topics:
- Observability
# Featured images for Social Media promotion (sorted from by priority)
#images:
#- counting-scheme-with-time.png
resources:
- '*.png'
- '*.svg'
- '*.gif'
---

Après avoir révélé les coulisses de la conception du Leaderboard pour l'atelier "Open Code Quest" lors du {{< internalLink path="/speaking/red-hat-summit-connect-france-2024/index.md" >}}, il est temps de plonger plus en détail dans son implémentation pratique !

Dans cet article, je vais vous guider à travers la configuration de **Red Hat Advanced Cluster Management** ainsi que les différentes adapatations nécessaires pour connecter le *Leaderboard* créé précédemment avec l'infrastructure de l'**Open Code Quest**.

Embarquez avec moi pour cette nouvelle étape, plus technique que la précédente, j'ai dû faire preuve de créativité pour câbler un tableau de bord Grafana très "conceptuel" avec la réalité des clusters OpenShift !

<!--more-->

Cet article est la suite de {{< internalLink path="/blog/behind-the-scenes-at-open-code-quest-how-i-designed-leaderboard/index.md" >}}.
Si vous ne l'avez pas lu, je vous conseille de le lire avant pour mieux comprendre le contexte.

## Requêtes Prometheus

Dans l'article précédent, j'avais évoqué a manière dont ont pouvait détecter les actions d'un utilisateur dans son environnement :

- Si le Pod **hero-database-1** est créé dans le namespace **batman-workshop-prod** alors on sait que l'utilisateur **batman** vient de terminer le déploiement de la base de donnée de l'exercice **hero** dans l'environnement de **prod**.
- Si le Deployment **hero** dans le namespace **batman-workshop-prod** passe à l'état **Available**, alors on sait que l'utilisateur vient de déployer avec succès son micro-service **hero**.
- Si un Pod **batman-hero-run-*\<random>*-resync-pod** dans le namespace **batman-workshop-dev** passe à l'état **Completed**, alors on sait que le dernier pipeline Tekton l'utilisateur vient de terminer avec succès.

Si les trois conditions précédentes sont vraies, on peut en déduire que l'utilisateur a terminé et validé l'exercice **hero**.

La réalité est en fait un peu plus compliquée car entre le *Leaderboard* de l'article précédent, très conceptuel et ces éléments très techniques, il a fallu faire pas mal d'adaptation.

Au final, pour chaque exercice j'ai eu à implémenter trois requêtes Prometheus pour détecter les trois conditions ci-dessus.
Fort heureusement, les trois exercices sont sur le même modèle donc le jeu de requêtes est très similaire pour les trois exercices.

### Détection du micro-service Quarkus

Je détecte le déploiement du micro-service Quarkus **hero** dans l'environnement de **dev** à l'aide de la requête suivante que je persiste sous la forme d'une *recording rule* nommée **opencodequest_hero_quarkus_pod:dev**.

```
clamp_max(
  sum(
    label_replace(kube_deployment_status_condition{namespace=~"[a-zA-Z0-9]+-workshop-dev",deployment="hero",condition="Available",status="true"}, "user", "$1", "namespace", "([a-zA-Z0-9]+)-workshop-dev")
  ) by (user),
1)
or
clamp(
  sum(
    label_replace(kube_namespace_status_phase{namespace=~"[a-zA-Z0-9]+-workshop-(dev|preprod|prod)",phase="Active"}, "user", "$1", "namespace", "([a-zA-Z0-9]+)-workshop-(dev|preprod|prod)")
  ) by (user),
0, 0)
```

Cette requête est en deux parties.
La première partie fonctionne de la manière suivante :

- `kube_deployment_status_condition{namespace=~"[a-zA-Z0-9]+-workshop-dev",deployment="hero",condition="Available",status="true"}` retourne le nombre de **Deployment** kubernetes ayant le nom **hero**, dans un namespace se terminant par **-workshop-dev** et étant dans un état **Available**.
- `label_replace(TIMESERIE, "user", "$1", "namespace", "([a-zA-Z0-9]+)-workshop-dev")` extrait le nom de l'utilisateur depuis le *label* **namespace** à l'aide d'une expression régulière et le stocke dans un *label* **user**.
- `sum(TIMESERIE) by (user)` supprime toutes les étiquettes sauf **user** (j'aurais pu utiliser les fonctions `min`, `max`, etc, ça marche aussi).
- `clamp_max(TIMESERIE, 1)` plafonne le résultat à 1 pour garantir que le résultat est binaire.

Cette première partie retourne l'état du micro-service Quarkus **dès lors que le Deployment kubernetes existe**.
Tant que le Deployment kubernetes n'existe pas, aucune donnée n'est retournée par cette partie de la requête.

Et la deuxième partie de la requête est là pour palier à ce problème :

- `kube_namespace_status_phase{namespace=~"[a-zA-Z0-9]+-workshop-(dev|preprod|prod)",phase="Active"}` retourne les namespaces des participants étant dans un état actif (ils le sont tous durant la durée de l'atelier).
- `label_replace(TIMESERIE, "user", "$1", "namespace", "([a-zA-Z0-9]+)-workshop-(dev|preprod|prod)")` extrait le nom de l'utilisateur depuis le *label* **namespace** à l'aide d'une expression régulière et le stocke dans un *label* **user**.
- `sum(TIMESERIE) by (user)` supprime toutes les étiquettes sauf **user** (j'aurais pu utiliser les fonctions `min`, `max`, etc, ça marche aussi).
- `clamp(TIMESERIE, 0, 0)` force toutes les valeurs de la *time serie* à 0.

Cette deuxième partie permet d'avoir une valeur par défaut (0) pour l'ensemble des participants, même lorsque les Deployment kubernetes ne sont pas encore présents.

Le mot clé `or` au milieu des deux requêtes permet de fusionner les deux parties, la première ayant la priorité sur la seconde.

Les micro-services **villain** et **fight**, ainsi que les environnements de **preprod** et **prod** sont sur le même principe.
Au total, ce sont 9 *time series* qui sont enregistrées sous la forme de *recording rules* :

- `opencodequest_hero_quarkus_pod:dev`
- `opencodequest_hero_quarkus_pod:preprod`
- `opencodequest_hero_quarkus_pod:prod`
- `opencodequest_villain_quarkus_pod:dev`
- `opencodequest_villain_quarkus_pod:preprod`
- `opencodequest_villain_quarkus_pod:prod`
- `opencodequest_fight_quarkus_pod:dev`
- `opencodequest_fight_quarkus_pod:preprod`
- `opencodequest_fight_quarkus_pod:prod`

### Détection de la base de données

Je détecte le déploiement de la base de données **hero** dans l'environnement de **dev** à l'aide de la requête suivante que je persiste sous la forme d'une *recording rule* nommée **opencodequest_hero_db_pod:dev**.

```
clamp_max(
  sum(
    label_replace(kube_pod_status_phase{namespace=~"[a-zA-Z0-9]+-workshop-dev",pod="hero-database-1",phase="Running"}, "user", "$1", "namespace", "([a-zA-Z0-9]+)-workshop-dev")
  ) by (user),
1)
or
clamp(
  sum(
    label_replace(kube_namespace_status_phase{namespace=~".*-workshop-(dev|preprod|prod)",phase="Active"}, "user", "$1", "namespace", "(.*)-workshop-(dev|preprod|prod)")
  ) by (user),
0, 0)
```

La requête est très similaire à la précédente, excepté que je me base sur l'état du **Pod** nommé **hero-database-1**.
C'est pour cette raison que j'utilise la timeserie **kube_pod_status_phase**.

Le micro-service **villain**, ainsi que les environnements de **preprod** et **prod** sont sur le même principe.
Au total, ce sont 6 *time series* qui sont enregistrées sous la forme de *recording rules* (**fight** n'a pas de base de données) :

- `opencodequest_hero_db_pod:dev`
- `opencodequest_hero_db_pod:preprod`
- `opencodequest_hero_db_pod:prod`
- `opencodequest_villain_db_pod:dev`
- `opencodequest_villain_db_pod:preprod`
- `opencodequest_villain_db_pod:prod`

Les *recording rules* de l'environnement **prod** sont un peu différentes car dans cet environnement la base de données est mutualisée entre tous les participants et déployée avant le démarrage de l'atelier avec le reste de l'infrastructure.
Par conséquent, je force la valeur des *time series* `opencodequest_hero_db_pod:prod` et `opencodequest_villain_db_pod:prod` à 1 en utilisant une variante de la deuxième partie de la requête expliquée plus haut :

```
clamp(
  sum(
    label_replace(kube_namespace_status_phase{namespace=~".*-workshop-(dev|preprod|prod)",phase="Active"}, "user", "$1", "namespace", "(.*)-workshop-(dev|preprod|prod)")
  ) by (user),
1, 1)
```

### Détection de la fin du Pipeline Tekton

Détecter la fin du pipeline Tekton m'a demandé plus de travail car il n'existe pas de métrique standard pour connaître l'état d'un Pipeline.
Je me suis donc basé sur la présence d'un pod `<user>-hero-run-<random>-resync-pod` dans l'environnement **dev** de l'utilisateur.
Ce Pod correspond à la dernière étape du Pipeline Tekton.
Donc si ce pod est dans un état **Completed**, c'est que le Pipeline s'est terminé avec succès.

Je détecte l'état du Pipeline Tekton **hero** dans l'environnement de **dev** à l'aide de la requête suivante que je persiste sous la forme d'une *recording rule* nommée **opencodequest_hero_pipeline**.

```
clamp_max(
  sum(
    label_replace(kube_pod_status_phase{namespace=~"[a-zA-Z0-9]+-workshop-dev",pod=~"[a-zA-Z0-9]+-hero-run-.*-resync-pod",phase="Succeeded"}, "user", "$1", "namespace", "([a-zA-Z0-9]+)-workshop-dev")
  ) by (user),
1)
or
clamp(
  sum(
    label_replace(kube_namespace_status_phase{namespace=~".*-workshop-(dev|preprod|prod)",phase="Active"}, "user", "$1", "namespace", "(.*)-workshop-(dev|preprod|prod)")
  ) by (user),
0, 0)
```

La requête est très similaire à la précédente, excepté que l'état attendu du Pod est différent (**Completed**) et le nom du Pod est différent.

Les micro-services **villain** et **fight** sont sur le même principe.
Au total, ce sont 3 *time series* qui sont enregistrées sous la forme de *recording rules* (les pipelines n'existent que dans l'environnement **dev**) :

- `opencodequest_hero_pipeline`
- `opencodequest_villain_pipeline`
- `opencodequest_fight_pipeline`

### Détection de la fin de l'exercice

Pour détecter la fin de l'exercice **hero** dans l'environnement de **dev**, je combine le résultat des trois requêtes précédentes à l'aide de la requète suivante que je persiste sous la forme d'une *recording rule* nommée **opencodequest_leaderboard_hero:dev**.

```
max(
  (opencodequest_hero_quarkus_pod:dev + opencodequest_hero_db_pod:dev + opencodequest_hero_pipeline) == bool 3
) by (user, cluster)
```

Cette requête fonctionne de la manière suivante :

- `(opencodequest_hero_quarkus_pod:dev + opencodequest_hero_db_pod:dev + opencodequest_hero_pipeline) == bool 3` retourne 1 quand les trois composantes de l'exercice sont validées, 0 sinon.
  L'opérateur **bool** est important car sans lui, la requête ne retournerait aucun résultat tant que les trois composantes de l'exercice ne sont pas validées.
- `max(TIMESERIE) by (user, cluster)` élimine tous les *labels* sauf **cluster** et **user**.
  Ici, l'utilisation de la fonction `max` est intéressante pour conserver le niveau maximum de complétude de l'exercice si par exemple l'utilisateur a commencé l'exercice sur un cluster et l'a refait et terminé sur un autre cluster.
  C'est un cas qui ne doit pas arriver mais dans le doute...

L'exercice **fight** n'a que deux composantes car il n'a pas de base de données.
Les requêtes le concernant seront donc plus simples :

```
max(
  (opencodequest_fight_quarkus_pod:prod + opencodequest_fight_pipeline) == bool 2
) by (user, cluster)
```

C'est un total de 9 *recording rules* qui enregistrent l'état de complétude des 3 exercices au travers des 3 environnements des participants.

- `opencodequest_leaderboard_hero:dev`
- `opencodequest_leaderboard_hero:preprod`
- `opencodequest_leaderboard_hero:prod`
- `opencodequest_leaderboard_villain:dev`
- `opencodequest_leaderboard_villain:preprod`
- `opencodequest_leaderboard_villain:prod`
- `opencodequest_leaderboard_fight:dev`
- `opencodequest_leaderboard_fight:preprod`
- `opencodequest_leaderboard_fight:prod`

Et avec ces dernières *recording rules* nous venons de raccorder le Leaderboard avec les environnements OpenShift utilisés pour l'Open Code Quest.
Voyons maintenant comment l'observabilité a été implémentée dans **Red Hat Advanced Cluster Management** !

## Observabilité dans Red Hat Advanced Cluster Management

Lors de l'Open Code Quest, nous avions à notre disposition 8 clusters :

- 1 cluster **central**
- 1 cluster pour l'intelligence artificielle
- 6 clusters répartis entre les participants (on avait prévu un cluster par table)

**Red Hat Advanced Cluster Management** est installé sur le cluster **central** et à partir de là, il contrôle l'ensemble des clusters.

L'observabilité est un module supplémentaire (dans le sens où il n'est pas installé par défaut) de **Red Hat Advanced Cluster Management** et ce module est basé sur les composants Open Source **Prometheus**, **Thanos** et **Grafana**.

Le schéma suivant présente l'architecture du module d'observabilité dans **Red Hat Advanced Cluster Management**.
Je l'ai créé en observant les relations entre les composants à partir d'une installation d'ACM en version 2.11.

{{< attachedFigure src="redhat-acm-observability-architecture.svg" title="Architecture logique de l'observabilité dans Red Hat Advanced Cluster Management 2.11" >}}

Les composants déployés sur le cluster central sont en **vert**, ceux déployés sur les clusters managés sont en **bleu** et les éléments de configuration en **gris**.
J'ai aussi illustré les deux endroits possibles pour le calcul des *recording rules*, en **jaune**.

On notera que les ConfigMap sur les clusters managés peuvent être déployées automatiquement depuis le cluster **central** via un **ManifestWork**.

### Implémentation des *Recording rules*

Les recording rules peuvent être calculées à deux moments différents :

- Dans chaque cluster managé, avant envoi sur le cluster central.
- Dans le cluster central, après réception.

Mais il y a une petite subtilité : ce choix est vrai pour les métriques standard d'OpenShift.

Les *recording rules* faisant appel à des métriques *custom* (ie. le **User Workload Monitoring**) ne sont calculées **qu'après réception sur le cluster central**.
Il n'est pas possible de les calculer avant envoi sur le cluster central.
On peut spécifier des métriques *custom* à envoyer telles quelles.

Elles ne se configurent pas non plus au même endroit en fonction de si c'est une métrique *custom* ou une métrique standard et de si c'est fait avant ou après envoi.

Pour vous aider, j'ai fait un tableau récapitulatif :

| Type de métrique     | Calcul de la *recording rule*     | Emplacement de la configuration                                                                        | Nom de la ConfigMap                      | Clé                     |
| -------------------- | --------------------------------- | ------------------------------------------------------------------------------------------------------ | ---------------------------------------- | ----------------------- |
| standard             | avant envoi                       | *namespace* `open-cluster-management-observability` sur le cluster **central** ou les clusters managés | `observability-metrics-custom-allowlist` | `metrics_list.yaml`     |
| *custom*             | **pas de calcul**, envoi tel quel | *namespace* `open-cluster-management-observability` sur le cluster **central** ou les clusters managés | `observability-metrics-custom-allowlist` | `uwl_metrics_list.yaml` |
| standard ou *custom* | à réception                       | *namespace* `open-cluster-management-observability` sur le cluster **central**                         | `thanos-ruler-custom-rules`              | `custom_rules.yaml`     |

#### Calcul des *Recording Rules* avant envoi

Pour l'envoi des métriques et le calcul des *recording rules* **avant envoi** sur le cluster **central**, ça se configure dans le *namespace* `open-cluster-management-observability` sur le cluster **central** via une ConfigMap :

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: observability-metrics-custom-allowlist
  namespace: open-cluster-management-observability
data:
  uwl_metrics_list.yaml: |
    names:
    - fights_total
  metrics_list.yaml: |
    names:
    - kube_deployment_status_replicas_ready
    - kube_pod_status_phase
    - kube_namespace_status_phase
    rules:
    - record: opencodequest_hero_quarkus_pod:dev
      expr: kube_deployment_status_condition{namespace=~\"[a-zA-Z0-9]+-workshop-dev\",deployment=\"hero\",condition=\"Available\",status=\"true\"}
```

La configuration ci-dessus permet de :

- Envoyer la métrique *custom* `fights_total` telle quelle.
- Envoyer les métriques standard `kube_deployment_status_replicas_ready`, `kube_pod_status_phase` et `kube_namespace_status_phase` telles quelles.
- Créer une métrique `opencodequest_hero_quarkus_pod:dev` à partir de la requête Prometheus `kube_deployment_status_condition{...}` et envoyer le résultat.

Lorsque cette ConfigMap est créée sur le cluster **central**, elle est automatiquement répliquée sur tous les clusters managés.
D'après la documentation, il est aussi possible de la créer dans chaque cluster managé pour personnaliser la configuration par cluster.

#### Calcul des *Recording Rules* à réception

Pour le calcul des *recording rules* **à réception** sur le cluster **central**, ça se configure aussi dans le *namespace* `open-cluster-management-observability` sur le cluster **central** mais via une autre ConfigMap :

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: thanos-ruler-custom-rules
  namespace: open-cluster-management-observability
data:
  custom_rules.yaml: |
    groups:
      - name: opencodequest
        rules:
        - record: opencodequest_hero_quarkus_pod:dev
          expr: kube_deployment_status_condition{namespace=~"[a-zA-Z0-9]+-workshop-dev",deployment="hero",condition="Available",status="true"}
```

On notera que les syntaxes des deux ConfigMap ne sont pas identiques.

- Dans la ConfigMap `observability-metrics-custom-allowlist`, les *double quotes* doivent être échappées, par un *backslash*.
  Ce n'est pas le cas dans l'autre ConfigMap.
- La syntaxe de la ConfigMap `thanos-ruler-custom-rules` permet de spécifier des groupes de *recording rules* alors que l'autre ConfigMap ne permet pas de le faire.

Note: les noms des métriques dans les exemples ci-dessus sont plus ou moins fictifs.
Ce ne sont pas ces configurations que j'ai utilisées au final.

#### Choix d'implémentation

J'ai choisi de calculer sous la forme de *recording rules* **dans les clusters managés**, les trois composantes permettant de valider la complétude d'un exercice, à savoir :

- Le **Deployment** du micro-service Quarkus est dans l'état **Available**.
- Le **Pod** de la base de donnée, lorsqu'il y en a une, est présent et dans un état **Ready**.
- Le Pipeline Tekton du micro-service s'est terminé avec succès.
  Comme il n'existe pas de métrique standard pour les Pipelines Tekton, la *recording rule* détecte la présence du **Pod** correspondant à la dernière étape du Pipeline et vérifie qu'il est dans un état **Completed**.

J'ai créé ces *recording rules* pour les environnements de **dev**, **preprod** et **prod** des participants.
Ainsi, si le jour de l'Open Code Quest on avait eu un problème généralisé dans l'environnement **prod**, on aurait pu rapidement basculer le calcul des points sur un autre environnement en amont.

Je vois un avantage à cette approche : calculer les trois composantes de chaque exercice dans les clusters managés permet de ne pas remonter trop de métriques au niveau du cluster **central**.

À l'inverse, j'ai dû calculer sous la forme de *recording rules* au niveau du **cluster central** les requêtes Prometheus du Leaderboard décrites en première partie de cet article.
Effectivement, je n'ai pas trop eu le choix : j'avais besoin d'avoir plusieurs groupes de *recording rules* et cette fonction n'est disponible que dans la ConfigMap qui configure les *recording rules* du cluster **central**.

Vous pouvez retrouver l'ensemble des *recording rules* utilisées pour l'Open Code Quest dans le dossier [acm](https://github.com/nmasse-itix/opencodequest-leaderboard/tree/main/acm).

### Mise en place de l'observabilité

Le déployement du module d'observabilité sur le cluster **central**, se fait très simplement en suivant [la documentation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.11/html/observability/observing-environments-intro#enabling-observability-service) :

- Créer le namespace `open-cluster-management-observability`.
- Créer le *pull secret* permettant de télécharger les images sur **registry.redhat.io**.
- Créer un *bucket* S3.
- Créer la *Custom Resource Definition* `MultiClusterObservability`.

Pour effectuer ces opérations, j'ai utiliser les commandes suivantes :

```sh
AWS_ACCESS_KEY_ID="REDACTED"
AWS_SECRET_ACCESS_KEY="REDACTED"
S3_BUCKET_NAME="REDACTED"
AWS_REGION="eu-west-3"

# Create the open-cluster-management-observability namespace
oc create namespace open-cluster-management-observability

# Copy the pull secret from the openshift namespace
DOCKER_CONFIG_JSON=`oc extract secret/pull-secret -n openshift-config --to=-`
echo $DOCKER_CONFIG_JSON
oc create secret generic multiclusterhub-operator-pull-secret \  
   -n open-cluster-management-observability \  
   --from-literal=.dockerconfigjson="$DOCKER_CONFIG_JSON" \  
   --type=kubernetes.io/dockerconfigjson

# Create an S3 bucket
aws s3api create-bucket --bucket "$S3_BUCKET_NAME" --create-bucket-configuration "LocationConstraint=$AWS_REGION" --region "$AWS_REGION" --output json

# Deploy the observability add-on
oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: thanos-object-storage
  namespace: open-cluster-management-observability
type: Opaque
stringData:
  thanos.yaml: |
    type: s3
    config:
      bucket: $S3_BUCKET_NAME
      endpoint: s3.$AWS_REGION.amazonaws.com
      insecure: false
      access_key: $AWS_ACCESS_KEY_ID
      secret_key: $AWS_SECRET_ACCESS_KEY
EOF
oc apply -f - <<EOF
apiVersion: observability.open-cluster-management.io/v1beta2
kind: MultiClusterObservability
metadata:
  name: observability
  namespace: open-cluster-management-observability
spec:
  observabilityAddonSpec: {}
  storageConfig:
    metricObjectStorage:
      name: thanos-object-storage
      key: thanos.yaml
EOF
```

Après installation du module d'observabilité, les clusters managés sont automatiquement configurés pour remonter les métriques Prometheus les plus importantes sur le cluster **central**.

L'atelier **Open Code Quest** tire parti de métriques *custom* que j'utilise dans le Leaderboard pour savoir quels sont les participants qui ont fait marcher leurs micro-services.
Pour collecter ces métriques, j'active la fonction **User Workload Monitoring** d'**OpenShift** dans chaque cluster managé.

```sh
oc -n openshift-monitoring get configmap cluster-monitoring-config -o yaml | sed -r 's/(\senableUserWorkload:\s).*/\1true/' | oc apply -f -
```

### Déploiement d'une instance Grafana de développement

Une instance Grafana est déployée automatiquement avec le module d'observabilité mais cette instance est en lecture seule : on peut consulter les tableaux de bord standard mais pas en mettre au point de nouveaux.
Pour en créer de nouveaux, il faut déployer en parallèle une instance de développement de Grafana.

```sh
git clone https://github.com/stolostron/multicluster-observability-operator.git
cd multicluster-observability-operator/tools
./setup-grafana-dev.sh --deploy
```

Une fois l'instance déployée, il faut s'y connecter avec n'importe quel utilisateur OpenShift et donner les privilèges **administrateur** à cet utilisateur.

```sh
GRAFANA_DEV_HOSTNAME="$(oc get route grafana-dev -n open-cluster-management-observability -o jsonpath='{.status.ingress[0].host}')"
echo "Now login to Grafana with your openshift user at https://$GRAFANA_DEV_HOSTNAME"
read -q "?press any key to continue "
./switch-to-grafana-admin.sh "$(oc whoami)"
```

Puis, créer le tableau de bord "Red Hat Summit Connect 2024", comme expliqué dans l'article {{< internalLink path="/blog/behind-the-scenes-at-open-code-quest-how-i-designed-leaderboard/index.md" >}}.

Et enfin, exporter le tableau de bord sous la forme d'une ConfigMap.

```sh
./generate-dashboard-configmap-yaml.sh "Red Hat Summit Connect 2024"
```

Un fichier `red-hat-summit-connect-2024.yaml` est créé.
Il suffit de l'appliquer sur le cluster **central** pour que le tableau de bord apparaisse dans l'instance Grafana de production.

```sh
oc apply -f red-hat-summit-connect-2024.yaml
```

## Conclusion

Pour conclure, l'implémentation du Leaderboard dans Red Hat Advanced Cluster Management m'a permis de mieux comprendre le fonctionnement de l'observabilité, en particulier les *recording rules*.
Au final, j'ai réussi à mettre en place un tableau de bord qui suit en temps réel l'avancée des participants.

Retrouvez l'ensemble des *recording rules* utilisées pour l'Open Code Quest dans le dossier [acm](https://github.com/nmasse-itix/opencodequest-leaderboard/tree/main/acm) de l'entrepôt Git.
