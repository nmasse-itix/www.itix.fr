---
title: "Behind the scenes at Open Code Quest: how I implemented the Leaderboard in Red Hat Advanced Cluster Management"
date: 2024-11-05T00:00:00+02:00
lastMod: 2024-11-18T00:00:00+02:00
opensource:
- Kubernetes
- Prometheus
- Grafana
topics:
- Observability
# Featured images for Social Media promotion (sorted from by priority)
images:
- redhat-acm-observability-architecture.png
resources:
- '*.png'
- '*.svg'
- '*.gif'
---

After revealing the behind-the-scenes design of the Leaderboard for the "Open Code Quest" workshop during the {{< internalLink path="/speaking/red-hat-summit-connect-france-2024/index.md" >}}, it's time to delve deeper into its practical implementation!

In this article, I'm going to take you through the configuration of **Red Hat Advanced Cluster Management** as well as the various adaptations needed to connect the *Leaderboard* created earlier with the **Open Code Quest** infrastructure.

Come on board with me for this new stage, which is more technical than the previous one, as I had to get creative to wire up a very "conceptual" Grafana dashboard with the reality of OpenShift clusters!

<!--more-->

This article follows on from {{< internalLink path="/blog/behind-the-scenes-at-open-code-quest-how-i-designed-leaderboard/index.md" >}}.
If you haven't read it yet, I advise you to read it first to understand the context better.

## Prometheus queries

In the previous article, I discussed how we could detect the actions of a user in his environment:

- If the **hero-database-1** Pod is created in the **batman-workshop-prod** namespace, then we know that the **batman** user has just finished deploying the **hero** exercise database in the **prod** environment.
- If the Deployment **hero** in the **batman-workshop-prod** namespace changes to the **Available** state, then we know that the **batman** user has successfully deployed his **hero** microservice.
- If a **batman-hero-run-*\<random>*-resync-pod** Pod in the **batman-workshop-dev** namespace changes to the **Completed** state, then we know that the user's last Tekton pipeline has been successfully completed.

If the three previous conditions are true, we can deduce that the user has completed and validated the **hero** exercise.

The reality is in fact a little more complicated, because between the very conceptual *Leaderboard* of the previous article and these very technical elements, it was necessary to make quite a few adaptations.

In the end, for each exercise I had to implement three Prometheus queries to detect the three conditions above.
Fortunately, all three exercises are based on the same model, so the set of queries is very similar for all three exercises.

### Detecting the Quarkus micro-service

I detect the deployment of the Quarkus microservice **hero** in the environment **dev** using the following query, which I persist as a recording rule named **opencodequest_hero_quarkus_pod:dev**.

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

This query is in two parts.
The first part works as follows:

- `kube_deployment_status_condition{namespace=~"[a-zA-Z0-9]+-workshop-dev",deployment="hero",condition="Available",status="true"}` returns the number of kubernetes **Deployment** with the name **hero**, in a namespace ending in **-workshop-dev** and being in a **Available** state.
- `label_replace(TIMESERIE, "user", "$1", "namespace", "([a-zA-Z0-9]+)-workshop-dev")` extracts the user's name from the **namespace** label using a regular expression and stores it in a **user** label.
- `sum(TIMESERIE) by (user)` deletes all labels except **user** (I could have used `min`, `max`, etc, that works too).
- `clamp_max(TIMESERIE, 1)` caps the result at 1 to ensure that the result is binary.
This first part returns the state of the Quarkus microservice **as soon as the kubernetes Deployment exists**.
As long as kubernetes Deployment does not exist, no data is returned by this part of the query.

The second part of the query addresses this problem:

- `kube_namespace_status_phase{namespace=~"[a-zA-Z0-9]+-workshop-(dev|preprod|prod)",phase="Active"}` returns the namespaces of participants who are in an active state (they all are during the workshop).
- `label_replace(TIMESERIE, "user", "$1", "namespace", "([a-zA-Z0-9]+)-workshop-(dev|preprod|prod)")` extracts the name of the user from the **namespace** label using a regular expression and stores it in a **user** label.
- `sum(TIMESERIE) by (user)` deletes all labels except **user** (I could have used `min`, `max`, etc, that works too).
- `clamp(TIMESERIES, 0, 0)` forces all values in the time serie to 0.

This second part makes it possible to have a default value (0) for all participants, even when Kubernetes Deployment is not yet present.

The `or` keyword in the middle of the two queries merges the two parts, with the first taking precedence over the second.

