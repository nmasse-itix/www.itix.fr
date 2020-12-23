---
title: "What is this 'URL Rewriting' policy configured by the 3scale toolbox?"
date: 2019-11-14T00:00:00+02:00
opensource: 
- 3scale
topics:
- API Management
---

In this article on the Red Hat Developer blog, I explained [how to deploy an API from a Jenkins Pipeline, using the 3scale toolbox](https://developers.redhat.com/blog/2019/07/30/deploy-your-api-from-a-jenkins-pipeline/).
If you tried this approach by yourself you may have noticed that in some cases, the configured service includes the *URL Rewriting* policy in its *Policy Chain*.

<!--more-->

The *URL Rewriting* policy can be used for a variety of use cases but, in a nutshell, the *URL Rewriting* policy is used by the toolbox to change the *Base Path* of an API.

For instance, if your actual API implementation is live at **/camel/my-route** but you wish to expose it on **/api/v1**, you can instruct the 3scale toolbox to configure the *URL Rewriting* policy for you by specifying the `--override-private-basepath` and `--override-public-basepath` options.

By default, the public and private basepath have the same value and are taken from the OpenAPI Specification file (the field *basePath*). If the basePath field is missing, the default value is "/".

Let's examine a concrete example.
You have an actual API implementation live at **/camel/my-route** and an API contract as follow:

{{< highlight yaml "hl_lines=5" >}}
swagger: '2.0'
info:
  title: 'Beer Catalog API'
  [...]
basePath: /camel/my-route
[...]
{{< / highlight >}}

If you wish to expose it publicly *as-is* on **/camel/my-route**, there is nothing special to do, the toolbox will do the right thing.

But if you want to expose it publicly on **/api/v1**, you will have to pass the following option to the *3scale import openapi* command:

```raw
--override-public-basepath=/api/v1
```

Let's examine another example.
You have an API contract stating that you want to expose your API publicly on **/api/v1**

{{< highlight yaml "hl_lines=5" >}}
swagger: '2.0'
info:
  title: 'Beer Catalog API'
  [...]
basePath: /api/v1
[...]
{{< / highlight >}}

If unfortunately your API backend is live at another *Base Path* (**/camel/my-route**), you will have to pass the following option to the *3scale import openapi* command:

```raw
--override-private-basepath=/camel/my-route
```

And if your API contract specifies neither the public nor the private *Base Path*? Or a dummy *Base Path*?

In that specific case, you will have to pass both options to the *3scale import openapi* command:

```raw
--override-public-basepath=/api/v1 --override-private-basepath=/camel/my-route
```
