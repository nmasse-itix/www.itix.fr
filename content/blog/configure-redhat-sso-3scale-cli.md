---
title: "Configure Red Hat SSO for 3scale using the CLI!"
date: 2020-04-08T00:00:00+02:00
opensource: 
- 3scale
- keycloak
---

[3scale API Management](https://3scale.github.io/) can be used in conjunction with [Red Hat SSO](https://access.redhat.com/products/red-hat-single-sign-on) / [Keycloak](https://www.keycloak.org/) to secure APIs managed by 3scale using the OpenID Connect protocol.

The [official documentation](https://access.redhat.com/documentation/en-us/red_hat_3scale_api_management/2.8/html/administering_the_api_gateway/openid-connect#configure_red_hat_single_sign_on) describes the steps to configure Red Hat SSO / Keycloak but it uses the Graphical User Interface, which can be tedious if you have multiple environments to configure. Let's configure Red Hat SSO for 3scale using the CLI!

As a pre-requisite, install [jq](https://stedolan.github.io/jq/download/).

Fetch the hostname, login and password of your Red Hat SSO instance, from your OpenShift environment.

```sh
eval $(oc set env dc/sso --list |egrep '^SSO_(ADMIN|HOSTNAME)')
```

Alternatively, if you deployed Red Hat SSO outside of OpenShift you can set those variables manually.

```sh
SSO_HOSTNAME=sso.myserver.test
SSO_ADMIN_USERNAME=admin
SSO_ADMIN_PASSWORD=s3cr3t
```

**Note:** According to [Red Hat Single Sign-On Component Details](https://access.redhat.com/articles/2342881), Red Hat SSO 7.3 is based on Keycloak 4.8.15. So, we will install the closest available version of the Keycloak CLI (**kcadm.sh**).

Install kcadm.sh from the Keycloak 4.8 distibution.

```sh
curl -L -o keycloak.tgz https://downloads.jboss.org/keycloak/4.8.3.Final/keycloak-4.8.3.Final.tar.gz
tar zxvf keycloak.tgz
mv keycloak-* /usr/local/share/keycloak/
export PATH="/usr/local/share/keycloak/bin:$PATH"
```

Authenticate to the Red Hat SSO server.

```sh
kcadm.sh config credentials --server "https://$SSO_HOSTNAME/auth" --realm master --user "$SSO_ADMIN_USERNAME" --client admin-cli --password "$SSO_ADMIN_PASSWORD"
```

Create the **3scale** realm.

```sh
REALM=3scale
kcadm.sh create realms -s realm=$REALM -s enabled=true
```

Create a client named **zync**, type **confidential** and with a chosen client secret: **s3cr3t**.

```sh
kcadm.sh create clients -r $REALM -s 'clientId=zync' -s 'standardFlowEnabled=false' -s 'directAccessGrantsEnabled=false' -s 'serviceAccountsEnabled=true' -s 'clientAuthenticatorType=client-secret' -s 'secret=s3cr3t'
```

Now, we need to find the id of the **zync** client, the **realm-management** client and **zync** service account.

```sh
ZYNC_CLIENT_ID="$(kcadm.sh get clients -r $REALM -q clientId=zync |jq -r '.[0].id')"
RM_CLIENT_ID="$(kcadm.sh get clients -r $REALM -q clientId=realm-management |jq -r '.[0].id')"
ZYNC_USER_ID="$(kcadm.sh get clients/$ZYNC_CLIENT_ID/service-account-user -r $REALM |jq -r '.id')"
```

Then, we need to add the **realm-management/manage-clients** client role to the **zync** service account.
This is achieved by fetching the client role definition of the **realm-management** client, filtering out everyting except the **manage-clients** role and piping everything to the **kcadm.sh create** command.

```sh
kcadm.sh get clients/$RM_CLIENT_ID/roles -q name=manage-clients -r $REALM |jq -r '[ .[] | select(.name == "manage-clients") ]' | kcadm.sh create users/$ZYNC_USER_ID/role-mappings/clients/$RM_CLIENT_ID -r $REALM -f -
```

You can verify the client role has been assigned successfully with the following command. 

```
$ kcadm.sh get users/$ZYNC_USER_ID/role-mappings/clients/$RM_CLIENT_ID -r $REALM
[ {
  "id" : "08392afe-8ef1-476d-a30c-5943ac5d7f3b",
  "name" : "manage-clients",
  "description" : "${role_manage-clients}",
  "composite" : false,
  "clientRole" : true,
  "containerId" : "61ce88e6-3fb7-41ac-b588-ae3f3aaa8630"
} ]
```

Then, in the 3scale Admin Portal, pick a product and drill down to **Integration** > **Settings**.
You can use the following URL for the **OpenID Connect Issuer** (replace $SSO_HOSTNAME with its actual value).

```
https://zync:s3cr3t@$SSO_HOSTNAME/auth/realms/3scale
```

![openid-connect-issuer](openid-connect-issuer.png)

Or when [deploying an API in 3scale with the 3scale toolbox](https://developers.redhat.com/blog/2019/07/29/3scale-toolbox-deploy-an-api-from-the-cli/), you can use:

```sh
3scale import openapi -d 3scale-saas --oidc-issuer-endpoint=https://zync:s3cr3t@$SSO_HOSTNAME/auth/realms/3scale /path/to/openapi.yaml
```

In this article, we discovered how to configure Red Hat SSO for 3scale using the CLI!
