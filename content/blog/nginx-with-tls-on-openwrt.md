---
title: "Nginx with TLS on OpenWRT"
date: 2019-12-19T00:00:00+02:00
opensource: 
- OpenWRT
- nginx
---

In the article "[Install OpenWRT on your Raspberry PI](../install-openwrt-raspberry-pi/)", I explained how to install OpenWRT on a Raspberry PI and the first steps as an OpenWRT user.
As I plan to use my Raspberry PI to host plenty of web applications, I wanted to setup a versatile reverse proxy to protect them all, along with TLS support to meet nowadays security requirements.

OpenWRT has an [nginx package](https://openwrt.org/packages/pkgdata/nginx), ready to be installed using *opkg* but unfortunately it does not have TLS enabled. So we need to recompile nginx with TLS enabled!

## Install the OpenWRT build system

Install a Linux distribution [supported by the OpenWRT build system](https://openwrt.org/docs/guide-developer/build-system/install-buildsystem) in a Virtual Machine. For instance, [Ubuntu Server LTS 18.04.3](http://cdimage.ubuntu.com/releases/18.04.3/release/).

Install the build system pre-requisites.

```sh
sudo apt-get install -y build-essential libncurses5-dev gawk git libssl-dev gettext unzip zlib1g-dev file python-dev libmodule-build-perl  libmodule-install-perl libthread-queue-any-perl
```

Clone the OpenWRT GIT repository. Change the branch name to your version number, if you are not on 18.06.

```sh
git clone https://git.openwrt.org/openwrt/openwrt.git -b openwrt-18.06
cd openwrt
```

Run *make menuconfig* to configure the build system.

```sh
make menuconfig
```

Select the following options:

- Target System: **Broadcom BCM27xx**
- Subtarget: **BCM2710 64 bit based boards**
- Target Profile: **Raspberry Pi 3B/3B+**
- Enable **Build the OpenWRT SDK**

![make menuconfig](make-menuconfig.png)

Launch a complete build. According to [the documentation](https://oldwiki.archive.openwrt.org/doc/techref/buildroot), the parameter *V=s* in the following command is used to display verbose output.

```sh
make V=s
```

## Recompile the nginx package

Fetch the existing nginx package sources.

```sh
scripts/feeds update
scripts/feeds install nginx
```

Run *make menuconfig* again.

```sh
make menuconfig
```

Drill down to **Network** > **Web Servers/Proxies** and:

- Press space to select **nginx**
- Press enter to enter configuration
- Choose **Configuration**
- Press space to select "**Enable SSL Module**"
- Exit five times and save

Build the nginx package.

```sh
make V=s
```

Once the build finished, the nginx package will be in *bin/packages*.

```raw
$ find . -type f -name 'nginx*.ipk'
./bin/packages/aarch64_cortex-a53/packages/nginx_1.12.2-1_aarch64_cortex-a53.ipk
```

## Install nginx

Install the freshly compiled nginx package on your OpenWRT system.

```sh
scp ./bin/packages/aarch64_cortex-a53/packages/nginx_1.12.2-1_aarch64_cortex-a53.ipk root@raspberry-pi.example.test:/tmp
ssh root@raspberry-pi.example.test opkg install /tmp/nginx_1.12.2-1_aarch64_cortex-a53.ipk
```

## Install Lego

[Lego](https://go-acme.github.io/lego/) is a client for the Let's Encrypt CA. It will help us get valid TLS certificates for our nginx instance.

Install lego from the [binaries](https://github.com/go-acme/lego/releases).

```sh
mkdir -p /opt/lego/bin
wget -O /tmp/lego.tgz https://github.com/go-acme/lego/releases/download/v3.2.0/lego_v3.2.0_linux_arm64.tar.gz
tar -C /opt/lego/bin -zxvf /tmp/lego.tgz lego
chown root:root /opt/lego/bin/lego
chmod 755 /opt/lego/bin/lego
```

## Get a public TLS certificate

Request a public certificate for your Raspberry PI hostname. In the following example, I'm using the DNS challenge method and the Gandi DNS provider. Of course, you would have also to replace *raspberry-pi.example.test* with your Raspberry PI's hostname.

```sh
mkdir /etc/nginx/tls
GANDIV5_API_KEY=[REDACTED] /opt/lego/bin/lego -m replace.with@your.email -d raspberry-pi.example.test -a --dns gandiv5 --path /etc/nginx/tls run  --no-bundle
```

If everything went fine, you will find the freshly issued certificates in */etc/nginx/tls/certificates/$hostname.{key,crt}*.

```raw
root@OpenWrt:~# find /etc/nginx/tls/
/etc/nginx/tls/
/etc/nginx/tls/certificates
/etc/nginx/tls/certificates/raspberry-pi.example.test.crt
/etc/nginx/tls/certificates/raspberry-pi.example.test.issuer.crt
/etc/nginx/tls/certificates/raspberry-pi.example.test.key
/etc/nginx/tls/certificates/raspberry-pi.example.test.json
```

## Configure nginx

Create a user for the nginx workers.

```sh
opkg update
opkg install shadow-useradd
useradd -d /var/run/nginx -s /bin/false -m -r nginx
```

Create the nginx configuration file in **/etc/nginx/nginx.conf**.

```raw
user nginx nginx;
worker_processes 1;

error_log syslog:server=unix:/dev/log,nohostname warn;

events {
    worker_connections 1024;
}

http {
    server_names_hash_bucket_size 64;
    include mime.types;

    log_format main '$remote_addr "$request" => $status';
    access_log syslog:server=unix:/dev/log,nohostname main;

    sendfile on;
    keepalive_timeout 65;
    gzip off;

    server {
        listen 443 ssl default_server;

        ssl_certificate /etc/nginx/tls/certificates/raspberry-pi.example.test.crt;
        ssl_certificate_key /etc/nginx/tls/certificates/raspberry-pi.example.test.key;
        ssl_session_cache shared:SSL:1m;
        ssl_session_timeout 5m;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        # Error pages
        error_page 404 /404.html;
        error_page 500 502 503 504 /50x.html;
        location ~ /[45][0-9x][0-9x].html {
            root /srv/nginx/default;
        }

        # Main content
        index index.html index.htm;
        location / {
            root /srv/nginx/default;
        }
    }
}
```

Create the default page and the error pages.

```sh
mkdir -p /srv/nginx/default
echo "None of your business." > /srv/nginx/default/index.html
echo "Nope. Not here." > /srv/nginx/default/404.html
echo "OOPS..." > /srv/nginx/default/50x.html
```

## Start nginx

Start the nginx instance.

```sh
service nginx enable
service nginx start
```

If your configuration is valid, the port 443 should be bound to nginx.

```raw
root@OpenWrt:~# netstat -tlnp |grep :443
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      11305/nginx.conf -g
```

If nginx does not start, you can get some details using the *logread* command.

```raw
logread |tail -n 10
```

If you cannot get any details using *logread*, try to start nginx manually.

```sh
nginx -g "daemon off;" -c /etc/nginx/nginx.conf
```

From your workstation, try to query your nginx instance by its IP address.

```raw
$ curl -k https://192.168.2.2/
None of your business.
```

## Further configuration

So far, our nginx instance is only serving a few static files with unpleasant messages.
This is the default virtual host of our nginx instance that is used when bots try to scan your web server by its IP address without knowing its actual hostname.

To add another virtual host, just add a new *server* block after the default one.

```raw
server {
    listen 443 ssl;
    server_name raspberry-pi.example.test

    ssl_certificate /etc/nginx/tls/certificates/raspberry-pi.example.test.crt;
    ssl_certificate_key /etc/nginx/tls/certificates/raspberry-pi.example.test.key;
    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout 5m;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location ~ /[45][0-9x][0-9x].html {
        root /srv/nginx/default;
    }

    # Main content
    index index.html index.htm;
    location / {
        root /srv/nginx/main;
    }
}
```

Serve some nice content.

```sh
mkdir -p /srv/nginx/main
echo 'Welcome!' > /srv/nginx/main/index.html
```

From your workstation, try to query your nginx instance by its hostname.

```raw
$ curl https://raspberry-pi.itix.fr/
Welcome!
```

## Certificate renewal

The TLS certificate we fetched from Let's Encrypt is valid for ninety days.
If you do not want to manually renew the certificate every ninety days, you will have to setup automatic renewal in a cron job.

Install pkill. We will use it to tell nginx to reload its configuration and the renewed certificates.

```sh
opkg update
opkg install procps-ng-pkill
```

Edit the crontab of the root user.

```sh
crontab -e -u root
```

And an entry to renew the certificate using lego.

```crontab
# At 3:59 the first day of the month, renew the Let's Encrypt certificates
3 59 1 * * GANDIV5_API_KEY=[REDACTED] /opt/lego/bin/lego -m replace.with@your.email -d raspberry-pi.example.test -a --dns gandiv5 --path /etc/nginx/tls run  --no-bundle && pkill -SIGHUP 'nginx: master'
```

## Conclusion

Nginx is now installed on your Raspberry PI, with TLS support enabled and a valid public certificate from Let's Encrypt that will be renewed automatically.
The configuration serves a default virtual host to every bot that queries the nginx instance by its IP address and can serve any number of virtual host, provided you add the matching *server* block.

Discover in the next article how to deploy a real world application: miniflux, an RSS reader.