The **villain** and **fight** microservices, as well as the **preprod** and **prod** environments, are based on the same principle.

In total, 9 time series are recorded in the form of recording rules:

- `opencodequest_hero_quarkus_pod:dev`
- `opencodequest_hero_quarkus_pod:preprod`
- `opencodequest_hero_quarkus_pod:prod`
- `opencodequest_villain_quarkus_pod:dev`
- `opencodequest_villain_quarkus_pod:preprod`
- `opencodequest_villain_quarkus_pod:prod`
- `opencodequest_fight_quarkus_pod:dev`
- `opencodequest_fight_quarkus_pod:preprod`
- `opencodequest_fight_quarkus_pod:prod`

### Detecting the database

I detect the deployment of the **hero** database in the **dev** environment using the following query, which I persist as a recording rule named **opencodequest_hero_db_pod:dev**.

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

The query is very similar to the previous one, except that I'm basing it on the state of the **Pod** named **hero-database-1**.
This is why I'm using the **kube_pod_status_phase** timeseries.

The **villain** microservice and the **preprod** and **prod** environments are based on the same principle.
In total, 6 time series are recorded in the form of recording rules (**fight** has no database):

- `opencodequest_hero_db_pod:dev`
- `opencodequest_hero_db_pod:preprod`
- `opencodequest_hero_db_pod:prod`
- `opencodequest_villain_db_pod:dev`
- `opencodequest_villain_db_pod:preprod`
- `opencodequest_villain_db_pod:prod`

The recording rules for the **prod** environment are a little different because in this environment the database is shared between all the participants and deployed before the workshop starts with the rest of the infrastructure.
Consequently, I force the value of the time series `opencodequest_hero_db_pod:prod` and `opencodequest_villain_db_pod:prod` to 1 using a variant of the second part of the query explained above:

```
clamp(
  sum(
    label_replace(kube_namespace_status_phase{namespace=~".*-workshop-(dev|preprod|prod)",phase="Active"}, "user", "$1", "namespace", "(.*)-workshop-(dev|preprod|prod)")
  ) by (user),
1, 1)
```

### Detecting the end of the Tekton Pipeline

Detecting the end of the Tekton pipeline required more work because there is no standard metric for knowing the state of a pipeline.
I therefore relied on the presence of a `<user>-hero-run-<random>-resync-pod` pod in the user's **dev** environment.
This pod corresponds to the last stage of the Tekton Pipeline.
So if this pod is in a **Completed** state, it means that the Pipeline has completed successfully.

I detect the state of the Tekton Pipeline **hero** in the **dev** environment using the following query, which I persist in the form of a recording rule called **opencodequest_hero_pipeline**.

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

The query is very similar to the previous one, except that the expected state of the Pod is different (**Completed**) and the name of the Pod is different.

The **villain** and **fight** microservices are based on the same principle.
In total, 3 time series are recorded in the form of recording rules (pipelines only exist in the **dev** environment):

- `opencodequest_hero_pipeline`
- `opencodequest_villain_pipeline`
- `opencodequest_fight_pipeline`

### Detecting the end of the exercise

To detect the end of the **hero** exercise in the **dev** environment, I combine the results of the three previous queries using the following query, which I persist in the form of a recording rule called **opencodequest_leaderboard_hero:dev**.

```
max(
  (opencodequest_hero_quarkus_pod:dev + opencodequest_hero_db_pod:dev + opencodequest_hero_pipeline) == bool 3
) by (user, cluster)
```

This query works as follows:

- `(opencodequest_hero_quarkus_pod:dev + opencodequest_hero_db_pod:dev + opencodequest_hero_pipeline) == bool 3` returns 1 when all three components of the exercise are validated, 0 otherwise.
  The **bool** operator is important because without it, the query would not return any results until all three components of the exercise have been validated.
- `max(TIMESERIE) by (user, cluster)` eliminates all labels except **cluster** and **user**.
  Here, the use of the `max` function is useful for preserving the maximum level of completeness of the exercise if, for example, the user started the exercise on one cluster and then finished it on another cluster.
  This shouldn't happen, but if in doubt...

The **fight** exercise only has two components because it doesn't have a database.
The queries concerning it will therefore be simpler:

```
max(
  (opencodequest_fight_quarkus_pod:prod + opencodequest_fight_pipeline) == bool 2
) by (user, cluster)
```

There are a total of 9 *recording rules* which record the state of completion of the 3 exercises across the 3 environments of the participants.

