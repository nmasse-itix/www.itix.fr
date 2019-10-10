---
title: "Running Red Hat SSO outside of OpenShift"
date: 2019-10-10T00:00:00+02:00
opensource: 
- Keycloak
---

In an article named [Red Hat Single Sign-On: Give it a try for no cost!](https://developers.redhat.com/blog/2019/02/07/red-hat-single-sign-on-give-it-a-try-for-no-cost/), I explained how to deploy Red Hat SSO very easily in any OpenShift cluster.

As pointed by a reader in a comment, as widespread OpenShift can be, not everyone has access to a running OpenShift cluster. So, here is how to run Red Hat SSO outside of OpenShift: using only plain Docker commands.

The rest of this procedure assumes you already have a token to access the Red Hat registry (full procedure described in [my article](https://developers.redhat.com/blog/2019/02/07/red-hat-single-sign-on-give-it-a-try-for-no-cost/) and in the [Red Hat SSO Getting Started guide, chapter 3, section 3.1](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.3/html/red_hat_single_sign-on_for_openshift/get_started)).

Start by logging in with this token using the *docker login* command (do not forget to replace the login and password with yours):

```sh
docker login -u='1979710|nma-docker' -p=your.token.here registry.redhat.io
```

Confirm your Red Hat registry token is valid by pulling the Red Hat SSO image:

```sh
docker pull registry.redhat.io/redhat-sso-7/sso73-openshift:1.0
```

We can continue by following the official [Red Hat SSO Getting Started guide, chapter 4, section 4.1.2](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.3/html/red_hat_single_sign-on_for_openshift/advanced_concepts#Configuring-Keystores) to create HTTPS and JGroups Keystores, and Truststore:

```sh
mkdir keystore
openssl req -new -newkey rsa:2048 -x509 -keyout keystore/xpaas.key -out keystore/xpaas.crt -days 365 -subj "/CN=localhost" -nodes
keytool -genkeypair -keyalg RSA -keysize 2048 -dname "CN=localhost" -alias jboss -keystore keystore/keystore.jks -storepass secret -keypass secret
keytool -certreq -keyalg rsa -alias jboss -keystore keystore/keystore.jks -file keystore/sso.csr -storepass secret
openssl x509 -req -CA keystore/xpaas.crt -CAkey keystore/xpaas.key -in keystore/sso.csr -out keystore/sso.crt -days 365 -CAcreateserial
keytool -import -file keystore/xpaas.crt -alias xpaas.ca -keystore keystore/keystore.jks -storepass secret -trustcacerts -noprompt
keytool -import -file keystore/sso.crt -alias jboss -keystore keystore/keystore.jks -storepass secret

mkdir jgroups
keytool -genseckey -alias secret-key -storetype JCEKS -keystore jgroups/jgroups.jceks -storepass secret -keypass secret

mkdir truststore
keytool -import -file keystore/xpaas.crt -alias xpaas.ca -keystore truststore/truststore.jks -storepass secret -trustcacerts -noprompt
```

And finally, we can convert the official [Red Hat SSO template](https://github.com/jboss-container-images/redhat-sso-7-openshift-image/blob/sso73-dev/templates/sso73-https.json) to Docker commands:

```sh
docker run --name redhat-sso -m 1Gi \
           -p 8778:8778 -p 8080:8080 -p 8443:8443 -p 8888:8888 \
           -e SSO_HOSTNAME=localhost \
           -e SSO_ADMIN_USERNAME=admin \
           -e SSO_ADMIN_PASSWORD=password \
           -e SSO_REALM=test \
           -e HTTPS_KEYSTORE_DIR=/etc/keystore \
           -e HTTPS_KEYSTORE=keystore.jks \
           -e HTTPS_KEYSTORE_TYPE=jks \
           -e HTTPS_NAME=jboss \
           -e HTTPS_PASSWORD=secret \
           -e JGROUPS_ENCRYPT_KEYSTORE_DIR=/etc/jgroups \
           -e JGROUPS_ENCRYPT_KEYSTORE=jgroups.jceks \
           -e JGROUPS_ENCRYPT_NAME=secret-key \
           -e JGROUPS_ENCRYPT_PASSWORD=secret \
           -e JGROUPS_CLUSTER_PASSWORD=random \
           -e SSO_TRUSTSTORE=truststore.jks \
           -e SSO_TRUSTSTORE_DIR=/etc/truststore \
           -e SSO_TRUSTSTORE_PASSWORD=secret \
           -v $PWD/keystore:/etc/keystore \
           -v $PWD/jgroups:/etc/jgroups \
           -v $PWD/truststore:/etc/truststore \
           registry.redhat.io/redhat-sso-7/sso73-openshift:1.0
```

You should see the Red Hat SSO server logs appearing in your console.
Once the server started successfully, you can connect to the console at **http://localhost:8080/auth/admin** or **https://localhost:8443/auth/admin** and login with *admin* / *password*.

Of course, none of this is endorsed or supported by Red Hat! But for a test run, it's an acceptable tradeoff.
