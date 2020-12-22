---
title: "Use QLKube to query the Kubernetes API"
date: 2019-06-07T00:00:00+02:00
opensource: 
- OpenShift
topics:
- GraphQL
---

[QLKube](https://github.com/qlkube/qlkube) is a project that exposes the Kubernetes API as GraphQL.
[GraphQL](https://en.wikipedia.org/wiki/GraphQL) is a data query and manipulation language for APIs developed initially by Facebook and released as open-source.
It strives to reduce the chattiness clients can experience when querying REST APIs.
It is very useful for mobile application and web development: by reducing the number of roundtrips needed to fetch the relevant data and by fetching only the needed field, the network usage is greatly reduced.

To install QLKube in OpenShift, use the NodeJS Source-to-Image builder:

{{< highlight sh >}}
oc new-project qlkube --display-name=QLKube
oc new-app nodejs~https://github.com/qlkube/qlkube.git --name=qlkube
{{< / highlight >}}

Disable TLS certificate validation to accommodate your self-signed certificates:

{{< highlight sh >}}
oc set env dc/qlkube NODE_TLS_REJECT_UNAUTHORIZED=0
{{< / highlight >}}

And enable the NodeJS development mode to enable the GraphQL explorer (disabled in production mode):

{{< highlight sh >}}
oc set env dc/qlkube NODE_ENV=development
{{< / highlight >}}

Give the GLKube's Service Account the right to query the Kubernetes API for its own namespace:

{{< highlight sh >}}
oc adm policy add-role-to-user view -z default
{{< / highlight >}}

Once deployed, open the QLKube URL in your web browser:

{{< highlight sh >}}
open $(oc get route qlkube -o go-template --template="http://{{.spec.host}}")
{{< / highlight >}}

You can try the following queries in the GraphQL explorer.

## Get all pods in the current namespace

Unless you gave the `cluster-admin` right to the QLKube Service Account, you will have to specify a target namespace in all your queries. The `all` type is a [meta type defined by QLKube](https://github.com/qlkube/qlkube/blob/9274405bb46592646220c099affdd24211875eed/src/schema.js#L25-L39) to ease the use of common types such as `services`, `deployments`, `pods`, `daemonSets`, `replicaSets`, `statefulSets`, `jobs` or `cronJobs`.

**Query:**

{{< highlight graphql >}}
query getAllPodsInCurrentNamespace {
  all(namespace: "qlkube") {
    pods {
      items {
        metadata {
          name
          creationTimestamp
        }
        status {
          phase
        }
      }
    }
  }
}
{{< / highlight >}}

**Response:**

{{< highlight json >}}
{
  "data": {
    "all": {
      "pods": {
        "items": [
          {
            "metadata": {
              "name": "qlkube-1-build",
              "creationTimestamp": "2019-06-07T07:56:53Z"
            },
            "status": {
              "phase": "Succeeded"
            }
          },
          {
            "metadata": {
              "name": "qlkube-3-jplpc",
              "creationTimestamp": "2019-06-07T14:03:48Z"
            },
            "status": {
              "phase": "Running"
            }
          }
        ]
      }
    }
  }
}
{{< / highlight >}}

## Get a service by name

To get an object by name, you can use the `fieldSelector` parameter (in this example, we are filtering on the `name` field in the `metadata` section).

**Query:**

{{< highlight graphql >}}
query getServiceByNameAndNamespace {
  all(namespace: "qlkube", fieldSelector: "metadata.name=qlkube") {
    services {
      items{
        metadata {
          name
          namespace
        }
        spec {
          clusterIP
        }
      }
    }
  }
}
{{< / highlight >}}

**Response:**

{{< highlight json >}}
{
  "data": {
    "all": {
      "services": {
        "items": [
          {
            "metadata": {
              "name": "qlkube",
              "namespace": "qlkube"
            },
            "spec": {
              "clusterIP": "172.30.213.61"
            }
          }
        ]
      }
    }
  }
}
{{< / highlight >}}

## Type introspection

Playing with the built-in types of GLKube is nice but you might soon be limited.
To discover all the available types, run this query:

{{< highlight graphql >}}
{
  __schema {
    types {
      name
    }
  }
}
{{< / highlight >}}

This query returns a list of all the available types (truncated here for brevity):

{{< highlight json >}}
{
  "data": {
    "__schema": {
      "types": [
        {
          "name": "Query"
        },
        {
          "name": "String"
        },
        {
          "name": "Boolean"
        },
        {
          "name": "Int"
        },
        {
          "name": "ComGithubOpenshiftApiAppsV1DeploymentConfig"
        },
        {
          "name": "ComGithubOpenshiftApiRouteV1Route"
        },
        {
          "name": "ComGithubOpenshiftApiRouteV1RouteList"
        }
      ]
    }
  }
}
{{< / highlight >}}

## Get a Deployment Config by name and namespace

Once the desired data type discovered, you can use it directly.

- If the data type represents an item (such as `ComGithubOpenshiftApiRouteV1Route`) you will need to specify the `name` and `namespace` parameters.
- If the data type is a list (such as `ComGithubOpenshiftApiRouteV1RouteList`) you will need to specify the `namespace` and optionally a `fieldSelector` parameters.

**Query:**

{{< highlight graphql >}}
query getDeploymentConfigByNameAndNamespace {
  comGithubOpenshiftApiAppsV1DeploymentConfig(name: "qlkube", namespace: "qlkube") {
    metadata {
      name
    }
    status {
      replicas
      availableReplicas
    }
  }
}
{{< / highlight >}}

**Reponse:**

{{< highlight json >}}
{
  "data": {
    "comGithubOpenshiftApiAppsV1DeploymentConfig": {
      "metadata": {
        "name": "qlkube"
      },
      "status": {
        "replicas": 1,
        "availableReplicas": 1
      }
    }
  }
}
{{< / highlight >}}

## Get routes by hostname and namespace

This query use a `fieldSelector` on the `host` field in the `spec` section and uses aliasing to rename the `status` field.

**Query:**

{{< highlight graphql >}}
query getRouteByHostnameAndNamespace {
  routes: comGithubOpenshiftApiRouteV1RouteList(namespace: "qlkube" fieldSelector: "spec.host=qlkube-qlkube.app.itix.fr") {
    items {
      metadata {
        name
      }
      status {
        ingress {
          routerName
          conditions {
            deployed: status
          }
        }
      }
    }
  }
}
{{< / highlight >}}

**Reponse:**

{{< highlight json >}}
{
  "data": {
    "routes": {
      "items": [
        {
          "metadata": {
            "name": "qlkube"
          },
          "status": {
            "ingress": [
              {
                "routerName": "router",
                "conditions": [
                  {
                    "deployed": "True"
                  }
                ]
              }
            ]
          }
        }
      ]
    }
  }
}
{{< / highlight >}}

## Sending your GraphQL request from curl

Once your GraphQL queries refined in the GraphQL Explorer, you can send them directly using curl or any HTTP client.

{{< highlight sh >}}
export GLKUBE_HOSTNAME=$(oc get route qlkube -o go-template --template="{{.spec.host}}")

cat <<EOF | curl -XPOST "http://$GLKUBE_HOSTNAME/" -H "Content-Type: application/json" -d @- -s |jq .
{
  "query": "query getAllPodsInCurrentNamespace {
              all(namespace: \"qlkube\") {
                services {
                  items {
                    metadata {
                      name
                      namespace
                      creationTimestamp
                      labels
                    }
                  }
                }
              }
            }"
}
EOF
{{< / highlight >}}

## Advanced use-cases

One use case in which GraphQL is very interesting is the ability to request in the same query an object and it's linked objects. For instance, it would be nice from a hostname to query the route that matches this hostname, along with the service backing this route and the pods behind the service.

Unfortunately, this is not yet possible with GLKube. Since it auto-generates its GraphQL schema from the OpenAPI Specifications of the Kubernetes APIs and those APIs are loosely coupled, some code would be required to link the relevant object between them.

## Conclusion

GLKube is a nice initiative to ease the use of the Kubernetes API. Definitely worth checking from times to times the status of this project. Some more code would be needed to enable the really interesting use cases that GraphQL can bring.