- `opencodequest_leaderboard_hero:dev`
- `opencodequest_leaderboard_hero:preprod`
- `opencodequest_leaderboard_hero:prod`
- `opencodequest_leaderboard_villain:dev`
- `opencodequest_leaderboard_villain:preprod`
- `opencodequest_leaderboard_villain:prod`
- `opencodequest_leaderboard_fight:dev`
- `opencodequest_leaderboard_fight:preprod`
- `opencodequest_leaderboard_fight:prod`

And with these last recording rules we've just connected the Leaderboard with the OpenShift environments used for the **Open Code Quest**.
Now let's see how observability has been implemented in **Red Hat Advanced Cluster Management**!

## Observability in Red Hat Advanced Cluster Management

During the Open Code Quest, we had 8 clusters at our disposal:

- 1 **central** cluster
- 1 cluster for artificial intelligence
- 6 clusters distributed among the participants (we had planned one cluster per table)

**Red Hat Advanced Cluster Management** is installed on the **central** cluster and from there it controls all the clusters.

Observability is an additional module (in the sense that it is not installed by default) of **Red Hat Advanced Cluster Management** and this module is based on the Open Source components **Prometheus**, **Thanos** and **Grafana**.

The following diagram shows the architecture of the observability module in **Red Hat Advanced Cluster Management**.
I created it by observing the relationships between the components from an installation of ACM version 2.11.

{{< attachedFigure src="redhat-acm-observability-architecture.svg" title="Logical architecture of observability in Red Hat Advanced Cluster Management 2.11" >}}

The components deployed on the central cluster are in **green**, those deployed on the managed clusters are in **blue** and the configuration items are in **grey**.
I've also illustrated the two possible places for calculating *recording rules*, in **yellow**.

Note that ConfigMaps on managed clusters can be deployed automatically from the **central** cluster via a **ManifestWork**.

### Implementation of the recording rules

Recording rules can be calculated at two different times:

- In each managed cluster, before sending to the central cluster.
- In the central cluster, after reception.

But there's a little subtlety: this choice is true for standard OpenShift metrics.

The recording rules using *custom* metrics (i.e. **User Workload Monitoring**) are calculated **only after reception on the central cluster**.
It is not possible to calculate them before sending them to the central cluster.
You can only specify *custom* metrics to be sent as-is.

They are not configured in the same place either, depending on whether it's a *custom* metric or a standard metric and whether it's done before or after sending.
To help you, I've put together a summary table:


| Type of metric       | Computation of the recording rule     | Location of the configuration                                                                        | Name of the ConfigMap                      | Key                     |
| -------------------- | --------------------------------- | ------------------------------------------------------------------------------------------------------ | ---------------------------------------- | ----------------------- |
| standard             | before sending                       | `open-cluster-management-observability` namespace on the **central** cluster or managed clusters | `observability-metrics-custom-allowlist` | `metrics_list.yaml`     |
| custom             | **no computation**, sent as-is | `open-cluster-management-observability` namespace on the **central** cluster or managed clusters | `observability-metrics-custom-allowlist` | `uwl_metrics_list.yaml` |
| standard or custom | on arrival                       | `open-cluster-management-observability` namespace on the **central** cluster                        | `thanos-ruler-custom-rules`              | `custom_rules.yaml`     |

#### Computing Recording Rules before sending

To send metrics and compute recording rules **before sending** to the **central** cluster, this is configured in the `open-cluster-management-observability` namespace on the **central** cluster via a ConfigMap :

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

The configuration above allows you to :

- Send the `fights_total` custom metric as is.
- Send the standard `kube_deployment_status_replicas_ready`, `kube_pod_status_phase` and `kube_namespace_status_phase` metrics as is.
- Create an `opencodequest_hero_quarkus_pod:dev` metric from the Prometheus query `kube_deployment_status_condition{...}` and send the result.
When this ConfigMap is created on the **central** cluster, it is automatically replicated to all managed clusters.
According to the documentation, it is also possible to create it in each managed cluster to customise the configuration per cluster.

#### Computing Recording Rules on arrival

For the computation of recording rules **on arrival** on the **central** cluster, this is also configured in the `open-cluster-management-observability` namespace on the **central** cluster, but via another ConfigMap:

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

Note that the syntax of the two ConfigMaps is not identical.

- In the `observability-metrics-custom-allowlist` ConfigMap, *double quotes* must be escaped, using a *backslash*.
  This is not the case in the other ConfigMap.
