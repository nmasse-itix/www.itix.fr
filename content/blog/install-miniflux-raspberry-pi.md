---
title: "Install Miniflux on your Raspberry PI"
date: 2020-04-08T00:00:00+02:00
opensource: 
- OpenWRT
---

In the article "[Nginx with TLS on OpenWRT](../nginx-with-tls-on-openwrt/)", I explained how to install Nginx with TLS support on a Raspberry PI.
But without an application to protect, Nginx is quite useless.
This article explains how to install [Miniflux](https://miniflux.app/) (a lightweight RSS reader) on your Raspberry PI and how to host it as an Nginx virtual host.

Miniflux is a web application written in Go and backed by a PostgreSQL database. So we will need to install PostgreSQL, install miniflux and setup Nginx. The rest of this article assumes you [installed OpenWRT on your Raspberry](../install-openwrt-raspberry-pi/), but it should be applicable to any Linux distribution with minimal changes.

## Install PostgreSQL

Install the **pgsql-server** and **pgsql-cli** packages.

```sh
opkg update
opkg install pgsql-server pgsql-cli
```

Create a directory to hold PostgreSQL data (for instance **/srv/postgresql/data**).

```sh
mkdir -p /srv/postgresql/data
uci set postgresql.config.PGDATA=/srv/postgresql/data
uci set postgresql.config.PGLOG=/srv/postgresql/data/postgresql.log
uci commit
chown postgres:postgres /srv/postgresql/data
```

Initialize the database.

```sh
cd /srv/postgresql/data
sudo -u postgres /bin/ash -c 'LC_COLLATE="C" initdb —pwprompt -D /srv/postgresql/data'
```

Enable and start the PostgreSQL service.

```sh
service postgresql enable
service postgresql start
```

**Note:** if you need to start/stop the database manually, you can do so with the following commands:

```sh
sudo -u postgres /bin/ash -c 'LC_COLLATE="C" pg_ctl -D /srv/postgresql/data -l logfile start'
sudo -u postgres /bin/ash -c 'LC_COLLATE="C" pg_ctl -D /srv/postgresql/data -l logfile stop'
```

To be able to connect to the database by just typing **psql** in a command prompt, you have to create a PostgreSQL user for each Unix user.
In the following example, *root* can do everything and *nicolas* can create new databases.

```sh
sudo -u postgres psql -c 'CREATE USER root SUPERUSER;'
sudo -u postgres psql -c 'CREATE USER nicolas CREATEDB;'
```

## Install Miniflux

If not already done yet, install the required libraries to handle HTTPS URLs in **wget**.
This is required by the next step (download from github.com over HTTPS).

```sh
opkg update
opkg install libustream-mbedtls ca-bundle ca-certificates
```

Install Miniflux in **/opt/miniflux**.

```sh
mkdir -p /opt/miniflux/bin
wget -O /opt/miniflux/bin/miniflux https://github.com/miniflux/miniflux/releases/download/2.0.19/miniflux-linux-armv8
chmod 755 /opt/miniflux/bin/miniflux
```

Create a Unix user and a PostgreSQL user named **miniflux**.

```sh
useradd -d /var/run/miniflux -s /bin/false -m -r miniflux
sudo -u postgres psql -c "CREATE USER miniflux WITH PASSWORD 'miniflux';"
sudo -u postgres psql -c "CREATE DATABASE miniflux OWNER miniflux;"
```

Check that users and database are setup correctly with the following command (no error message should appear here).

```sh
psql -h 127.0.0.1 miniflux miniflux
cd /tmp && sudo -u miniflux psql miniflux -c ''
```

Create the hstore extension required by Miniflux.

```sh
sudo -u postgres psql miniflux -c 'CREATE EXTENSION hstore;'
```

Configure Miniflux with the database connection URL and the port to listen on.

```sh
mkdir -p /opt/miniflux/etc
cat > /opt/miniflux/etc/miniflux.conf <<EOF
DATABASE_URL=postgres://miniflux:miniflux@localhost/miniflux?sslmode=disable
LISTEN_ADDR=8001
EOF
chown miniflux:miniflux /opt/miniflux/etc/miniflux.conf
chmod 600 /opt/miniflux/etc/miniflux.conf
```

Initialize the Miniflux database.

```sh
/opt/miniflux/bin/miniflux -c /opt/miniflux/etc/miniflux.conf -migrate
/opt/miniflux/bin/miniflux -c /opt/miniflux/etc/miniflux.conf -create-admin
```

Create an init script for Miniflux (**/etc/init.d/miniflux** for instance).

```sh
#!/bin/sh /etc/rc.common
# Miniflux

# Start after PostgreSQL (S50)
START=80
STOP=20

start() {
  start-stop-daemon -c miniflux -u miniflux -x /opt/miniflux/bin/miniflux -b -S -- -c /opt/miniflux/etc/miniflux.conf
}

stop() {
  start-stop-daemon -c miniflux -u miniflux -x /opt/miniflux/bin/miniflux -b -K
}
```

Enable and start the **miniflux** service.

```sh
service miniflux enable
service miniflux start
```

If everything goes well, you should see a process binding port 8001.

```
# netstat -tlnp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      517/dropbear
tcp        0      0 127.0.0.1:5432          0.0.0.0:*               LISTEN      676/postmaster
tcp        0      0 127.0.0.1:8001          0.0.0.0:*               LISTEN      804/miniflux
```

## Configure the Nginx virtual host

Edit your nginx configuration file and, as explained in "[Nginx with TLS on OpenWRT](../nginx-with-tls-on-openwrt/)", insert a new **server** directive after the last one.

The only difference is that we are not serving static files from the filesystem but rather forwarding requests to a backend service.

So the **root** directive in the **location /** block needs to be replace by a **proxy_pass** directive.

```
server {
    listen 443 ssl;
    server_name miniflux.pi.example.test;

    ... redacted ...

    location / {
        proxy_pass http://127.0.0.1:8001;
    }
}
```

**Note:** Do not insert a slash at the end of the URL, otherwise you would [get a very different behavior](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass).

Of course, you would also need to add a new DNS entry for the hostname of this new virtual host and renew your TLS certificate to include it.

## Conclusion

This article explained how to install [Miniflux](https://miniflux.app/) on your Raspberry PI and how to host it as an Nginx virtual host.

If you liked this article, you can use your freshly installed Miniflux instance to [subscribe to my RSS feed](/index.xml)!
