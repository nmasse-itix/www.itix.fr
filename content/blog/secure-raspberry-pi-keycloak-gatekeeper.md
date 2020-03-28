---
title: "Secure your Raspberry PI with Keycloak Gatekeeper on OpenWRT"
date: 2020-03-28T00:00:00+02:00
opensource: 
- OpenWRT
- Keycloak
---

In the article "[Nginx with TLS on OpenWRT](../nginx-with-tls-on-openwrt/)", I explained how to install nginx on a Raspberry PI running OpenWRT for hosting web applications.
Some of the web applications that I installed on my Raspberry PI do not feature any authentication mechanism at all.
No authentication means that anybody on the internet could reach those applications and play with them.
This article explains how to secure applications running on a Raspberry PI with [Keycloak Gatekeeper](https://github.com/keycloak/keycloak-gatekeeper).

[Keycloak Gatekeeper](https://github.com/keycloak/keycloak-gatekeeper) is a reverse proxy whose sole purpose is to authenticate the end-users using the [OpenID Connect](https://openid.net/connect/) protocol.
If Keycloak Gatekeeper is best used in conjunction with the [Keycloak Identity Provider](https://www.keycloak.org/), it can also be used with any Identity Provider that conforms to the OpenID Connect specifications.

The rest of this article assumes you have already setup your OpenID Connect client in the Google Developer Console as explained in this article: [Use your Google Account as an OpenID Connect provider](../use-google-account-openid-connect-provider).

## Compile Keycloak Gatekeeper

Since the Keycloak community provides no ARM binaries, we need to compile Keycloak Gatekeeper by ourselves.

First, make sure you have Go installed on your workstation, **at least version 1.11**.

```sh
$ go version
go version go1.14.1 darwin/amd64
```

Clone the Keycloak Gatekeeper repository.

```sh
git clone https://github.com/keycloak/keycloak-gatekeeper.git -b 9.0.2
cd keycloak-gatekeeper
```

Compile it for the ARM architecture.

```sh
GIT_SHA=$(git --no-pager describe --always --dirty)
BUILD_TIME=$(date '+%s')
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -a -tags netgo -ldflags " -w -X main.gitsha=$GIT_SHA -X main.compiled=$BUILD_TIME" -o bin/keycloak-gatekeeper
```

## Install Keycloak Gatekeeper

On your Raspberry PI, create a directory hierarchy for Keycloak Gatekeeper.

```sh
mkdir -p /opt/keycloak-gatekeeper/bin /opt/keycloak-gatekeeper/etc
```

Copy Keycloak Gatekeeper on your Raspberry PI.

```sh
scp bin/keycloak-gatekeeper root@raspberry-pi.example.test:/opt/keycloak-gatekeeper/bin/
```

Create a dedicated user for Keycloak Gatekeeper.

```sh
opkg update
opkg install shadow-useradd
useradd -d /opt/keycloak-gatekeeper -s /bin/false -m -r gatekeeper
```

Adjust the directory permissions on **/opt/keycloak-gatekeeper/etc/**.

```sh
chown gatekeeper:root /opt/keycloak-gatekeeper/etc/
chmod 700 /opt/keycloak-gatekeeper/etc/
```

## Configure Keycloak Gatekeeper

In this article, we will secure an "Echo Service" (it echoes back the received request).
This service is named **echo-api.3scale.net**.

```
$ curl http://echo-api.3scale.net/
{
  "method": "GET",
  "path": "/",
  "args": "",
  "body": "",
  "headers": {
    "HTTP_VERSION": "HTTP/1.1",
    "HTTP_HOST": "echo-api.3scale.net",
    "HTTP_ACCEPT": "*/*",
    "HTTP_USER_AGENT": "curl/7.64.1",
    "HTTP_X_FORWARDED_FOR": "90.79.1.247, 10.0.103.119",
    "HTTP_X_FORWARDED_HOST": "echo-api.3scale.net",
    "HTTP_X_FORWARDED_PORT": "80",
    "HTTP_X_FORWARDED_PROTO": "http",
    "HTTP_FORWARDED": "for=10.0.103.119;host=echo-api.3scale.net;proto=http"
  },
  "uuid": "3ac98e47-8895-4b36-9f27-c4cf5d40d5e9"
}
```

Start by creating a file named **echo.yaml** under **/opt/keycloak-gatekeeper/etc/**.

```yaml
client-id: <YOUR CLIENT_ID>.apps.googleusercontent.com
client-secret: <YOUR CLIENT_SECRET>
discovery-url: https://accounts.google.com/.well-known/openid-configuration
listen: 0.0.0.0:3000
redirection-url: http://raspberry-pi.example.test:3000
encryption-key: <CHANGE ME>
secure-cookie: false
upstream-url: http://echo-api.3scale.net
resources:
- uri: /
enable-refresh-tokens: true
```

Of course, you will have to put your Client ID and Client Secret in the **client-id** and **client-secret** fields.
You will also need to edit the **redirection-url** so that it matches your Raspberry PI hostname (do not forget the port!).

You can generate an encryption key using the following command. Copy the output of this command and paste it in the **encryption-key** field.

```sh
openssl rand -base64 24
```

## Test your configuration

Connect to the [Google Developer Console](https://console.developers.google.com/projectselector2/apis/dashboard?organizationId=0) and add a Redirect URI to your existing OpenID Connect client (pick your project > **Credentials** > click your **OAuth 2.0 client**).

If the **redirection-url** field in the Keycloak Gatekeeper configuration is:

```
http://raspberry-pi.example.test:3000
```

Then, you need to add the following **Authorized redirect URI** in the Google Developer Console:

```
http://raspberry-pi.example.test:3000/oauth/callback
```

Start Keycloak Gatekeeper manually.

```sh
/opt/keycloak-gatekeeper/bin/keycloak-gatekeeper --config /opt/keycloak-gatekeeper/etc/echo.yaml
```

From your web browser, connect to the port 3000 of your Raspberry PI using the **http** protocol.
You should be redirected to the Google Login page and once logged in or if already logged in, you should see the Echo API (output edited for brevity).

```json
{
  "method": "GET",
  "path": "/",
  "args": "",
  "body": "",
  "headers": {
    "HTTP_VERSION": "HTTP/1.1",
    "HTTP_HOST": "echo-api.3scale.net",
    "HTTP_AUTHORIZATION": "Bearer eyJ...",
    "HTTP_COOKIE": "request_uri=Lw==; OAuth_Token_Request_State=dbb1cafa-3cca-4ffc-ac2d-ff6b14593e34; kc-access=eyJ...",
    "HTTP_X_AUTH_AUDIENCE": "942727606324-fvavcr2fld4t5o0f84s76vrodgcp9vmq.apps.googleusercontent.com",
    "HTTP_X_AUTH_EMAIL": "nicolas DOT masse AT itix.fr",
    "HTTP_X_AUTH_EXPIRESIN": "2020-03-28 19:21:37 +0000 UTC",
    "HTTP_X_AUTH_GROUPS": "",
    "HTTP_X_AUTH_ROLES": "",
    "HTTP_X_AUTH_SUBJECT": "114331641802984310666",
    "HTTP_X_AUTH_TOKEN": "eyJ...",
    "HTTP_X_AUTH_USERID": "nicolas DOT masse AT itix.fr",
    "HTTP_X_AUTH_USERNAME": "nicolas DOT masse AT itix.fr",
  },
  "uuid": "e5dcf957-60d3-41a8-a888-2752c62b08a2"
}
```

If your web browser displays a JSON document containing some **HTTP_X\_AUTH\_\*** headers, your setup is working! Those headers are added by Keycloak Gatekeeper once the user is authenticated.

## Add restrictions on who can access the target service

So far, we configured Keycloak Gatekeeper to enforce authentication of the end-user.
But we have not yet configured any check regarding the identity of the end-user.
So, any user having a GMail account can access the target service.

Let's fix this.

If you have a Google Suite with a custom domain, you can add to the Keycloak Gatekeeper configuration file (**itix.fr** being the Google Suite domain):

```yaml
match-claims:
  hd: ^itix.fr$
```

With this additional configuration, only users of your Google Suite will be able to connect.

If you are a regular GMail user, you can enforce a check on your exact email address by adding to the Keycloak Gatekeeper configuration file:

```yaml
match-claims:
  email: ^john\.doe@gmail\.com$
```

**Note:** the matches are [regular expressions](https://en.wikipedia.org/wiki/Regular_expression).

Restart Keycloak Gatekeeper and verify that the restrictions you put on the end-user identity is actually enforced.

## Put Keycloak Gatekeeper behind nginx

As explained in the article "[Nginx with TLS on OpenWRT](../nginx-with-tls-on-openwrt/)", I am using nginx to host several web applications on my Raspberry PI.
Since nginx is the entrypoint to access any web application on my Raspberry PI, I need to put Keycloak Gatekeeper behind nginx.

In the nginx configuration file, add a virtual host.

```
server {
    listen 443 ssl;
    server_name echo.pi.example.test;

    ssl_certificate /path/to/crt;
    ssl_certificate_key /path/to/key;
    // add the usual ssl_* directives here...

    location / {
        proxy_pass http://127.0.0.1:3000;
    }
}
```

The important parts of this configuration are:

* the virtual host listens on port 443 and handles TLS
* it forwards the requests to the Keycloak Gatekeeper on port 3000
* the hostname of this virtual host is **echo.pi.example.test**

Then, we need to modify the Keycloak Gatekeeper configuration accordingly. Only altered fields are listed below.

```yaml
listen: 127.0.0.1:3000
secure-cookie: true
redirection-url: https://echo.pi.example.test
```

The important parts of this configuration are:

* Cookies now have the secure flag (since nginx will serves requests over HTTPS).
* The listen address is now 127.0.0.1 to enforce nginx as the main entry point.
* The Redirect URI has been updated to reflect the virtual host hostname and port.

And finally, we need to update the **Authorized redirect URIs** in the Google Developer Console.

```
https://echo.pi.example.test/oauth/callback
```

Restart nginx.

```sh
service nginx restart
```

## Finish the configuration

Create an init script named **gatekeeper-echo** under **/etc/init.d**

```sh
#!/bin/sh /etc/rc.common

START=80
USE_PROCD=1

start_service() {
  procd_open_instance
  procd_set_param command /opt/keycloak-gatekeeper/bin/keycloak-gatekeeper --config /opt/keycloak-gatekeeper/etc/echo.yaml
  procd_set_param file /opt/keycloak-gatekeeper/etc/echo.yaml
  procd_set_param respawn
  procd_close_instance
}
```

Make it executable.

```sh
chmod 755 /etc/init.d/gatekeeper-echo
```

Enable and start the service.

```sh
service gatekeeper-echo enable
service gatekeeper-echo start
```

## Conclusion

This article explained how to compile, install and configure Keycloak Gatekeeper to secure applications running on a Raspberry PI. The application we secured was an "Echo Service" to keep things simple, but any application can be secured that way.
