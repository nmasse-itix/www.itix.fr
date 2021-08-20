---
title: "Deploy APIs from your CI/CD pipeline with the 3scale REST API"
date: 2021-07-26T00:00:00+02:00
lastMod: 2021-08-20T00:00:00+02:00
topics:
- API Management
opensource:
- 3scale
---

In the past years, I spent time (maybe too much) designing and implementing CI/CD pipelines around 3scale.
This led to the birth of the [threescale_cicd ansible role](https://github.com/nmasse-itix/threescale-cicd).
I also helped on the design of the [3scale_toolbox](https://github.com/3scale/3scale_toolbox) and crafted a [Jenkins shared library](https://github.com/rh-integration/3scale-toolbox-jenkins) as well as [sample CI/CD pipelines using the 3scale_toolbox](https://github.com/rh-integration/3scale-toolbox-jenkins-samples).
I had the opportunity to train colleagues and transmit this knowledge but I never took the time to set it down on paper.

This article is an attempt to transmit everything I know on this subject.

<!-- more -->

## Introduction

I will not explain **why** it is important to deploy your APIs from a CI/CD pipeline since I wrote a couple articles on this subject in the past.

- [Full API lifecycle management: A primer](https://developers.redhat.com/blog/2019/02/25/full-api-lifecycle-management-a-primer)
- [5 principles for deploying your API from a CI/CD pipeline](https://developers.redhat.com/blog/2019/07/26/5-principles-for-deploying-your-api-from-a-ci-cd-pipeline)

So, in this article, we will focus on the **how**: how to craft a solid mechanism to deploy your APIs from your CI/CD pipeline with the 3scale REST API.
To make it practical, we will use simple **curl** and **jq** commands and a bit of **bash** to tie them together.
**curl** is a simple tool to issue HTTP calls and **jq** parses JSON document to transform them or extract data from them.

If I stick to those three tools (curl, jq, bash) in this article, it is not because I love programming in bash but rather because it is easy to get something working quickly without specific programming abilities.
Or said differently: those three tools form a wonderful playground to learn.

The error handling will be minimal to keep the code simple so that everyone can understand.

Before we jump into code and REST calls, let's discuss a very important topic: idempotence.

## Idempotence

Idempotence is the property of certain operations in computer science whereby they can be applied multiple times without changing the result beyond the initial application. ([from Wikipedia](https://en.wikipedia.org/wiki/Idempotence))

Adding zero to any number is idempotent: no matter how many times you add zero, the result will always be the same.

Idempotence is a highly desirable property in distributed systems since [network packets can be lost, software can fail, etc.](https://en.wikipedia.org/wiki/Fallacies_of_distributed_computing).

Growing solutions such as Ansible, Terraform or the Operator SDK, made more accessible idempotence: **no matter in which state is the system, I only care about the target state**.

In the context of a CI/CD pipeline, idempotence is a must.
You never know what will happen to your pipeline (it can fail, be killed, be restarted, etc.).
If a commit get reverted, your pipeline might even go back in time (deploy a previous version)!

The question is how to achieve idempotence if the underlying REST API is not designed to be idempotent (the 3scale REST API is not).

There are two strategies: one is stateless and the other is stateful.

The stateless strategy (à la Ansible) involves discovering the current state of the system before applying changes.
Namely if I want the **service** petstore to be present in 3scale, I can issue a **GET /admin/api/services.json** and check if the petstore service is in the list.
If the petstore service exists, issue a **PUT /admin/api/services/{id}.json** to update it else issue a **POST /admin/api/services.json** to create it.

The stateful strategy (à la Terraform) involves recording (in a local database for instance) the identifiers of the target system objects upon creation.
With the previous use case, I would look into my local database if there is an id for the petstore service.
If there is an id for the petstore service, issue a **PUT /admin/api/services/{id}.json** to update it else issue a **POST /admin/api/services.json** to create it and then save the auto-generated identifier in the database.

The stateful strategy comes at a cost: you have to save the current state (the local database in the example above) on a persistent storage.
It is not impossible but puts an additional burden on the CI/CD system.

Also, this stateful strategy is subject to desynchronization between the CI/CD pipeline and the target system (3scale).
If someone deletes the service and re-creates it, the service will have a different identifier and the PUT request will fail.
This would require a manual intervention to update the current state with the new identifier.

The stateless strategy does not come as a free lunch either.

First, the API needs to accept external identifiers. That is to say, identifiers generated by the CI/CD pipeline.
With the 3scale REST API, when creating a **service** the CI/CD pipeline can supply a chosen **system_name**.
When searching for a **service** the pipeline can skim through the list of all services looking for the wanted system_name.

Most resources of the 3scale REST API accept an external identifier named **system_name**.
Some resources have no external identifiers (such as **mapping rules**).

Second, the API has to provide a mechanism to translate external identifiers to auto-generated id.
If there is no such translation mechanism available, we would need to go through the list of all objects.
If that list is long, this could be costly and if there is pagination, that can even involves multiple calls!

The 3scale REST API provides only the **list** call (without pagination) for most resources which means that large lists of objects will generate large network transfers.

There are two notable exceptions: the **application** and **account** resources.
They accepts external identifiers (user_key, app_id for the **application** resource and username for the **account** resource) and there is a REST method to translate the external id into the auto-generated id (**/admin/api/applications/find.json** and **/admin/api/accounts/find.json**).

All in all, the stateless strategy is an acceptable trade-off when working with the 3scale Admin REST API, especially considering the burden of managing a state in the pipeline.

In the rest of this article, I will focus on the stateless strategy to achieve idempotence.

There are two ways to approach idempotence with a stateless strategy:

- Check if the object exists and then update or create.
- Try to create and if it fails, find the id of the object and update it.

In the first case, it's a "GET then PUT or POST".
In the second case, it's a "POST. If it fails then GET and PUT".

The second case is more efficient when provisioning the system from scratch but less efficient on minor changes.
It also generates a lot of 422 HTTP codes (failed POST), which can trigger alerts on your monitoring system.

In both cases, since the API has not been designed from the ground up to be idempotent, operations are not atomic.

All in all, I chose the first approach (GET then PUT or POST).

## First contact with the 3scale Admin REST API

The 3scale Admin Portal offers four REST APIs: the Service Management API, the Billing API, the Analytics API and the Account Management API.
The Account Management API being usually called the 3scale Admin REST API.

3scale Admin REST API is documented in the **Help** section of your 3scale Admin Portal.
If you do not have access to the 3scale Admin Portal, you can find the Swagger file in the [porta github repo](https://github.com/3scale/porta/blob/3scale-2.10-stable/doc/active_docs/Account%20Management%20API.json).

It supports two types of payload: XML and JSON.
When the documentation states that the method returns XML, just replace **.xml** with **.json** at the end of the path and it returns JSON instead.

To use the 3scale Admin REST API, you need to have an access token.

You can get the default one from the OpenShift installation.

```sh
export THREESCALE_TOKEN="$(oc get secret system-seed -o go-template --template='{{.data.ADMIN_ACCESS_TOKEN|base64decode}}')"
```

Or you can generate one from the Admin portal.

- Click **Account Settings**
- Navigate to **Personal** > **Tokens**
- Click **Add Access Token**
- Check **Account Management API**
- Select **Read & Write** in the **Permission** dropdown box
- Click **Create Access Token**

In the rest of this article, I assume your access token will be set in the **THREESCALE_TOKEN** environment variable.

```sh
export THREESCALE_TOKEN="123...456"
```

This access token can be passed in the query string (all HTTP verbs) or in the body (POST, PUT, PATCH).

Now, set the hostname of the 3scale Admin Portal.
If you have access to the OpenShift platform where 3scale is installed, you can get it very easily.

```sh
export ADMIN_PORTAL_HOSTNAME="$(oc get route -l zync.3scale.net/route-to=system-provider -o go-template='{{(index .items 0).spec.host}}')"
```

In the rest of this article, I assume your 3scale Admin Portal hostname will be set in the **ADMIN_PORTAL_HOSTNAME** environment variable.

```sh
export ADMIN_PORTAL_HOSTNAME="3scale-admin.apps.$OPENSHIFT_SUFFIX"
```

For a first try, you can query the list of Services.

```
$ curl -skf "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services.json?access_token=$THREESCALE_TOKEN" | jq .
{
  "services": [
    {
      "service": {
        "id": 2,
        "name": "API",
        "state": "incomplete",
        "system_name": "api",
        "backend_version": "1",
        "deployment_option": "hosted",
        // output edited for brevity 
      }
    }
  ]
}
```

As you can see, instead of just returning a plain list of objects, 3scale wraps the list with an object and even wraps each object with another object.
This makes the API very verbose and not easy to work with.

Usually, I define two bash functions to transform the results from the 3scale Admin REST API: one for methods that returns a list and the other for methods returning a single item.

```sh
function cleanup_list () {
    jq 'to_entries | .[0].value | map(to_entries | .[0].value)'
}

function cleanup_item () {
    jq 'to_entries | .[0].value'
}
```

You can then directly pipe the output of curl to the **cleanup_list** function and get a cleaner output.

```
$ curl -skf "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services.json?access_token=$THREESCALE_TOKEN" | cleanup_list
[
  {
    "id": 2,
    "name": "API",
    "state": "incomplete",
    "system_name": "api",
    "backend_version": "1",
    "deployment_option": "hosted",
    // output edited for brevity
  }
]
```

Create a new service with the **Create Service** method.

```
$ curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services.json" \
            --data-urlencode "access_token=$THREESCALE_TOKEN" \
            --data-urlencode "name=test" \
            --data-urlencode "system_name=test" | cleanup_item
{
  "id": 9,
  "name": "test",
  "state": "incomplete",
  "system_name": "test",
  "backend_version": "1",
  "deployment_option": "hosted",
  // output edited for brevity
}
```

Now, let's say that a few days later, you need to update the service.
You would have to find the id of the service having the **system_name** "test".

Let me introduce you a new bash function that will help us in that task.
The first argument of that function is the external identifier (**system_name** in this example) to look for and the second argument is the value of this external id ("test" in this example).

```sh
function id_of_external_id () {
    jq --arg k "$1" --arg v "$2" -r '.[] | select(.[$k] == $v) | .id '
}
```

```
$ curl -skf "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services.json?access_token=$THREESCALE_TOKEN" | cleanup_list | id_of_external_id system_name test

9
```

Update the service with the **Update Service** method.

```
$ id=9
$ curl -skf -X PUT "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$id.json" \
            --data-urlencode "access_token=$THREESCALE_TOKEN" \
            --data-urlencode "name=new test" | cleanup_item
{
  "id": 9,
  "name": "new test",
  "state": "incomplete",
  "system_name": "test",
  "backend_version": "1",
  "deployment_option": "hosted",
  // output edited for brevity
}
```

And a few days later, you decide you do not need it anymore.
You can delete it with the **Delete Service** method.

```
$ id=9
$ curl -skf -X DELETE "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$id.json?access_token=$THREESCALE_TOKEN"
{
  "id": 9,
  "name": "new test",
  "state": "incomplete",
  "system_name": "test",
  "backend_version": "1",
  "deployment_option": "hosted",
  // output edited for brevity
}
```

Now that we covered the four CRUD methods, let's see how we can achieve idempotence by combining the previous building blocks in a "GET then PUT or POST" scheme.

The **apply_service** function takes a system_name as first argument and a state (absent/present) as second argument.
It then checks if the service exists and acts upon: creates if missing, update if present or delete if present and the requested state is "absent".

```sh
function apply_service () {
  local external_id=$1
  local state="$2"

  local id="$(curl -skf "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services.json?access_token=$THREESCALE_TOKEN" | cleanup_list | id_of_external_id system_name "$external_id")"
  
  if [[ -z "$id" ]] && [[ "$state" == "present" ]]; then
    echo "Creating service with system_name $external_id..."
    curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services.json" \
         --data-urlencode "access_token=$THREESCALE_TOKEN" \
         --data-urlencode "name=test" \
         --data-urlencode "system_name=$external_id" | cleanup_item
  elif [[ -n "$id" ]] && [[ "$state" == "present" ]]; then
    echo "Updating service with system_name $external_id and id = $id..."
    curl -skf -X PUT "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$id.json" \
         --data-urlencode "access_token=$THREESCALE_TOKEN" \
         --data-urlencode "name=test" | cleanup_item
  elif [[ -n "$id" ]] && [[ "$state" == "absent" ]]; then
    echo "Deleting service with system_name $external_id and id = $id..."
    curl -skf -X DELETE "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$id.json?access_token=$THREESCALE_TOKEN"
  fi
}
```

If you run it multiple times, you should see idempotence at play.

```
$ apply_service test present
Creating service with system_name test...

$ apply_service test present
Updating service with system_name test and id = 3...

$ apply_service test absent
Deleting service with system_name test and id = 3...

$ apply_service test absent
<nothing>
```

Of course, this is a very crude example: the call arguments are hardcoded, there is no error handling (unless you are using **set -e**), etc.
And this function is dedicated to one 3scale resource!
There are maybe fifty resources in 3scale...

## The playground

For the rest of this article, I will not come up with very clever code since the idea is to give "generic enough" instructions for 3scale users to implement it by themselves in the language of their choice.

However, if you want to play with the 3scale Admin Rest API, there are a couple of slightly more polished Bash functions in the [3scale API Playground](https://github.com/nmasse-itix/3scale-api-playground.sh) repository.
The **samples** directory contains ready-to-use examples that follow this article.

```sh
git clone https://github.com/nmasse-itix/3scale-api-playground.sh
cd 3scale-api-playground.sh
./pack.sh
./samples/01-api-with-apikey.sh
```

This playground uses the concepts and functions defined in this article but a few features have been added to make it more usable.

- It uses a **factory** to generate helper functions for all relevant 3scale resources (services, backends, mapping_rules, etc.).
- To deal with linked resources (a mapping_rule can be owned by a backend or a service), **"breadcrumbs"** can be set.
- And finally, all call parameters can be passed as an **associative array**.

For instance, to replicate the previous scenario (create a service), you could add the following lines at the end of **dev.sh**.

```sh
declare -A service_def=( ["system_name"]="test" ["name"]="Test API" ["description"]="This is a test" )
apply service present service_def
```

Now let's talk about the 3scale Admin REST API itself!

## Common return codes

You can expect the following return codes for CRUD methods.

- Upon resource creation (**POST**), the 3scale Admin REST API returns the HTTP code **201 Created**.
- Upon resource update (**PUT/PATCH**), it returns the HTTP code **200 OK**.
- Upon deletion (**DELETE**), it returns the HTTP code **200 OK**.

In case of error, the following error codes can be returned.

**422 Unprocessable Entity** is returned when a field has an wrong syntax or when the chosen system_name is already taken.

```
$ curl -D - -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services.json" \
       --data-urlencode "access_token=$THREESCALE_TOKEN" \
       --data-urlencode "name=test" \
       --data-urlencode 'system_name=b@d!'

HTTP/1.1 422 Unprocessable Entity

{
  "errors": {
    "system_name": [
      "invalid. Only ASCII letters, numbers, dashes and underscores are allowed."
    ]
  }
}
```

**403 Forbidden** is returned when you try to delete an object that is used elsewhere (like a backend that is still used by a product).

```
$ curl -D - -X DELETE "https://$ADMIN_PORTAL_HOSTNAME/admin/api/backend_apis/2.json"
       --data-urlencode "access_token=$THREESCALE_TOKEN"

HTTP/1.1 403 Forbidden

{
  "errors": {
    "base": [
      "cannot be deleted because it is used by at least one Product"
    ]
  }
}
```

**403 Forbidden** is also used when your access token is not valid.

```
$ curl -D - "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services.json?access_token=dummy"

HTTP/1.1 403 Forbidden

{
  "error": "Access denied"
}
```

**404 Not Found** is returned when you try to delete or update an nonexistent resource.

## Steps to deploy an API

This section presents the general steps to deploy an API using the 3scale Admin REST API.
Given that the previous sections explain how to implement idempotence, I will only show the resource creation.
If you struggle to achieve idempotence, you can still have a look at the [3scale API Playground](https://github.com/nmasse-itix/3scale-api-playground.sh) repository.

### Service

To deploy your API from a CI/CD pipeline, the first step would be to reserve your spot on the API Manager by creating a **service** resource.
The service is the publicly facing part of your API: what consumers will subscribe to.

To do so, you would need:

- a chosen external identifier: the **system_name**,
- a display **name** that will appear in the developer portal and in the 3scale Admin Portal,
- and a **description**.

The service creation call will also require two additional technical parameters:

- the **deployment_option** can take three different values depending on the type of API Gateway you are using and how it is managed.

  - **hosted** means your API will be protected by the default APIcast gateways deployed with 3scale. The OpenShift route will be managed for you too.
  - **self_managed** means you deployed an APIcast somewhere (even outside OpenShift).
  - **service_mesh_istio** is used when you are using the Istio adapter for 3scale.

- the **backend_version** defines the authentication mechanism used to secure your API. "1" is for API Key, "2" for API Key Pair and "oidc" is for OpenID Connect.

The creation and update call returns the created object as JSON format.
The only interesting field in the returned structured would be the **id** since you will need it to create the nested resources.

Create a new service named "Echo API" with system_name "echo", secured with API Key and using the default set of APIcast instances.

```sh
curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "name=Echo API" \
      --data-urlencode "system_name=echo" \
      --data-urlencode "backend_version=1" \
      --data-urlencode "deployment_option=hosted" | cleanup_item > service.json

# Retrieve the id of the created service
service_id="$(jq -r .id service.json)"
```

Regarding idempotence, use the **Service Create** (POST) to create a service, **Service Update** (PUT) to update it.
To find the service to update, use the **Service List** (GET) to list all the services and search yours by using the **system_name** as an external identifier.

Beware that the **Service List** call is paginated by default.
If you have more than 500 services in your API Manager, you have to deal with pagination!

### Backend

The **backend_apis** resource represents the internal part of your API: how to connect to your API implementation.

To create a **backend_apis**, you would need:

- a chosen external identifier: the **system_name**,
- a display **name** that will appear in the 3scale Admin Portal,
- a **description**
- and the URL of your API implementation (**private_endpoint**).

The **private_endpoint** field is composed of a scheme, host and eventually a port and a path.
If you specify a path, the called URLs will be automatically rewritten when used in a product (more on that later).

The creation and update call returns the created object as JSON format.
The only interesting field in the returned structured would be the **id** since you will need it to create the nested resources.

Create a new backend named "Echo API" with system_name "echo", living at https://echo-api.3scale.net.

```sh
curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/backend_apis.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "name=Echo API" \
      --data-urlencode "system_name=echo" \
      --data-urlencode "private_endpoint=https://echo-api.3scale.net" | cleanup_item > backend.json

# Retrieve the id of the created backend
backend_id="$(jq -r .id backend.json)"
```

Regarding idempotence, use the **Backend Create** (POST) to create a backend, **Backend Update** (PUT) to update it.
To find the backend to update, use the **Backend List** (GET) to list all the backends and search yours by using the **system_name** as an external identifier.

Beware that the **Backend List** call is paginated by default.
If you have more than 500 backends in your API Manager, you have to deal with pagination!

### Methods and metrics

3scale has two concepts to keep track of API usage: **metrics** and **methods**.
Both counts something that can be summed over time (number of calls, bytes, items, etc.).
The main difference is that **metrics** are shown as a curve in the Analytics module and can have a custom unit (bytes, items, foos, bars) attached.
**methods** on the over hand are shown as histograms and always represent a number of API calls.
Also methods are tied to a specific metric and all methods tied to a metric are shown stacked when this metric is displayed.

There is a special metric named **hits** that you can use to create your methods if you do not want to create a specific metric for it.

Methods and metrics can be nested under services and backends.
With metrics and methods under a backend, you can keep track of the individual API methods usage.
And under a service, you can for instance keep track of API version usage (if there are two backends, one for each version).

Methods and metrics have the usual **system_name** property that you can use as an external identifier to find them back later.
This is especially true when nested under a **service**.
However, when nested under a **backend**, the **system_name** will be silently suffixed by the backend internal id.
For instance, if you create a metric with **system_name=test** under the backend that have id **6**, the created resource will have its **system_name** set to **test.6**.

This means that when you want to find back your metric or method (to achieve idempotence), you cannot search for the chosen bare **system_name** but you need to parse it accordingly.

Let me introduce you a new bash function that will help us in that task.
The first argument of that function is the external identifier (**system_name** in this example) to look for and the second argument is the value of this external id ("hits" in this example).

```sh
function id_of_external_id_with_prefix () {
    jq --arg k "$1" --arg v "$2" -r '.[] | select(.[$k] | startswith($v + ".")) | .id '
}
```

And now you can get the id of the default "hits" metric of our newly created backend and service.

```sh
curl -skf "https://$ADMIN_PORTAL_HOSTNAME/admin/api/backend_apis/$backend_id/metrics.json?access_token=$THREESCALE_TOKEN" | cleanup_list > backend_metrics.json
backend_hits_metric_id="$(cat backend_metrics.json | id_of_external_id_with_prefix system_name hits)"

curl -skf "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/metrics.json?access_token=$THREESCALE_TOKEN" | cleanup_list > service_metrics.json
service_hits_metric_id="$(cat service_metrics.json | id_of_external_id system_name hits)"
```

This was the main caveat to achieve idempotence with metrics and methods.
The rest is pretty standard.

To create a **metrics** and **methods**, you would need:

- a chosen external identifier: the **system_name**,
- a **friendly_name** that will appear in the 3scale Admin Portal,
- a **description**,
- and only for **metrics**: a **unit** that is decorative only (no computation depends on it).

Create a new backend method with name "sayHello" nested under the "hits" metric.

```sh
curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/backend_apis/$backend_id/metrics/$backend_hits_metric_id/methods.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "system_name=sayHello" \
      --data-urlencode "description=How many times the sayHello method has been called" \
      --data-urlencode "friendly_name=Say Hello" | cleanup_item > method.json
method_id="$(cat method.json | jq -r .id)"
```

Beware that the **Methods List** and **Metrics List** calls are paginated by default when nested inside a **backend_apis** and not when nested inside a **services**.
If you have more than 500 methods/metrics in your backend, you have to deal with pagination!

### Mapping Rules

**mapping_rules** bind an HTTP method and a path pattern to a **metric** or **method**.
The method can be GET, POST, PUT, DELETE, PATCH, etc.
The path pattern is the pattern that the path of the incoming request has to match to trigger a **metric**/**method** increment.

The path pattern always start at the beginning of the path so there is no need for an anchor such as `^` in a regex.
It can contains placeholders such as `{id}` to indicate a variable path component.
And finally, it can terminate with a dollar sign to indicate an exact match.
If there is no dollar sign at the end, it is a prefix match.

Path patterns can overlap: **/api/foo** matches everything that begins with /api/foo and **/api/{obj}/bar$** matches everything that starts with /api, ends with /bar and has a path component in-between.
An incoming request having the **/api/foo/bar** would match both mapping_rules.

To deal with such cases, **mapping_rules** have two dedicated properties:

- a **position** to process them from the first (1) to the last,
- and a **last** flag to stop the processing if the mapping_rule matches.

**mapping_rules** have other properties, such as:

- the **http_method** and **pattern** discussed above,
- a **metric_id** that contains the id of the **metric** or **method** to increment if the mapping rule matches,
- and a **delta** which is by how much to increment the target **metric** or **method** if the mapping rule matches.

**mapping_rules** can be nested under a backend or the **proxy** of a service (more on that later), depending if you want to reuse the mapping rule each time the backend is used in a service or not.
If the **mapping_rule** is used in the **proxy** of a service it is specific to this service.

Beware that the **Mapping Rules List** calls are paginated by default when nested under **backend_apis** and not when nested under **services**.
If you have more than 500 mapping rules in your backend, you have to deal with pagination!

Regarding idempotence, mapping rules have no external identifier (no **system_name**).
This means that once created, if you do not store the auto-incremented identifier of the mapping rule, there is no way to find it back.
One could argue that the tuple (**http_method** / **pattern**) should be unique and could be used an external identifier.

I see at least two ways to deal with this issue:

- Delete all mapping rules and recreate them each time (the approach I chose in the [3scale API Playground](https://github.com/nmasse-itix/3scale-api-playground.sh) repository)
- List all mapping rules, compute the diff between what you have and what you want and do the needed POST/PUT/DELETE (the approach I implemented in the [threescale_cicd](https://github.com/nmasse-itix/threescale-cicd/blob/master/tasks/steps/mapping_rules.yml) repository)

Create a new mapping rule for **GET /** incrementing the **sayHello** method by 1.

```sh
curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/backend_apis/$backend_id/mapping_rules.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "http_method=GET" \
      --data-urlencode "pattern=/" \
      --data-urlencode "delta=1" \
      --data-urlencode "metric_id=$method_id" | cleanup_item
```

### Backend Usage

Now that you created a **service** and a **backend_api**, it's time to bind them together with a **backend_usage**.

To create a **backend_usage**, you would need:

- the **backend_api_id** (id of the **backend_api**),
- and an optional **path** if you need to prefix the backend URLs.

The creation and update call returns the created object as JSON format but there is no interesting field in the returned structure.

Regarding idempotence, use the **Backend Usage Create** (POST) to create a backend usage, **Backend Usage Update** (PUT) to update it.
To find the backend usage to update, use the **Backend Usage List** (GET) to list all the backend usages and search yours by using the **backend_api_id** as an external identifier.

Create a new backend_usage binding the echo service with the echo backend at /.

```sh
curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/backend_usages.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "backend_api_id=$backend_id" \
      --data-urlencode "path=/" | cleanup_item
```

### Application Plan

An Application Plan binds a client application to a **service**, while applying rate limits and pricing rules.

In this section, we will create an **application_plan** resource, two nested **limits** and four nested **pricing_rules**.

To create an **application_plan**, you would need:

- a chosen external identifier: the **system_name**,
- a display **name** that will appear in the 3scale Admin Portal,
- a state (**state_event**) that is either **publish** (visible in the Developer Portal) or **hide** (not visible),
- whether an approval is required to use that plan or not (**approval_required**),
- and the pricing structure of the application plan (**cost_per_month**, **setup_fee** and **trial_period_days**).

The creation and update call returns the created object as JSON format.
The only interesting field in the returned structure would be the **id** since you will need it to create the nested resources.

Create a new hidden application plan named "Test Plan" with system_name "test".

```sh
curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/application_plans.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "name=Test Plan" \
      --data-urlencode "system_name=test" | cleanup_item > application_plan.json

# Retrieve the id of the created application_plan
application_plan_id="$(jq -r .id application_plan.json)"
```

Regarding idempotence, use the **Application Plan Create** (POST) to create an application plan, **Application Plan Update** (PUT) to update it.
To find the application plan to update, use the **Application Plan List** (GET) to list all the application plans and search yours by using the **system_name** as an external identifier.

Note: by default, application plans are created hidden.
Strangely, you cannot specify **state_event=hide** when creating the plan...

#### Limits

To create a **limit**, you would need:

- a **period** (day, hour, minute, etc),
- and a **value** for the limit.

The creation and update call returns the created object as JSON format but there is no interesting field in the returned structure.

Create a new limit for the "sayHello" method at 5 hits per minute.

```sh
curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/application_plans/$application_plan_id/metrics/$method_id/limits.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "period=minute" \
      --data-urlencode "value=5" | cleanup_item
```

Create a new limit for the "sayHello" method at 100 hits per day.

```sh
curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/application_plans/$application_plan_id/metrics/$method_id/limits.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "period=day" \
      --data-urlencode "value=100" | cleanup_item
```

Regarding idempotence, limits have no external identifier (no **system_name**).
This means that once created, if you do not store the auto-incremented identifier of the limit, there is no way to find it back.
One could argue that the **period** key is unique and could be used an external identifier.

I see at least two ways to deal with this issue:

- Delete all limits and recreate them each time (the approach I chose in the [3scale API Playground](https://github.com/nmasse-itix/3scale-api-playground.sh) repository)
- List all limits, compute the diff between what you have and what you want and do the needed POST/PUT/DELETE

Use the **Limit Create** (POST) to create a limit, **Limit Update** (PUT) to update it.
To find the limit to update, use the **Limit List per Metric** (GET) to list all the limits and search yours by using the **period** as an external identifier.

#### Pricing Rules

To create a **pricing_rule**, you would need:

- a lower (**min**) and upper bound (**max**) for the rule,
- and a price as floating point number (**cost_per_unit**).

The creation call returns the created object as JSON format but there is no interesting field in the returned structure.

Create a new pricing rule for the first ten calls to the "sayHello" method at 1 euro (or whatever currency you chose in your 3scale tenant) per call.

```sh
curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/application_plans/$application_plan_id/metrics/$method_id/pricing_rules.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "min=1" \
      --data-urlencode "max=10" \
      --data-urlencode "cost_per_unit=1.0" | cleanup_item
```

Create the pricing rules for the subsequent calls to the "sayHello" method at 0.9, 0.8 and 0.75 euro per call.

```sh
curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/application_plans/$application_plan_id/metrics/$method_id/pricing_rules.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "min=11" \
      --data-urlencode "max=100" \
      --data-urlencode "cost_per_unit=0.9" | cleanup_item

curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/application_plans/$application_plan_id/metrics/$method_id/pricing_rules.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "min=101" \
      --data-urlencode "max=1000" \
      --data-urlencode "cost_per_unit=0.8" | cleanup_item

curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/application_plans/$application_plan_id/metrics/$method_id/pricing_rules.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "min=1001" \
      --data-urlencode "max=" \
      --data-urlencode "cost_per_unit=0.75" | cleanup_item
```

Regarding idempotence, pricing rules have no external identifier (no **system_name**).
This means that once created, if you do not store the auto-incremented identifier of the pricing rule, there is no way to find it back.
And unlike the **limits**, there is no easy unique key you could use as an external identifier.

In addition to that, there is no **Pricing Rule Update** method.

I see at least two ways to deal with this issue:

- Delete all pricing rules and recreate them each time (the approach I chose in the [3scale API Playground](https://github.com/nmasse-itix/3scale-api-playground.sh) repository)
- List all pricing rules, compute the diff between what you have and what you want and if there is a difference, delete them all and recreate them.

It seems difficult to use a regular diff algorithm like for **limits** since the 3scale Admin Portal checks there is no overlap between **pricing_rules** for their lower and upper bounds.

### Test Application

An **application** resource represents a client application.
By creating a test **application**, you will be able to perform an end-to-end test: from the client to the API backend, through the API Gateway.

An application has to be nested inside an **account** resource. Hopefully, there is already an **account** created as part of the 3scale installation and dedicated for tests: the **Developer** account.

You can find its id with a call to the **Account List** (GET) method.

```sh
curl -skf "https://$ADMIN_PORTAL_HOSTNAME/admin/api/accounts.json?access_token=$THREESCALE_TOKEN&per_page=1" | cleanup_list > account.json
account_id="$(jq '.[0].id' account.json)"
```

To create an **application**, you would need:

- the id of the application plan to use (**plan_id**),
- a **name** and **description**,
- a **user_key** (when using API Key),
- or a tuple **application_id**/**application_key** and an optional **redirect_url** (when using OpenID Connect).

The creation and update call returns the created object as JSON format.
The returned structure contains the **id** of the created resource. If you did not specify **user_key**, **application_id** and **application_key**, auto-generated values will be returned for those fields.

Regarding idempotence, the **application** resource has two possible external identifiers: **user_key** (when using API Key) or **application_id** (when using OpenID Connect). Use the **Application Create** (POST) to create an application, **Application Update** (PUT) to update it.
To find the application to update, use the **Application Find** (GET) to retrieve an application by its **user_key** or **application_id**.

Since the **user_key** and **application_key** are secrets that enable access to your API, you have to make them unguessable but at the same time deterministic in order to achieve idempotence.
An HMAC function meet those two criteria: given a secret and some stable data, you get a deterministic but unguessable output.

You can generate the **user_key** or **application_id** with a hash of the **application** name, **service** system_name and a secret such as the 3scale Admin Token.
In the following example, I used a SHA1 hash function and the 3scale Admin Token.
For production usage, you should use a more secure hash function (SHA512) and a dedicated secret stored in a vault, with enough entropy.

```sh
echo -n "${application_name}${service_system_name}${THREESCALE_TOKEN}" | sha1sum | cut -d " " -f1
```

To generate an **application_key** that is different from the **application_id**, you can introduce a slight variation in the input data.

```sh
echo -n "secret${application_name}${service_system_name}${THREESCALE_TOKEN}" | sha1sum | cut -d " " -f1
```

Create a new application named "Test App" and backed by the "Test Plan".

```sh
application_name="Test App"
service_system_name="echo"
user_key="$(echo -n "${application_name}${service_system_name}${THREESCALE_TOKEN}" | sha1sum | cut -d " " -f1)"

curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/accounts/$account_id/applications.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "plan_id=$application_plan_id" \
      --data-urlencode "name=$application_name" \
      --data-urlencode "description=Used for end-to-end tests" \
      --data-urlencode "user_key=$user_key" | cleanup_item
```

### Proxy configuration

The **proxy** resource is nested under a **service** resource and represents the low level settings of an API.
There is only one **proxy** under a **service**, so achieving idempotence is trivial: there is no need for external identifiers, reconciliation, etc.

The main settings of a **proxy** are:

- the Public Staging URL,
- the Public Production URL,
- the location of the credentials within the request (headers or query string),
- and the OIDC Issuer Endpoint if your service is configured to use OpenID Connect.

The Public Staging URL is a Public URL you can use to test your API before committing the changes to the production gateway (accessible through the Public Production URL).
The Staging and Production URL should not be confused with the multiple environments a customer can have (DEV, TEST, QA, PRE-PROD, PROD, etc.)
In fact, there will be a staging and a production URL in each environment.

You can think of the public staging URL as a way to **test ongoing changes** before **committing them atomically to the public production URL**.

What you will do with the **proxy** will depend of which deployment option you chose when creating the **service**.

- if you chose the **hosted** deployment option, you will **read** the proxy to find out the Public Staging and Production URLs.
- if you chose the **self_managed** deployment option, you will set the Public Staging and Production URLs in the **proxy**.

Find out the Public Staging (**sandbox_endpoint**) and Production (**endpoint**) URLs of the Echo API.

```sh
curl -skf -X GET "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/proxy.json?access_token=$THREESCALE_TOKEN" | cleanup_item > proxy.json
public_staging_url="$(cat proxy.json | jq -r .sandbox_endpoint)"
public_production_url="$(cat proxy.json | jq -r .endpoint)"
```

Set the credentials to be passed in an HTTP Header named **X-APIKey**.

```sh
curl -skf -X PATCH "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/proxy.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "credentials_location=headers" \
      --data-urlencode "auth_user_key=X-APIKey" | cleanup_item
```

If your service is configured to use OpenID Connect, you will also have to set the OIDC Issuer Type (**oidc_issuer_type**) and OIDC Issuer Endpoint (**oidc_issuer_endpoint**).
The former is fixed if you use 3scale with Red Hat SSO while the later has the following syntax:

```sh
https://$CLIENT_ID:$CLIENT_SECRET@$SSO_HOSTNAME/auth/realms/$REALM
```

If the **echo** service were configured to use OpenID Connect, you would have been able to update the OIDC Issuer Endpoint.

```sh
curl -skf -X PATCH "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/proxy.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "oidc_issuer_endpoint=https://zync:s3cr3t@sso.apps.$OPENSHIFT_SUFFIX/auth/realms/3scale" \
      --data-urlencode "oidc_issuer_type=keycloak" | cleanup_item
```

### Policy chain

The **policies** resource is nested under a **proxy** resource and represents the handling of a request and response during their journey through the API Gateway.
There is only one **policies** resource under a **proxy**, so achieving idempotence is trivial: there is no need for external identifiers, reconciliation, etc.

There is a default policy chain that you can read with the **Proxy Policies Chain Show** method.

```sh
curl -skf -X GET "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/proxy/policies.json?access_token=$THREESCALE_TOKEN" | cleanup_item
```

The default policy chain at the time this article has been written is:

```json
[
  {
    "name": "apicast",
    "version": "builtin",
    "configuration": {},
    "enabled": true
  }
]
```

You can add policies by manipulating this JSON array: either before or after the built-in policy **apicast**.
Each item of this array is the application of a policy and policies are applied in order (from the first to the last, for each of the Nginx phases).

There is a registry of all available policies that you can query with the **APIcast Policy Registry** method.

```sh
curl -skf -X GET "https://$ADMIN_PORTAL_HOSTNAME/admin/api/policies.json?access_token=$THREESCALE_TOKEN" > policies.json
```

The returned JSON structure can be queries to list all available policies.

```sh
jq -r 'to_entries | .[].key' policies.json | sort
```

And you can extract the configuration schema of the desired policy.

For instance, extract the configuration schema of the **cors** policy.

```sh
jq '.cors[0].configuration' policies.json > cors_schema.json
```

Create a sample configuration for the **cors** policy.

{{< highlightFile "cors.json" "json" "" >}}
{
    "allow_credentials": true
}
{{< /highlightFile >}}

Validate that the configuration conforms to the extracted schema.

```sh
sudo dnf install python3-jsonschema
jsonschema -i cors.json cors_schema.json
```

Create the final policy chain.

{{< highlightFile "policy_chain.json" "json" "" >}}
[
  {
    "name": "cors",
    "version": "builtin",
    "enabled": true,
    "configuration": {
      "allow_credentials": true
    }
  },
  {
    "name": "apicast",
    "version": "builtin",
    "configuration": {},
    "enabled": true
  }
]
{{< /highlightFile >}}

You can then change the policy chain with the **Proxy Policies Chain Update** method.
For instance, update the policy chain of the **echo** service with the new policy chain.

```sh
curl -skf -X PUT "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/proxy/policies.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "policies_config=$(cat policy_chain.json)" | cleanup_item
```

### OIDC Configuration

If you configured your **service** to use OpenID Connect, you can configure the enabled OIDC flows through the **oidc_configuration** resource.

The **oidc_configuration** resource is nested under a **proxy** resource.
There is only one **oidc_configuration** resource under a **proxy**, so achieving idempotence is trivial: there is no need for external identifiers, reconciliation, etc.

There is a default configuration that you can read with the **OIDC Configuration Show** method.

```sh
curl -skf -X GET "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/proxy/oidc_configuration.json?access_token=$THREESCALE_TOKEN" | cleanup_item
```

The default configuration at the time this article has been written is:

```json
{
  "standard_flow_enabled": true,
  "implicit_flow_enabled": false,
  "service_accounts_enabled": false,
  "direct_access_grants_enabled": false
}
```

If you want to perform automated integration tests, you will have to enable either **direct_access_grants_enabled** or **service_accounts_enabled**.

If the **echo** service were configured to use OpenID Connect, you would have been able to update the OIDC configuration to enable the **service_accounts_enabled** flag.

```sh
curl -skf -X PATCH "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/proxy/oidc_configuration.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "service_accounts_enabled=1" | cleanup_item
```

### Deploy the proxy

Depending on how the service has been created, you might need to deploy the proxy configuration to the staging gateway.
It is not always strictly needed but it does not hurt.

If you chose the **hosted** or **self_managed** deployment option during service creation, this step will deploy the ongoing configuration changes to the staging gateway.

If you chose the **service_mesh_istio** deployment option, this step will deploy the ongoing configuration changes to the connected services mesh (there is only one connected service mesh for each **service**).
When using the **service_mesh_istio** deployment option, you can skip the next steps and jump directly to the [Active Docs section](#active-docs).

Deploy the proxy of the **echo** service to the staging gateway.

```sh
curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/proxy/deploy.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" | cleanup_item
```

### Integration tests

At this time of the process, the staging gateway is more or less ready to serve requests for your API.
You can use the API Key or application id / application key to query your API through the API Gateway, validating the end-to-end behavior.

The procedure is straightforward when using API Keys: just run your API test suite against the Public Staging URL with your API Key passed in the corresponding HTTP header.

```sh
curl -sfk $public_staging_url/hello -H "X-APIKey: $user_key"
```

When using OpenID Connect you would have to get a token from Keycloak / Red Hat SSO first.

You can compute the **token** endpoint location from the OIDC Issuer Endpoint used earlier.

```sh
token_endpoint="$(echo "$OIDC_ISSUER_ENDPOINT" |sed -r 's|(https?)://[^:]+:[^@]+@([^/]+)/(.*)$|\1://\2/\3|')/protocol/openid-connect/token"
```

And then fetch a token from Red Hat SSO, using the Client Credentials flow.
The **client_id** and **client_secret** in the OIDC lingua are the **application_id** and **application_key** in the 3scale lingua.

```sh
while ! curl -sfk "$token_endpoint" -X POST -d client_id="$client_id" -d client_secret="$client_secret" -d "grant_type=client_credentials" > "token.json"; do
  echo "Waiting for the OIDC client to appear in Keycloak..."
  sleep 5
done
token="$(jq -r .access_token "token.json")"
```

You absolutely need to implement a retry mechanism since the client creation is done asynchronously.
At this stage, there is no guarantee that the test application creation ([see above](#test-application)) successfully led to the client creation in Red Hat SSO.
And of course your retry mechanism should have a timeout in order to prevent your process from staying in an infinite loop.

You can then run your API test suite against the Public Staging URL with your access token passed in the **Authorization** header.

```sh
curl -sfk $public_staging_url/hello -H "Authorization: Bearer $token"
```

It is important to note that sometimes, the Staging Gateway is not fully ready to serve the first request.
So it is wise to setup a retry mechanism like for the OIDC token retrieval.

### Promote to production

If the integration tests ran successfully against the Public Staging URL, you can promote the configuration from the staging to the production gateway.

This process involves three steps:

- read the proxy version number of the staging environment,
- read the proxy version number of the production environment,
- if they are different, call the promote endpoint.

Read the proxy version number of the staging environment of the **echo** service.

```sh
curl -skf -X GET "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/proxy/configs/sandbox/latest.json?access_token=$THREESCALE_TOKEN" | cleanup_item > proxy.json
staging_version="$(jq -r .version proxy.json)"
```

Read the proxy version number of the production environment of the **echo** service.

```sh
curl -skf -X GET "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/proxy/configs/production/latest.json?access_token=$THREESCALE_TOKEN" | cleanup_item > proxy.json
production_version="$(jq -r .version proxy.json)"
```

If the two versions are different, you can call the **promote** endpoint.

```sh
curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/services/$service_id/proxy/configs/sandbox/$staging_version/promote.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "to=production" | cleanup_item
```

### Active Docs

The **active_docs** resource represents the documentation of your API: the OpenAPI Specification file, version 2.0 or 3.0.

To create a **active_docs**, you would need:

- a chosen external identifier: the **system_name**,
- a display **name** that will appear in the 3scale Admin Portal,
- a **body** containing the whole OpenAPI Specification file,
- an optional publication state (**published**),
- a flag to instruct 3scale to skip the validation of the OpenAPI Specification file,
- and the id of the corresponding service (**service_id**).

The creation and update call returns the created object as JSON format.

Regarding idempotence, use the **ActiveDocs Spec Create** (POST) to create an ActiveDocs, **ActiveDocs Spec Update** (PUT) to update it.
To find the ActiveDocs to update, use the **ActiveDocs Spec List** (GET) to list all the ActiveDocs and search yours by using the **system_name** as an external identifier.

Speaking of system_name, I strongly suggest using the **same system_name** for both your **service** and your **active_docs**.
This way, you will be able to [build a dynamic API Catalog in the 3scale API Developer portal](https://github.com/3scale-labs/3scale-discover-APIs/blob/master/doc/activedocs.md) (see [Pull Request #5](https://github.com/3scale-labs/3scale-discover-APIs/pull/5) for OpenAPI Specification 3.0 support).

Create a new ActiveDocs named "Echo API" with system_name "echo".

```sh
cat > echo-api.json <<EOF
{
  "openapi": "3.0.2",
  "info": {
    "title": "Echo API",
    "version": "1.0"
  },
  "paths": {
    "/": {
      "get": {
        "responses": {
          "200": {
            "description": "OK"
          }
        },
        "operationId": "sayHello"
      }
    }
  }
}
EOF

curl -skf -X POST "https://$ADMIN_PORTAL_HOSTNAME/admin/api/active_docs.json" \
      --data-urlencode "access_token=$THREESCALE_TOKEN" \
      --data-urlencode "name=Echo API" \
      --data-urlencode "system_name=echo" \
      --data-urlencode "service_id=$service_id" \
      --data-urlencode "published=true" \
      --data-urlencode "body=$(cat echo-api.json)" | cleanup_item
```

Note: in the default 3scale installation, there is already a built-in ActiveDocs with system_name **echo**, bound to the service with system_name **api**.

## Designing the interface

In the previous section, I described the different steps to deploy an API using only the 3scale Admin REST API.
If you are about to implement a tool to deploy APIs from your CI/CD pipeline, let me suggest you a public interface for such a tool.
It is the result of several attempts as well as several customers' feedbacks.

```js
{
  // What to deploy: the API Contract
  "openapi": {
    "content": "openapi: 3.0.2\ninfo:\n ...",
    "validate": true
  },

  // Where to deploy: the 3scale Admin Portal
  "threescaleAdminPortal": {
    "url": "https://3scale-admin.apps.foo.bar",
    "token": "123...456",
    "insecure": false // Skip TLS certificate validation?
  },
  
  // How to deploy: the environment
  "environment": {
    // The baseSystemName is used together with the environmentName and versionNumber
    // to compute a targetSystemName.
    "baseSystemName": "echo",
    "environmentName": "dev",
    "versionNumber": "1.2.3",
    
    // ... but you can override the targetSystemName if desired.
    "targetSystemName": "dev_echo_1",

    // publicBasePath and privateBasePath are used to compute the url_rewriting policy. 
    "publicBasePath": "/api",
    "privateBasePath": "/rest",

    // For OpenID Connect APIs only
    "oidcIssuerEndpoint": "https://zync:s3cr3t@sso.apps.foo.bar/auth/realms/3scale",

    // The location of the API Backend
    "privateBaseURL": "https://echo-api.3scale.net",

    // The public staging and production URLs are generated by the 3scale Admin Portal
    // but you can override them here.
    "publicStagingURL": "https://echo-api-staging.apps.foo.bar",
    "publicProductionURL": "https://echo-api-production.apps.foo.bar"
  },
  "applicationPlans": [ // A list of application plans to create
    { 
      "systemName": "test",
      "name": "Test Plan",
      "defaultPlan": true,
      "published": true,
      "limits": [
        { "period": "minute", "value": 5, "metric": "sayHello" },
        { "period": "day", "value": 100, "metric": "sayHello" }
      ],
      "pricingRules": [
        { "from": 1, "to": 10, "cost": 1.0, "metric": "sayHello" },
        { "from": 11, "to": 100, "cost": 0.9, "metric": "sayHello" },
        { "from": 101, "to": 1000, "cost": 0.8, "metric": "sayHello" },
        { "from": 1001, "cost": 0.75, "metric": "sayHello" }
      ]
    }
  ],
  "applications": [ // A list of applications to create
    {
      "name": "Test App",
      "description": "Used for end-to-end tests",
      "plan": "test",
      "accountID": 123 // optional: the default "Developer" account can be discovered automatically

      // there is no user_key or application_id / application_key here since they are computed
      // automatically with a HMAC as explained above.
    }
  ]
}
```

Let's have a look at each field and its implication on the deployment process.

**openapi.content** is the OpenAPI Specification file (YAML or JSON), as string.
It is parsed to extract relevant information.

- **info.version** is the API version number. By applying the [Semantic Versioning](https://semver.org/) rules, this drives the creation of another service, **side-by-side** with the previous version (upon major version bump), or not (minor version).
- **info.title** makes a good **environment.baseSystemName** once sanitized.
- the **path** structure can be walked through to extract:
  - the **operationId** that will become the **system_name** of **methods**
  - the paths and methods will be used to compute **mapping_rules**
- **security** is used to determine the global security scheme name
- **components.securitySchemes** is used to find the detail of the global security scheme.
  Those data will determine the **service** type (API Key or OIDC?) and the **proxy** settings (HTTP Header? Query String?).
- the **servers** structure can eventually be used to build a default value for the **privateBaseURL**.

The **targetSystemName** is built from the **environmentName** (if specified), the **baseSystemName** and the API Version Number (only the "major" version component).

Example:

- An API in version number **1.0.0**, with a baseSystemName = **test** will lead to **test_1**.
- An API in version number **1.1.0**, with a baseSystemName = **test** will lead also to **test_1**, thus updating the service instead of creating a new one.
- An API in version number **2.0.0**, with a baseSystemName = **test** will lead to **test_2**, thus creating a new service.

If the **environmentName** is specified, it is just prefixed to allow multiple environments to be deployed in the same 3scale Admin Portal.

The **publicBasePath** and **privateBasePath** are used to compute the url_rewriting policy.

If **publicStagingURL** and **publicProductionURL** are specified, the created **service** will have its **deployment_option** set to **self_managed** and the corresponding URLs set in the **proxy** configuration. Otherwise, the created **service** will have its **deployment_option** set to **hosted**.

The **applications** and **applicationPlans** are straightforward.

If you are interested in more details, you can have a look at the [3scale-toolbox-jenkins](https://github.com/rh-integration/3scale-toolbox-jenkins/tree/master/src/com/redhat) repository and its [sample code](https://github.com/rh-integration/3scale-toolbox-jenkins-samples).

## OpenAPI Specification file contextualization

In the [ActiveDocs step](#active-docs), we published a static OpenAPI Specification but in order to be usable from the 3scale Developer Portal, this OAS file needs to be contextualized.

The **server** structure needs to be computed from the **publicBasePath** and **publicProductionURL**.

```yaml
servers:
  - url: '${publicProductionURL}${publicBasePath}'
    description: '3scale API Gateway'
```

The **info.title** field can be updated with **environmentName** and API version number (mainly for readability in the 3scale Admin Portal and in the 3scale Developer Portal).

```yaml
info:
  version: "1.2.3"
  title: "${info.title} (${environmentName}, ${info.version})"
```

For OpenID Connect APIs, the global **securityScheme** can be updated with the **token**, **authorization** and **refresh** endpoint URL.

```yaml
components:
  securitySchemes:
    oidc:
      type: oauth2
      flows:
        authorizationCode:
          authorizationUrl: 'https://sso.apps.foo.bar/auth/realms/3scale/protocol/openid-connect/auth'
          tokenUrl: 'https://sso.apps.foo.bar/auth/realms/3scale/protocol/openid-connect/token'
          refreshUrl: 'https://sso.apps.foo.bar/auth/realms/3scale/protocol/openid-connect/token'
          scopes:
            openid: default scope
```

You can compute those URLs from the OIDC Issuer Endpoint.

## Conclusion

In this article we went through all the steps required to deploy an API using only the 3scale Admin REST API.
We also devised design considerations and requirements about idempotence.

If you create a tool based on this article, let me know!
I would be interested to know if it has been useful or if there are missing steps.
