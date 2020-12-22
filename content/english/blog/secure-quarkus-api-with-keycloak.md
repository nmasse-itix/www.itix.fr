---
title: "Secure a Quarkus API with Keycloak"
date: 2020-03-17T00:00:00+02:00
opensource: 
- Keycloak
- Quarkus
topics:
- OpenID Connect
---

[Quarkus](https://quarkus.io/) is a Java stack that is Kubernetes native, lightweight and fast.
Quarkus can be used for any type of backend development, including API-enabled backends.
[Keycloak](https://www.keycloak.org/) is an open source Single Sign On solution that can be used to secure APIs.

In this article, I'm describing how to secure a Quarkus API with Keycloak using JWT tokens.

## Preparation

As a pre-requisite, install [Maven](https://maven.apache.org/), [jq](https://stedolan.github.io/jq/download/) and [jwt-cli](https://github.com/mike-engel/jwt-cli#installation).

Create a Quarkus project using either [code.quarkus.io](https://code.quarkus.io/) or Maven. Example shown below with Maven.

```sh
mvn io.quarkus:quarkus-maven-plugin:1.2.0.Final:create \
    -DprojectGroupId=fr.itix.test \
    -DprojectArtifactId=secured-rest \
    -DclassName="fr.itix.test.SecuredResource"
```

Enter the created directory.

```sh
cd secured-rest
```

## Install and configure Keycloak

Download Keycloak and install it locally.

```sh
curl -L -o keycloak.tgz https://downloads.jboss.org/keycloak/9.0.0/keycloak-9.0.0.tar.gz
tar zxvf keycloak.tgz
mv keycloak-* keycloak
```

Create the Keycloak admin user.

```sh
./keycloak/bin/add-user-keycloak.sh -u admin -r master -p secret
```

Start the Keycloak server.

```sh
nohup ./keycloak/bin/standalone.sh -Djboss.socket.binding.port-offset=100 &
```

Quickly, the Keycloak admin console should be available at [localhost:8180/auth/admin/](http://localhost:8180/auth/admin/). The login is **admin** and password is **secret**.

In the rest of this section, we will configure Keycloak with:

* a realm named **demo**
* a client named **quarkus-app**
* a user named **jdoe**
* two groups named **user** and **admin**

Authenticate as admin on Keycloak using the **kcadm** CLI.

```sh
./keycloak/bin/kcadm.sh config credentials --server http://localhost:8180/auth --realm master --user admin --client admin-cli --password secret
```

Create a realm named **demo**.

```sh
./keycloak/bin/kcadm.sh create realms -s realm=demo -s enabled=true -o
```

Create a client named **quarkus-app**.

```sh
./keycloak/bin/kcadm.sh create clients -r demo -s 'clientId=quarkus-app' -s 'standardFlowEnabled=false' -s 'directAccessGrantsEnabled=true' -s 'serviceAccountsEnabled=true' -s 'clientAuthenticatorType=client-secret' -s 'secret=s3cr3t'
```

The framework used by Quarkus to implement security is based on [Eclipse MicroProfile - JWT RBAC Security (MP-JWT)](https://www.eclipse.org/community/eclipse_newsletter/2017/september/article2.php) and requires a claim named **groups** to hold the group membership.

So, we need to create a **custom protocol mapper** to map the user's client role mapping to the **groups** claim.

```sh
CLIENT_ID="$(./keycloak/bin/kcadm.sh get clients -r demo -q clientId=quarkus-app |jq -r '.[0].id')"

./keycloak/bin/kcadm.sh create clients/$CLIENT_ID/protocol-mappers/models -r demo -f - <<EOF
{
  "name": "groups",
  "protocol":"openid-connect",
  "protocolMapper": "oidc-usermodel-client-role-mapper",
  "consentRequired": false,
  "config": {
    "multivalued": "true",
    "userinfo.token.claim": "true",
    "id.token.claim": "true",
    "access.token.claim": "true",
    "claim.name": "groups",
    "jsonType.label": "String",
    "usermodel.clientRoleMapping.clientId": "quarkus-app"
  }
}
EOF
```

Create two client roles in the **quarkus-app** client.

```sh
./keycloak/bin/kcadm.sh create clients/$CLIENT_ID/roles -r demo -s name=user -s 'description=Can access the application'
./keycloak/bin/kcadm.sh create clients/$CLIENT_ID/roles -r demo -s name=admin -s 'description=Can administer the application'
```

Create a user named **jdoe** and set its password to something easy to remember.

```sh
./keycloak/bin/kcadm.sh create users -r demo -s username=jdoe -s enabled=true -s firstName=John -s lastName=Doe
./keycloak/bin/kcadm.sh set-password -r demo --username jdoe --new-password password123
```

Give this user the client role **user**.

```sh
./keycloak/bin/kcadm.sh add-roles -r demo --uusername jdoe --cclientid quarkus-app --rolename user
```

Now Keycloak should be ready to secure your Quarkus API!

## Secure the Quarkus API with Keycloak

Add the [quarkus-smallrye-jwt](https://quarkus.io/guides/security-jwt) extension to the Quarkus project.

```sh
./mvnw quarkus:add-extension -Dextension="quarkus-smallrye-jwt"
```

Configure the jwt extension to fetch the OpenID Connect Public Keys from Keycloak (**mp.jwt.verify.publickey.location**), enforce a validation of the issuer, preferred_username, and audience fields.
That way, Quarkus takes care of validating the token for us.

```sh
cat > src/main/resources/application.properties <<EOF
mp.jwt.verify.publickey.location=http://localhost:8180/auth/realms/demo/protocol/openid-connect/certs
mp.jwt.verify.issuer=http://localhost:8180/auth/realms/demo
smallrye.jwt.verify.audience=quarkus-app
smallrye.jwt.require.named-principal=true
EOF
```

Replace `src/main/java/fr/itix/test/SecuredResource.java` with:

```java
package fr.itix.test;

import java.security.Principal;

import javax.annotation.security.PermitAll;
import javax.annotation.security.RolesAllowed;
import javax.enterprise.context.RequestScoped;
import javax.inject.Inject;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.WebApplicationException;
import javax.ws.rs.core.Context;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.SecurityContext;
import javax.ws.rs.core.Response.Status;

import org.eclipse.microprofile.jwt.Claim;
import org.eclipse.microprofile.jwt.Claims;

@Path("/api")
@RequestScoped
public class SecuredResource {
    @Inject @Claim(standard = Claims.preferred_username)
    String username;

    @GET
    @Path("/helloEverybody")
    @Produces(MediaType.TEXT_PLAIN)
    @PermitAll
    public String helloEverybody() {
        return "Hello everybody !";
    }

    @GET
    @Path("/hello")
    @Produces(MediaType.TEXT_PLAIN)
    public String hello(@Context SecurityContext ctx) {
        String name = "dear unknown visitor";
        Principal caller =  ctx.getUserPrincipal();
        if (caller != null) {
            name = caller.getName();
        }

        return "hello " + name;
    }

    @GET
    @Path("/helloUsers")
    @Produces(MediaType.TEXT_PLAIN)
    @RolesAllowed({"user"})
    public String helloUsers() {
        return "hello user " + username;
    }

    @GET
    @Path("/helloAdmins")
    @Produces(MediaType.TEXT_PLAIN)
    @RolesAllowed({"admin"})
    public String helloAdmins() {
        return "hello admin " + username;
    }
}
```

This class defines four HTTP endpoints:

* **/api/helloEverybody** does not require any authentication at all.
* **/api/hello** tries to authenticate the user and falls back gracefully when no JWT is provided.
* **/api/helloUsers** requires authentication and applies RBAC: the user needs to have the **user** role.
* **/api/helloAdmins** requires authentication and applies RBAC: the user needs to have the **admin** role.

Run the quarkus project in dev mode.

```sh
./mvnw compile quarkus:dev
```

## Query the Quarkus API

In another terminal, ensure the **/api/helloEverybody** endpoint is working and reachable without security.

```
$ curl http://localhost:8080/api/helloEverybody
Hello everybody !
```

You can query the **/api/hello** endpoint without any authentication.

```
$ curl http://localhost:8080/api/hello
hello dear unknown visitor
```

Now, get a token from Keycloak for user **jdoe**.

```sh
TOKEN="$(curl http://localhost:8180/auth/realms/demo/protocol/openid-connect/token -d grant_type=password -d client_id=quarkus-app -d client_secret=s3cr3t -d username=jdoe -d password=password123 -s |jq -r .access_token)"
```

When you display the issued token, it contains the standard OpenID Connect claims as well as the **groups** claim as instructed by our custom protocol mapper.

```
$ jwt decode "$TOKEN"

Token header
------------
{
  "typ": "JWT",
  "alg": "RS256",
  "kid": "dCsrXmzTBFDbrXqd-paTe9rSti43lHSSrjqbdcAN9IM"
}

Token claims
------------
{
  "acr": "1",
  "aud": "account",
  "auth_time": 0,
  "azp": "quarkus-app",
  "email_verified": false,
  "exp": 1584454157,
  "family_name": "Doe",
  "given_name": "John",
  "groups": [
    "user"
  ],
  "iat": 1584453857,
  "iss": "http://localhost:8180/auth/realms/demo",
  "jti": "49e5a792-8c36-4202-bd37-7d06fa799fa4",
  "name": "John Doe",
  "nbf": 0,
  "preferred_username": "jdoe",
  "realm_access": {
    "roles": [
      "offline_access",
      "uma_authorization"
    ]
  },
  "resource_access": {
    "account": {
      "roles": [
        "manage-account",
        "manage-account-links",
        "view-profile"
      ]
    },
    "quarkus-app": {
      "roles": [
        "user"
      ]
    }
  },
  "scope": "email profile",
  "session_state": "659d4c51-36a9-4bdc-ba4b-2ea84f3390cb",
  "sub": "0e83418b-0635-435e-9bac-dd3d3b87cba4",
  "typ": "Bearer"
}
```

If you provide a JWT token, the API will update its greeting message accordingly.

```
$ curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/hello
hello jdoe
```

When setting up Keycloak, we added **jdoe** to the **user** group. So, you should be able to query the **/api/helloUsers** endpoint.

```
$ curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/helloUsers
hello user jdoe
```

But you cannot *yet* query the **/api/helloAdmins** endpoint.

```
$ curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/helloAdmins
Forbidden
```

Give **jdoe** the client role **admin**.

```sh
./keycloak/bin/kcadm.sh add-roles -r demo --uusername jdoe --cclientid quarkus-app --rolename admin
```

Get a new token from Keycloak for user **jdoe**.

```sh
TOKEN="$(curl http://localhost:8180/auth/realms/demo/protocol/openid-connect/token -d grant_type=password -d client_id=quarkus-app -d client_secret=s3cr3t -d username=jdoe -d password=password123 -s |jq -r .access_token)"
```

You can *now* query the **/api/helloAdmins** endpoint.

```
$ curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/helloAdmins
hello admin jdoe
```

And this concludes this article on how to secure a Quarkus API with Keycloak!