- The syntax of the `thanos-ruler-custom-rules` ConfigMap allows groups of *recording rules* to be specified, whereas the other ConfigMap does not.

Note: the names of the metrics in the examples above are more or less fictitious.
These are not the configurations I used in the end.

#### Implementation choices

I have chosen to compute, in the form of recording rules **in managed clusters**, the three components that make it possible to validate the completeness of an exercise, i.e.:

- The **Deployment** of the Quarkus microservice is in the **Available** state.
- The **Pod** of the database, when there is one, is present and in a **Ready** state.
- The Tekton Pipeline of the microservice has been successfully completed.
  As there is no standard metric for Tekton Pipelines, the *recording rule* detects the presence of the **Pod** corresponding to the last stage of the Pipeline and checks that it is in a **Completed** state.

I've created these recording rules for the **dev**, **preprod** and **prod** environments of the participants.
This way, if on the day of the Open Code Quest we had a widespread problem in the **prod** environment, we could quickly switch the computation of the scores to another upstream environment.

I can see one advantage to this approach: computing the three components of each exercise in the managed clusters means that not too many metrics are sent back to the **central** cluster.

In contrast, I had to compute the Leaderboard Prometheus queries described in the first part of this article in the form of recording rules at the **central cluster** level.
I didn't really have much choice: I needed several groups of recording rules and this function is only available in the ConfigMap which configures the recording rules for the **central** cluster.

You can find all the recording rules used for Open Code Quest in the [acm](https://github.com/nmasse-itix/opencodequest-leaderboard/tree/main/acm) folder.

### Setting up observability

Deploying the observability module on the **central** cluster is very simple, and can be done by following [the documentation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.11/html/observability/observing-environments-intro#enabling-observability-service):

- Create the namespace `open-cluster-management-observability`.
- Create the pull secret allowing images to be uploaded to **registry.redhat.io**.
- Create an S3 bucket.
- Create the *Custom Resource Definition* `MultiClusterObservability`.

To perform these operations, I used the following commands:

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

After installing the observability module, the managed clusters are automatically configured to report the most important Prometheus metrics to the **central** cluster.

The **Open Code Quest** workshop takes advantage of custom metrics that I use in the Leaderboard to find out which participants have got their microservices working.
To collect these metrics, I activate the **User Workload Monitoring** feature in each managed **OpenShift** cluster.

```sh
oc -n openshift-monitoring get configmap cluster-monitoring-config -o yaml | sed -r 's/(\senableUserWorkload:\s).*/\1true/' | oc apply -f -
```

### Deploying a Grafana development instance

A Grafana instance is automatically deployed with the observability module, but this instance is read-only: the standard dashboards can be consulted, but new ones cannot be created.
To create new dashboards, you need to deploy a development instance of Grafana at the same time.

```sh
git clone https://github.com/stolostron/multicluster-observability-operator.git
cd multicluster-observability-operator/tools
./setup-grafana-dev.sh --deploy
```

Once the instance has been deployed, you need to connect to it with any OpenShift user and give that user **administrator** privileges.

```sh
GRAFANA_DEV_HOSTNAME="$(oc get route grafana-dev -n open-cluster-management-observability -o jsonpath='{.status.ingress[0].host}')"
echo "Now login to Grafana with your openshift user at https://$GRAFANA_DEV_HOSTNAME"
read -q "?press any key to continue "
./switch-to-grafana-admin.sh "$(oc whoami)"
```

Then create the "Red Hat Summit Connect 2024" dashboard, as explained in the article {{< internalLink path="/blog/behind-the-scenes-at-open-code-quest-how-i-designed-leaderboard/index.md" >}}.

And finally, export the dashboard in the form of a ConfigMap.

```sh
./generate-dashboard-configmap-yaml.sh "Red Hat Summit Connect 2024"
```

The `red-hat-summit-connect-2024.yaml` file is created.
Simply apply it to the **central** cluster and the dashboard will appear in the production Grafana instance.

```sh
oc apply -f red-hat-summit-connect-2024.yaml
```

## Conclusion

To conclude, implementing the Leaderboard in Red Hat Advanced Cluster Management gave me a better understanding of how observability works, in particular recording rules.
In the end, I have been able to set up a dashboard that tracks the progress of participants in real time.

You can find all the recording rules used for Open Code Quest in the [acm](https://github.com/nmasse-itix/opencodequest-leaderboard/tree/main/acm) folder in the Git repository.
