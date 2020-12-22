---
title: "Install Kubernetes operators in OpenShift using only the CLI"
date: 2020-04-24T00:00:00+02:00
opensource: 
- OpenShift
topics:
- Containers
- Kubernetes Operators
---

OpenShift 4 went all-in on Kubernetes operators: they are used for installation of the platform itself but also to install databases, middlewares, etc.
There are more and more operators available on the [Operator Hub](https://operatorhub.io/).
Most software now provide an operator and describe how to use it.

Nevertheless, almost every software documentation I read so far, includes the steps to install the operator using the nice GUI of OpenShift 4.
But since my OpenShift environments are provisioned by a playbook, I want to be able to install operators using the CLI only!

<!--more-->

The [OpenShift official documentation](https://docs.openshift.com/container-platform/4.3/operators/olm-adding-operators-to-cluster.html#olm-installing-operator-from-operatorhub-using-cli_olm-adding-operators-to-a-cluster) covers this part but I did not find it very clear.
So, this article tries to make it clearer: **how to install Kubernetes operators in OpenShift using only the CLI**.

## Discover the available operators from the CLI

Discover the operators available on your platform.

```sh
oc get packagemanifests -n openshift-marketplace --sort-by=.metadata.name
```

This should give you a very long list of operators.
You can filter it to retain only the ones you need.

For instance, to discover the operators required to install Red Hat Service Mesh / Istio:

```
$ oc get packagemanifests -n openshift-marketplace |egrep -i '(elastic|jaeger|kiali|service.*mesh)'
elasticsearch-operator                       Red Hat Operators     47h
jaeger-product                               Red Hat Operators     47h
jaeger                                       Community Operators   47h
kiali                                        Community Operators   47h
kiali-ossm                                   Red Hat Operators     47h
servicemeshoperator                          Red Hat Operators     47h
```

The second column is the display name of the operator source.
Later in the procedure, we will need the identifier of the operator source.

Query it programmatically for a specific operator using the following command.

```sh
oc get packagemanifests -n openshift-marketplace -o jsonpath='{.status.catalogSource}{"\n"}' elasticsearch-operator
```

In the rest of this article, we will install Elastic Search using the **elasticsearch-operator** coming from the **redhat-operators** source using the CLI.

Query the available channels for this operator using the follwing command.

```sh
oc get packagemanifest -o jsonpath='{range .status.channels[*]}{.name}{"\n"}{end}{"\n"}' -n openshift-marketplace elasticsearch-operator
```

When this article was written, the Elastic Search operator had four channels:

```
4.2
4.2-s390x
4.3
preview
```

In the rest of this article we will install version 4.3 using the CLI.

Finally discover whether the operator can be installed cluster-wide or in a single namespace.

```sh
oc get packagemanifest -o jsonpath='{range .status.channels[*]}{.name}{" => cluster-wide: "}{.currentCSVDesc.installModes[?(@.type=="AllNamespaces")].supported}{"\n"}{end}{"\n"}' -n openshift-marketplace elasticsearch-operator
```

You will discover that the Elastic Search operator can be installed cluster-wide for all of its four channels.

```
4.2 => cluster-wide: true
4.2-s390x => cluster-wide: true
4.3 => cluster-wide: true
preview => cluster-wide: true
```

The rest of the procedure varies slightly depending if the operator supports cluster-wide installation or not.

## Install an operator cluster-wide using the CLI

To install an operator cluster-wide using the CLI, create a Subscription object in the **openshift-operators** namespace.

```sh
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: elasticsearch-operator
  namespace: openshift-operators
spec:
  channel: "4.3"
  name: elasticsearch-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

The outstanding fields of the Subscription object are:

* **metadata.name**: name of your subscription. *free choice*
* **metadata.namespace**: for a cluster-wide installation, the value is fixed: *openshift-operators*
* **spec.channel**: the channel to install (see above the output of the *oc get packagemanifest* command)
* **spec.name**: the name of the operator to install
* **spec.source**: the id of the operator source (currently there are three operator sources: *certified-operators*, *community-operators* and *redhat-operators*)
* **spec.sourceNamespace**: fixed value (*openshift-marketplace*)

Ensure the Elastic Search operator has been deployed successfully in the **openshift-operators** namespace.

```
$ oc get pods -n openshift-operators -l name=elasticsearch-operator
NAME                                      READY   STATUS    RESTARTS   AGE
elasticsearch-operator-6697867687-x7r6t   1/1     Running   0          3d6h
```

## Install an operator in a namespace using the CLI

To install an operator in a specific project, you need to create first an OperatorGroup in the target namespace.
An OperatorGroup is an OLM resource that selects target namespaces in which to generate required RBAC access for all Operators in the same namespace as the OperatorGroup.

Create a new project.

```sh
oc new-project my-project
```

Create an **OperatorGroup** object in your project.

```sh
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: my-project
  namespace: my-project
spec:
  targetNamespaces:
  - my-project
EOF
```

The outstanding fields of the OperatorGroup object are:

* **metadata.name**: name of your OperatorGroup. *free choice*
* **metadata.namespace**: the namespace in which you want to deploy your operator.
* **spec.targetNamespaces[0]**: the namespace in which you want to deploy your operator (again).

Once the subscription is created, the OLM should create a CSV (ClusterServiceVersion):

```
$ oc get csv
NAME                                         DISPLAY                  VERSION               REPLACES                                     PHASE
elasticsearch-operator.4.3.13-202004131016   Elasticsearch Operator   4.3.13-202004131016   elasticsearch-operator.4.3.10-202003311428   Succeeded
```

If the CSV is not created, it might be because there are multiple OperatorGroup object in the namespace.
Delete them all before recreating the one you need.

You can then create the Subscription object in **your project**.

```sh
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: elasticsearch-operator
  namespace: my-project
spec:
  channel: "4.3"
  name: elasticsearch-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

The meaning of each field is the same as described above in the section **Install an operator cluster-wide using the CLI**.

## Use the installed operator

Once installed, you will want to use the operator to perform something useful.
All the capabilities of your newly installed operator are described in the ClusterServiceVersion (CSV) created automatically by the Operator Lifecycle Manager (OLM).

```
$ oc get csv
NAME                                         DISPLAY                  VERSION               REPLACES                                     PHASE
elasticsearch-operator.4.3.13-202004131016   Elasticsearch Operator   4.3.13-202004131016   elasticsearch-operator.4.3.10-202003311428   Succeeded
```

You can get details about the Custom Resource Definitions (CRD) supported by the operator or retrieve some sample CRDs.

Get the CSV name of the installed Elastic Search operator.

```sh
CSV=$(oc get csv -o name |grep /elasticsearch-operator.)
```

Now you can query the CRDs enabled by your operator.

```sh
oc get $CSV -o json |jq -r '.spec.customresourcedefinitions.owned[]|.name'
```

This will return a list of fully qualified CRDs:

```
elasticsearches.logging.openshift.io
```

You can also retrieve the sample CRDs if you need some help to get started.

```sh
oc get $CSV -o json |jq -r '.metadata.annotations["alm-examples"]'
```

For example, you can create an Elastic Search instance by using the provided sample CRD.

```sh
oc get $CSV -o json |jq -r '.metadata.annotations["alm-examples"]' |jq '.[0]' |oc apply -f -
```

And then retrieve all the created objects belonging to the operator.

```sh
oc get $(oc get $CSV -o json |jq -r '[.spec.customresourcedefinitions.owned[]|.name]|join(",")')
```

## Conclusion

This article explained how to install Kubernetes operators in OpenShift using only the CLI and also how to use them afterwards without having to use to the OpenShift console!
