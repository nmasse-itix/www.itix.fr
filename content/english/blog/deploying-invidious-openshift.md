---
title: "Deploying Invidious on OpenShift"
date: 2019-11-16T00:00:00+02:00
opensource: 
- OpenShift
- Invidious
topics:
- Containers
---

[Invidious](https://github.com/omarroth/invidious) is an alternative frontend to YouTube that is slimmer, faster and at the same time offer more features than YouTube itself. And even more important: it's Open Source!

There is a hosted instance at [invidio.us](https://invidio.us/) if you want to give it a try. But, wouldn't it be cooler to host your own instance on your OpenShift cluster? Let's do it!

<!--more-->

Create a new project.

```sh
oc new-project invidious --display-name=Invidious
```

Provision a PostgreSQL database instance, as required by Invidious.

```sh
oc new-app --name=postgresql --template=postgresql-persistent \
           -p POSTGRESQL_USER=kemal \
           -p POSTGRESQL_PASSWORD=secret \
           -p POSTGRESQL_DATABASE=invidious
```

Because the database needs to be initialized with the Invidious schema, we need to create an initialization script ([based on the one provided by the community](https://github.com/omarroth/invidious/blob/e56129111a5d182ddfcc75935c1222cc11e46234/docker/entrypoint.postgres.sh#L13-L24)).

Checkout the Invidious GIT repository (replace *0.20.0* with the Invidious version you want to deploy).

```sh
git clone https://github.com/omarroth/invidious -b 0.20.0
```

And create the init script *start.sh* in *config/sql*.

```sh
cd invidious/config/sql
cat <<"EOF" > start.sh
echo ">>> Starting database schema creation"
set +e
for f in channels videos channel_videos users \
         session_ids nonces annotations privacy \
         playlists playlist_videos; do

  psql $POSTGRESQL_DATABASE $POSTGRESQL_USER \
       -f $APP_DATA/src/postgresql-start/$f.sql
done
set -e
echo "<<< Finished database schema creation"
EOF
```

Provision the initialization script plus all the SQL files as a Config Map and mount it on the PostgreSQL pod in */opt/app-root/src/postgresql-start*.

```sh
oc create configmap postgresql-init --from-file=.
oc set volume dc/postgresql --add -t configmap --name postgresql-init \
                            --configmap-name=postgresql-init \
                            -m /opt/app-root/src/postgresql-start
```

Because of a <s>bug</s> feature in the [PostgreSQL base image](https://github.com/sclorg/postgresql-container) (see [#351](https://github.com/sclorg/postgresql-container/issues/351)), we need to hack a little bit the PostgreSQL image.

```sh
cat <<"EOF" > /tmp/common.sh
#!/bin/bash

export CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/postgresql
. /usr/share/container-scripts/postgresql/common.sh

# Replace the get_matched_files function from common.sh
# with a patched version that fixes #351
get_matched_files ()
{
  local pattern=$1 dir
  shift
  for dir; do
    test -d "$dir" || continue
    # see https://github.com/sclorg/postgresql-container/issues/351
    find -L "$dir" -maxdepth 1 -type f -name "$pattern" -printf "%f\n"
  done
}
EOF

oc create configmap postgresql-hack --from-file=/tmp/common.sh
oc set volume dc/postgresql --add -t configmap --name postgresql-hack \
                            --configmap-name=postgresql-hack \
                            -m /opt/custom
oc set env dc/postgresql CONTAINER_SCRIPTS_PATH=/opt/custom
```

Build the Invidious image.

```sh
cat <<"EOF" | oc new-build --name=invidious --strategy=docker --docker-image=alpine:edge -D -
FROM alpine:edge
RUN apk add --no-cache crystal shards libc-dev yaml-dev \
                       libxml2-dev sqlite-dev zlib-dev openssl-dev
WORKDIR /invidious
RUN git clone https://github.com/omarroth/invidious.git \
              -b ${INVIDIOUS_VERSION:-0.20.0} . \
 && shards update && shards install \
 && crystal build --release --warnings all --error-on-warnings -Dmusl \
                  ./src/invidious.cr \
 && apk add --no-cache librsvg ttf-opensans \
 && chmod -R ugo+rw,+X /invidious
CMD [ "/invidious/invidious" ]
EOF
oc patch bc/invidious -p '{"spec":{"strategy":{"dockerStrategy":{"noCache":true}}}}'
```

Deploy Invidious.

```sh
oc new-app --image-stream=invidious:latest --name=invidious
oc expose dc/invidious --port=3000
```

Create the Invidious configuration file and mount it in `/invidious/config/`.

```sh
cat <<"EOF" > /tmp/config.yml
channel_threads: 1
feed_threads: 1
db:
  user: kemal
  password: secret
  host: postgresql
  port: 5432
  dbname: invidious
full_refresh: false
https_only: false
domain:
EOF

oc create configmap invidious-config --from-file=/tmp/config.yml
oc set volume dc/invidious --add -t configmap --name invidious-config \
                           --configmap-name=invidious-config \
                           -m /invidious/config/
```

Create a route to expose Invidious.

```sh
oc expose svc/invidious
```

You can then export your existing YouTube subscriptions and import them in Invidious.

- Go to the [subscription manager](https://www.youtube.com/subscription_manager)
- Scroll down to the bottom of the page
- Click **Export subscriptions**
- *An XML file is generated and downloaded*
- Open Invidious
- Click **Login**
- Choose a login and a password and click **Sign In/Register**
- Click **Subscriptions** > **Manage subscriptions**
- Click **Choose file** next to **Import YouTube subscription**
- Click **Import**

Enjoy!
