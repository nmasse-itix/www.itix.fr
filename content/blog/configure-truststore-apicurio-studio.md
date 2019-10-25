---
title: "Configure the TLS trust store in Apicurio Studio"
date: 2019-10-25T00:00:00+02:00
opensource: 
- Apicurio
- Microcks
---

[Microcks](http://microcks.github.io) and [Apicurio](https://www.apicur.io/) are nice Open Source projects that can even talk to each other to deliver greater value than the sum of their parts.

Unfortunately, sometimes TLS certificates can get in the way of proper communication between the two projects.
This post explains how to configure the trust store in Apicurio to overcome TLS communication issues between Apicurio and Microcks.

Start by gathering the CA certificates used in your company. There can be several ones.

You can then create a trust store by running this command for each CA certificate to import:

```sh
keytool -import -file root-ca-certificate.crt -alias root-ca -keystore truststore.jks -storepass secret -trustcacerts -noprompt
```

Once your trust store is created, you can import it as a secret in the OpenShift project in which you deployed Apicurio.

```sh
oc create secret generic apicurio-truststore --from-file=truststore.jks
```

Then, update the *apicurio-studio-api* Deployment Config to mount this secret in */trust*:

```sh
oc set volume dc/apicurio-studio-api --add -m /trust --name truststore -t secret --secret-name=apicurio-truststore
```

Finally, patch the *apicurio-studio-api* Deployment Config to load this truststore:

```sh
oc patch dc/apicurio-studio-api -p '{"spec":{"template":{"spec":{"containers":[{"name":"apicurio-studio-api","args":["/bin/sh","-c","java -jar /opt/apicurio/apicurio-studio-api-thorntail.jar     -Xms${APICURIO_MIN_HEAP}     -Xmx${APICURIO_MAX_HEAP}     -Dthorntail.port.offset=${APICURIO_PORT_OFFSET}     -Dthorntail.datasources.data-sources.ApicurioDS.driver-name=${APICURIO_DB_DRIVER_NAME}     -Dthorntail.datasources.data-sources.ApicurioDS.connection-url=${APICURIO_DB_CONNECTION_URL}     -Dthorntail.datasources.data-sources.ApicurioDS.user-name=${APICURIO_DB_USER_NAME}     -Dthorntail.datasources.data-sources.ApicurioDS.password=${APICURIO_DB_PASSWORD}     -Dthorntail.datasources.data-sources.ApicurioDS.valid-connection-checker-class-name=${APICURIO_DB_VALID_CONNECTION_CHECKER_CLASS_NAME}     -Dthorntail.datasources.data-sources.ApicurioDS.validate-on-match=${APICURIO_DB_VALID_ON_MATCH}     -Dthorntail.datasources.data-sources.ApicurioDS.background-validation=${APICURIO_DB_BACKGROUND_VALIDATION}     -Dthorntail.datasources.data-sources.ApicurioDS.exception-sorter-class-name=${APICURIO_DB_EXCEPTION_SORTER_CLASS_NAME}     -Dapicurio.hub.storage.jdbc.init=${APICURIO_DB_INITIALIZE}     -Dapicurio.hub.storage.jdbc.type=${APICURIO_DB_TYPE}     -Dapicurio.kc.auth.rootUrl=${APICURIO_KC_AUTH_URL}     -Dapicurio.kc.auth.realm=${APICURIO_KC_REALM}     -Dthorntail.logging=${APICURIO_LOGGING_LEVEL} -Djavax.net.ssl.trustStore=/trust/truststore.jks -Djavax.net.ssl.trustStorePassword=secret"]}]}}}}'
```

The important part of this command line is at the end:

- `-Djavax.net.ssl.trustStore=/trust/truststore.jks`
- `-Djavax.net.ssl.trustStorePassword=secret`

Of course, if you are using a different password or a different filename, you will have to update the patch command accordingly.
