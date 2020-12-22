---
title: "What is this 'Anonymous' policy configured by the 3scale toolbox?"
date: 2019-11-14T00:00:00+02:00
opensource:
- 3scale
topics:
- API Management
---

In this article on the Red Hat Developer blog, I explained [how to deploy an API from the CLI, using the 3scale toolbox](https://developers.redhat.com/blog/2019/07/29/3scale-toolbox-deploy-an-api-from-the-cli/).
If you tried this approach by yourself you may end up, *sooner or later*, with a 3scale service including an *Anonymous* policy in its policy chain.
What is this policy and why is it there?
Let's dig in!

<!--more-->

In a nutshell, the *Anonymous* policy instruct the *APIcast* gateway to expose an API **without any security mechanism**.
Given how we stress out the importance of security in our very fragile IT systems, this calls out the following question: why was it there in the first place?

The answer is simple: **because you instructed the 3scale toolbox to do so!**

Let's describe a very important step in the inner working of the toolbox. When importing an API from an OpenAPI Specification file, the toolbox is inspecting the provided OpenAPI Specification file to determine which security protocols are mandated by the API Contract (and then configures 3scale accordingly).

The toolbox is looking first for a global security requirement (the *security* field in the following example). From this global security requirement, the toolbox searches for the matching security definition (in the *securityDefinitions* field).

In [the following OpenAPI Specification file](https://github.com/rh-integration/3scale-toolbox-jenkins-samples/blob/master/saas-usecase-apikey/swagger.yaml), a global security requirement named *api-key* is defined and backed by a security definition having the same name.

```yaml
swagger: '2.0'
info:
  title: 'Beer Catalog API'
  [...]
paths:
  [...]
securityDefinitions:
  api-key:
    type: apiKey
    name: api-key
    in: header
security:
  - api-key: []
```

This security definition mandates the following: "to use this API, the consumer will have to provide an API Key (*type: apiKey*) in an HTTP header named *api-key*".

You could mandate using OpenID Connect security instead, by specifying the following security requirements in [your OpenAPI Specification file](https://github.com/rh-integration/3scale-toolbox-jenkins-samples/blob/master/hybrid-usecase-oidc/swagger.json), and the toolbox would configure your API in 3scale using OpenID Connect instead of API Key.

```yaml
securityDefinitions:
  oidc:
    type: oauth2,
    flow: application
    tokenUrl: https://filled-later.dummy/token
    scopes:
      openid: Get an OpenID Connect token
security:
  oidc:
  - openid
```

If the toolbox finds no global security requirement, it concludes that you are trying to provision an *Open API* (an API usable without any credentials) and thus setups the required Anonymous policy for you.

An *Open API* is a legit option in some business use cases:

- The Public sector, when exposing Open Data.
- The Retail sector, when exposing a list of stores.
- More broadly, when it's part of your API Strategy. For instance, a subset of the GitHub API is open so that it can be included in all the Open Source CLI tools and thus reinforces the GitHub's leading position.

## Conclusion

To summarize, the *Anonymous* Policy is a way to expose an *Open API* in 3scale.
It is added automatically by the 3scale toolbox **when no global security requirement is present in the OpenAPI Specification file** you are trying to import.

## Further exploration

If you want to continue exploring this topic, you can try by yourself the following examples.

Add a *remote* in the 3scale toolbox configuration.

```sh
3scale remote add 3scale-instance https://${TOKEN}@${TENANT}-admin.3scale.net
```

Import an OpenAPI Specification file that contains no security requirements.

```sh
3scale import openapi -d 3scale-instance --default-credentials-userkey=test --override-private-base-url=http://echo-api.3scale.net -t toolbox_open_api https://raw.githubusercontent.com/rh-integration/3scale-toolbox-jenkins-samples/master/hybrid-usecase-open/swagger.json
```

Confirm your API has been imported as an *Open API*: it contains the *Anonymous* policy.

{{< highlight raw "hl_lines=4-11" >}}
$ curl -s "https://${TENANT}-admin.3scale.net/admin/api/nginx/spec.json?access_token=${TOKEN}"|jq '.services[]|select(.system_name == "toolbox_open_api")|.proxy.policy_chain'

[
  {
    "name": "default_credentials",
    "version": "builtin",
    "configuration": {
      "auth_type": "user_key",
      "user_key": "test"
    }
  },
  {
    "name": "apicast",
    "version": "builtin",
    "configuration": {}
  }
]
{{< / highlight >}}

Now, import an OpenAPI Specification file that contains a global security requirement **mandating API Key security**.

```sh
3scale import openapi -d 3scale-instance --override-private-base-url=http://echo-api.3scale.net -t toolbox_apikey https://raw.githubusercontent.com/rh-integration/3scale-toolbox-jenkins-samples/master/saas-usecase-apikey/swagger.yaml
```

Confirm your API **does not contain the *Anonymous* policy**.

```raw
$ curl -s "https://${TENANT}-admin.3scale.net/admin/api/nginx/spec.json?access_token=${TOKEN}"|jq '.services[]|select(.system_name == "toolbox_apikey")|.proxy.policy_chain'

[
  {
    "name": "apicast",
    "version": "builtin",
    "configuration": {}
  }
]
```
