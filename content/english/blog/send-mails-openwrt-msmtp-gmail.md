---
title: "Send mails on OpenWRT with MSMTP and Gmail"
date: 2020-04-08T00:00:00+02:00
opensource:
- OpenWRT
topics:
- Embedded Systems
---

A previous article named "[Install OpenWRT on your Raspberry PI](../install-openwrt-raspberry-pi/)" goes through the setup process to use OpenWRT on your Raspberry PI.
As a consequence, you might now have a Raspberry PI running OpenWRT and full of services of which all your family relies on.
With great power comes great responsibilities.
So, you might want to be notified when something goes wrong, a cron job failed, a hard disk is dying, etc., so that you can fix the problem at earliest, maybe before anyone else could notice.

This article explains how to send mails on OpenWRT with MSMTP and a GMail account.

<!--more-->

You can adapt this procedure to any email provider that supports SMTP access with a login and password.

## Configure GMail

How to configure GMail to allow SMTP access depends on the security settings of your account.

* If you have two-factor authentication (2FA) enabled, you will need to create an [app password](https://myaccount.google.com/apppasswords). Google will generate a strong password for you.
* If you do **NOT** have 2FA enabled, you will need to allow access to unsecured apps from the [Less Secure Apps](https://myaccount.google.com/lesssecureapps) page.

## Install MSMTP

On your OpenWRT device, install the msmtp package.

```sh
opkg update
opkg install msmtp
```

Create the MSMTP configuration file **/etc/msmtprc**.

```
# A system wide configuration file is optional.
# If it exists, it usually defines a default account.
# This allows msmtp to be used like /usr/sbin/sendmail.
account default

# The place where the mail goes. The actual machine name is required
# no MX records are consulted. Both port 465 or 587 should be acceptable
# See also https://support.google.com/mail/answer/78799
host smtp.gmail.com
port 587

# Construct envelope-from addresses of the form "user@oursite.example".
# auto_from on
# maildomain itix.fr
auto_from off
from change.me@gmail.com

# Dispatch mails according to /etc/aliases
aliases /etc/aliases

# Use TLS.
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt

# Syslog logging with facility LOG_MAIL instead of the default LOG_USER.
syslog LOG_MAIL

# Authenticate to GMail
#
# If your Gmail account is secured with two-factor authentication, you need
# to generate a unique App Password to use in ssmtp.conf.
# See https://support.google.com/mail/answer/185833
# App Passwords can be generated on https://myaccount.google.com/apppasswords
#
# Use you Gmail username (not the App Name) in the AuthUser line and use the
# generated 16-character password in the AuthPass line, spaces in the password
# can be omitted.
#
# If you do not use two-factor authentication, you need to allow access to
# unsecure apps. You can do so on your Less Secure Apps page.
# See https://support.google.com/accounts/answer/6010255
# You can do so on https://myaccount.google.com/lesssecureapps

auth on
user change.me@gmail.com
password changeme
```

Create the **/etc/aliases** file so that every mail sent to a local user (root, ftp, nobody, etc.) is in fact sent to the designated email address.
This is a safe measure in order no to lose emails.

```
default: change.me@gmail.com
```

Of course, do not forget to replace the email address (**change.me@gmail.com**) and password (**changeme**) with the actual values in both files.

If you know **for sure** that all the mails will be sent by root or daemons running as root, you can tighten up the file permissions. Otherwise, let it as-is.

```sh
chmod 600 /etc/msmtprc
```

You can make **msmtp** be an alias for the **sendmail** that most unix daemons are looking for.

```sh
ln -s /usr/bin/msmtp /usr/sbin/sendmail
```

## Run a test

The following command sends a mail to the **root** user.
If you configured **/etc/aliases** as instructed with a fallback on your email address, you should receive a mail containing the famous "Hello, World!".

```sh
echo -e "Subject: Hello!\n\nHello, world!" |sendmail root
```

## Daemon configuration

The cron daemon from OpenWRT is based on busybox and has **NOT** be compiled with the option to send emails.
So if you want to be notified when a cron fails, you will have to recompile busybox with "**Report command output via email (using sendmail)**" enabled.
The article named "[Nginx with TLS on OpenWRT](../nginx-with-tls-on-openwrt/)" explains how to recompile a package with a different configuration and how to install it.

## Conclusion

This article explained how to send mails on OpenWRT with MSMTP and a GMail account.
