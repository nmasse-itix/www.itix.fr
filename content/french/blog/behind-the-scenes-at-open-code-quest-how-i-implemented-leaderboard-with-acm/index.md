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

Lors du {{< internalLink path="/speaking/red-hat-summit-connect-france-2024/index.md" >}}, j'ai animé un atelier pour les développeurs intitulé "**Open Code Quest**".
Dans cet atelier, les développeurs devaient coder des micro-services en utilisant Quarkus, OpenShift et un service d'Intelligence Artificielle : le modèle Granite d'IBM.
L'atelier était conçu sous la forme d'une compétition de vitesse : les premiers à valider les trois exercices ont reçu une récompense.

J'ai conçu et développé le **Leaderboard** qui affiche la progression des participants et les départage en fonction de leur rapidité.
Facile ?
Pas tant que ça car je me suis imposé une figure de style : utiliser **Prometheus** et **Grafana**.

Suivez-moi dans les coulisse de l'Open Code Quest : comment j'ai implémenté le Leaderboard dans **Red Hat Advanced Cluster Management** !

<!--more-->

Cet article est la suite de {{< internalLink path="/blog/behind-the-scenes-at-open-code-quest-how-i-designed-leaderboard/index.md" >}}.
Si vous ne l'avez pas lu, je vous conseille de le lire avant pour mieux comprendre le contexte.

## Observabilité dans Red Hat Advanced Cluster Management

Maintenant que le principe est validé et que les requêtes ont été mises au point dans Prometheus, il est temps d'implémenter tout ça dans le module **Observabilité** de **Red Hat Advanced Cluster Management**.

Lors de l'Open Code Quest, nous avions à notre disposition 8 clusters :

- 1 cluster **central**
- 1 cluster pour l'intelligence artificielle
- 6 clusters répartis entre les participants (on avait prévu un cluster par table)

**Red Hat Advanced Cluster Management** est installé sur le cluster **central** et à partir de là, il contrôle l'ensemble des clusters.

L'observabilité est un module supplémentaire (dans le sens où il n'est pas installé par défaut) de **Red Hat Advanced Cluster Management** et ce module est basé sur les composants Open Source **Prometheus**, **Thanos** et **Grafana**.

L'architecture du module d'observabilité, tel que décrit [dans la documentation Red Hat Advanced Cluster Management](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.11/html/observability/observing-environments-intro#observing-environments-intro), est la suivante :

{{< attachedFigure src="redhat-acm-observability-architecture.png" title="Architecture logique de l'observabilité dans Red Hat Advanced Cluster Management 2.11 ([source](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.11/html/observability/observing-environments-intro#observing-environments-intro))" >}}

**TODO**

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

### Adaptation des requêtes Prometheus


### Déploiement d'une instance Grafana de développement

Déployer une instance de dev de Grafana.

```sh
# Deploy a Grafana development instance
git clone https://github.com/stolostron/multicluster-observability-operator.git
cd multicluster-observability-operator/tools
./setup-grafana-dev.sh --deploy

# Login on Grafana
GRAFANA_DEV_HOSTNAME="$(oc get route grafana-dev -n open-cluster-management-observability -o jsonpath='{.status.ingress[0].host}')"
echo "Now login to Grafana with your openshift user at https://$GRAFANA_DEV_HOSTNAME"
read -q "?press any key to continue "
./switch-to-grafana-admin.sh "$(oc whoami)"
```

Créer le dashboard "Red Hat Summit Connect 2024"

```sh
./generate-dashboard-configmap-yaml.sh "Red Hat Summit Connect 2024"
./setup-grafana-dev.sh --clean
```

