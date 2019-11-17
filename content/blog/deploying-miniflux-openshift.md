---
title: "Deploying Miniflux on OpenShift"
date: 2019-11-17T00:00:00+02:00
opensource:
- OpenShift
- Miniflux
---

[Miniflux](https://miniflux.app) is a minimalist, open source and opinionated RSS feed reader. There is a [hosted instance](https://miniflux.app/hosting.html) available at a fair price point but wouldn't it be cooler to host your own instance on your OpenShift cluster? Let's do it!

Create a new project.

```sh
oc new-project miniflux --display-name=Miniflux
```

Provision a PostgreSQL database instance, as required by Miniflux.

```sh
oc new-app --name=postgresql --template=postgresql-persistent \
           -p POSTGRESQL_USER=miniflux \
           -p POSTGRESQL_PASSWORD=miniflux \
           -p POSTGRESQL_DATABASE=miniflux
```

Because the database needs to be initialized [with the hstore extension enabled](https://miniflux.app/docs/installation.html), we need to create an initialization script for our PostgreSQL instance.

```sh
cat <<"EOF" > start.sh
echo ">>> Starting database schema creation"
set +e
psql $POSTGRESQL_DATABASE -c 'create extension hstore'
set -e
echo "<<< Finished database schema creation"
EOF
```

Provision the initialization script as a Config Map and mount it on the PostgreSQL pod in */opt/app-root/src/postgresql-start*.

```sh
oc create configmap postgresql-init --from-file=start.sh
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

Deploy Miniflux.

```sh
oc new-app --name=miniflux --docker-image=miniflux/miniflux:latest \
           -e 'DATABASE_URL=postgres://miniflux:miniflux@postgresql/miniflux?sslmode=disable' \
           -e RUN_MIGRATIONS=1 -e CREATE_ADMIN=1
```

Choose a login and a password for the first Miniflux user.

```sh
oc create secret generic miniflux --from-literal=username=admin --from-literal=password=secret
oc set env dc/miniflux --from=secret/miniflux --prefix=ADMIN_
```

Create a route to expose Miniflux.

```sh
oc expose svc/miniflux
```
