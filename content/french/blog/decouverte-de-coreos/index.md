---
title: "À la découverte de CoreOS !"
date: 2021-11-22T00:00:00+02:00
lastMod: 2021-11-25T00:00:00+02:00
opensource:
- OpenShift
- CoreOS
topics:
- Containers
resources:
- '*.png'
- '*.svg'
---

Avec le rachat de la société CoreOS par Red Hat et le développement d'OpenShift 4, est arrivé un nouveau concept dans l'écosystème Red Hat : le système d'exploitation spécifique aux conteneurs.
Au sein d'une série de deux articles, celui-ci présente CoreOS, son mécanisme de mise à jour ainsi que les principales différences avec Red Hat Enterprise Linux.

<!--more-->

## Contexte

CoreOS est un système d'exploitation spécifique aux conteneurs.
Ce concept est né avec l'essor des orchestrateurs de conteneurs et plus spécifiquement Kubernetes.

C'est en 2017 que le NIST définit le concept dans un article intitulé "[NIST Special Publication 800-190: Application Container Security Guide](https://doi.org/10.6028/NIST.SP.800-190)" qui aborde le sujet sous l'angle de la sécurité.

> A container-specific host OS is a minimalist OS explicitly designed to only run containers, with
> all other services and functionality disabled, and with read-only file systems and other hardening
> practices employed. When using a container-specific host OS, attack surfaces are typically much
> smaller than they would be with a general-purpose host OS, so there are fewer opportunities to
> attack and compromise a container-specific host OS. Accordingly, whenever possible,
> organizations should use container-specific host OSs to reduce their risk. However, it is
> important to note that container-specific host OSs will still have vulnerabilities over time that
> require remediation.

Jusqu'à OpenShift 3, le socle était composé d'un système d'exploitation qu'il fallait installer, configurer, mettre à jour, réparer manuellement.
C'est chronophage et incompatible avec une gestion à large échelle.
Même automatisées avec un outil d'automatisation tel que Ansible, les mises à jour et les installations étaient pénibles.

Mais avec l'arrivée d'OpenShift 4 et des opérateurs Kubernetes, CoreOS a beaucoup contribué à faciliter la gestion à large échelle !

## Présentation de CoreOS

CoreOS est un système d'exploitation spécifique à l'exploitation des conteneurs.
Il est né de la fusion de deux projets Open Source: Container Linux (par la société CoreOS avant le rachat) et Atomic Host (par Red Hat avant le rachat de la société CoreOS).

CoreOS se décline en deux versions :

- **Fedora CoreOS** qui est la communauté Open Source dans laquelle ont lieu les innovations.
- **Red Hat CoreOS** qui est la version stabilisée par Red Hat et utilisée par OpenShift.

Première différence avec un système d'exploitation classique : CoreOS est distribué sous la forme d'une image disque qu'il faut "flasher" sur le disque de la machine cible.
Ainsi, on n'installe pas CoreOS.
On flashe le serveur avec l'image CoreOS (sur le même principe que votre box internet qui arrive avec un firmware pré-installé, prêt à l'usage).

Cette façon de faire a un avantage : on s'assure que tous les serveurs s'appuient sur la même souche logicielle, au bit prêt !

Lors de son premier démarrage, CoreOS va se configurer en suivant les instructions d'un fichier *ignition*.
Ce fichier *ignition* est souvent fourni par un composant central à toutes les machines (dans OpenShift, c'est le **Machine Config Server** qui joue ce rôle).

Le fichier *ignition* ressemble à un script *Kickstart* ou *cloud-init* mais en plus restrictif car les seuls éléments pris en charge sont :

- le partitionnement et le formatage des disques,
- l'écriture des fichiers de configuration dans `/etc` et `/var`,
- l'activation et le démarrage de *units* systemd,
- la création d'utilisateurs,
- et l'ajout/suppression d'arguments au démarrage du noyau Linux.

L'avantage est que contrairement à un script *Kickstart* ou *cloud-init* qui peut laisser le système dans un état semi-fonctionnel à cause d'un script qui s'est terminé prématurément, ici tous les scripts doivent être joués sous la forme de *units* systemd qui peuvent être re-jouées jusqu'à réussir, pour lequel les journaux d'exécution sont disponibles et dont le statut (succès / échec) peut être suivi à distance.

C'est un gros gain pour une gestion à large échelle.

Vous remarquerez que le fichier [ignition](https://coreos.github.io/ignition/configuration-v3_3/) ne permet pas d'installer un package rpm.
C'est également une spécificité de CoreOS : tous les logiciels qui tournent sur CoreOS doivent tourner sous la forme de conteneurs, instanciés et démarrés depuis un *unit* systemd ou provisionné par OpenShift.

Note: si vous souhaitez tout de même installer un package RPM, il est possible de personnaliser l'image CoreOS avec vos modification.
Je vous conseille alors la lecture de cet article : {{< internalLink path="/blog/build-your-own-distribution-on-fedora-coreos.md" lang="en" >}}.

Autre différence majeure avec un système d'exploitation classique : les mises à jour s'effectuent de manière transactionnelle.
Cela signifie qu'une mise à jour du système d'exploitation s'effectue dans son intégralité ou ne se fait pas du tout.
Le système ne peut pas rester dans un état intermédiaire, à moitié mis à jour.

Et enfin, CoreOS vise l'immutabilité.
C'est à dire qu'une fois flashé, les binaires (/usr) sont montés en lecture seule alors que la configuration (/etc) et les données (/var) sont montées en lecture/écriture.
Ainsi, on minimise le risque de voir un logiciel malveillant s'implanter durablement dans le système.

## Principe de fonctionnement des mises à jour transactionnelles

Lorsque CoreOS se met à jour, il le fait de manière atomique. La mise à jour peut échouer, mais le système n'est jamais dans un état intermédiaire.
Soit le système est à jour dans sa dernière version, soit dans la version précédente : il n'y a pas d'entre deux possible.

Pour comprendre comment fonctionne ce système de mise à jour transactionnelle, il faut regarder du coté des points de montage.

CoreOS a une organisation bien particulière :

- tous les binaires et bibliothèques sont dans `/usr`,
- toutes les données sont dans `/var`,
- et tous les fichiers de configuration sont dans `/etc`.

Pour respecter le standard LSB et ne avoir à modifier le comportement des logiciels installés, des liens symboliques sont mis en place.

- `/bin` pointe sur `/usr/bin`
- `/home` pointe sur `/var/home`
- etc.

```
[core@coreos ~]$ ls -l /
lrwxrwxrwx.   2 root root    7 Jul 20 22:00 bin -> usr/bin
drwxr-xr-x.   7 root root 1024 Oct 11 14:31 boot
drwxr-xr-x.  18 root root 2980 Oct 25 19:02 dev
drwxr-xr-x.  93 root root 8192 Oct 25 19:02 etc
lrwxrwxrwx.   2 root root    8 Jul 20 22:00 home -> var/home
lrwxrwxrwx.   2 root root    7 Jul 20 22:00 lib -> usr/lib
lrwxrwxrwx.   2 root root    9 Jul 20 22:00 lib64 -> usr/lib64
lrwxrwxrwx.   2 root root    9 Jul 20 22:00 media -> run/media
lrwxrwxrwx.   2 root root    7 Jul 20 22:00 mnt -> var/mnt
lrwxrwxrwx.   2 root root    7 Jul 20 22:00 opt -> var/opt
lrwxrwxrwx.   2 root root   14 Jul 20 22:00 ostree -> sysroot/ostree
dr-xr-xr-x. 130 root root    0 Oct 25 19:02 proc
lrwxrwxrwx.   2 root root   12 Jul 20 22:00 root -> var/roothome
drwxr-xr-x.  30 root root  840 Oct 25 19:02 run
lrwxrwxrwx.   2 root root    8 Jul 20 22:00 sbin -> usr/sbin
lrwxrwxrwx.   2 root root    7 Jul 20 22:00 srv -> var/srv
dr-xr-xr-x.  13 root root    0 Oct 25 19:02 sys
drwxr-xr-x.   4 root root   66 Jul 20 22:00 sysroot
drwxrwxrwt.   8 root root  180 Oct 25 19:03 tmp
drwxr-xr-x.  12 root root  155 Jan  1  1970 usr
drwxr-xr-x.  25 root root 4096 Oct 11 14:31 var
```

Les différentes versions de CoreOS sont installées dans `/ostree`.
Chaque version (identifiée par son empreinte SHA 256) contient l'ensemble du système d'exploitation.

La commande `ostree admin status` permet de lister les versions installées.

{{< highlight "sh" "hl_lines=2 14" >}}
[core@coreos ~]$ sudo ostree admin status
* rhcos eb6dd3b8b2912914f568af791a7ece826665cc78153a4e4d304acdaae1daacd1.0
    Version: 48.84.202106231817-0
    origin refspec: eb6dd3b8b2912914f568af791a7ece826665cc78153a4e4d304acdaae1daacd1
  rhcos 5aad7b2a525fb337915157af5fa811e5066fe7bc39a0b9a331830395aa8f2e2d.0 (rollback)
    Version: 48.84.202105281935-0
    origin refspec: 5aad7b2a525fb337915157af5fa811e5066fe7bc39a0b9a331830395aa8f2e2d

[core@coreos ~]$ ls /ostree/deploy/rhcos/deploy/*/
/ostree/deploy/rhcos/deploy/5aad7b2a525fb337915157af5fa811e5066fe7bc39a0b9a331830395aa8f2e2d.0/:
bin   dev  home  lib64  mnt  ostree  root  sbin  sys      tmp  var
boot  etc  lib   media  opt  proc    run   srv   sysroot  usr

/ostree/deploy/rhcos/deploy/eb6dd3b8b2912914f568af791a7ece826665cc78153a4e4d304acdaae1daacd1.0/:
bin   dev  home  lib64  mnt  ostree  root  sbin  sys      tmp  var
boot  etc  lib   media  opt  proc    run   srv   sysroot  usr
{{< / highlight >}}

Pour éviter de gâcher de l'espace disque, les fichiers communs à deux versions sont partagés via un *hard link*.
Ici, la commande `ls` est identique entre les deux versions et ainsi les deux fichiers ont le même *inode*.

```
[core@coreos ~]$ ls -li /ostree/deploy/rhcos/deploy/*/bin/ls
3331330 -rwxr-xr-x. 3 root root 143368 Jan  1  1970 /ostree/deploy/rhcos/deploy/5aad7b2a525fb337915157af5fa811e5066fe7bc39a0b9a331830395aa8f2e2d.0/bin/ls
3331330 -rwxr-xr-x. 3 root root 143368 Jan  1  1970 /ostree/deploy/rhcos/deploy/eb6dd3b8b2912914f568af791a7ece826665cc78153a4e4d304acdaae1daacd1.0/bin/ls
```

Les données dans `/var` sont partagées entre les versions.

Les fichiers de configuration dans `/etc` font parties de la mise à jour et sont donc stockés dans `/ostree` mais les modifications locales sont reportées dans la version suivante lors du processus de mise à jour.

A cette étape, vous pouvez légitimement vous demander comment tout ça se met en place pour avoir tous les fichiers au bon endroit une fois le système en fonctionnement.

Lorsque CoreOS démarre, il commence par monter le système de fichier racine dans `/sysroot`.
Ensuite, il regarde quelle est la version courante du système d'exploitation (**eb6d...acd1** dans l'exemple ci-dessus).

Il monte alors `/ostree/deploy/rhcos/deploy/$version` sur `/`. C'est possible car `/ostree` est un lien symbolique vers `/sysroot/ostree` et CoreOS vient de monter `/sysroot`.

Dans la foulée, il monte `/ostree/deploy/rhcos/deploy/$version/usr` sur `/usr` (en lecture seule) et `/ostree/deploy/rhcos/deploy/$version/etc` sur `/etc`.

Ensuite, `/ostree/deploy/rhcos/var` est monté sur `/var`. 

Et à partir de ce moment, notre système est opérationnel !

Finalement, toute l'ingéniosité de ce système de mise à jour tient à deux choses :

- Les versions du système d'exploitation sont stockées côte à côte sur le système de fichiers, dans leur intégralité.
- C'est au moment du démarrage que CoreOS monte la bonne version à la racine du système de fichier.

Le corolaire de tout ça, c'est qu'il faut redémarrer le système pour le mettre à jour...

## Différence avec Red Hat Enterprise Linux

Red Hat CoreOS est une version de Red Hat Enterprise Linux, packagée de manière un peu différente.

Le premier indice se trouve dans le fichier /etc/os-release qui nous indique que la version de CoreOS embarquée avec OpenShift 4.8 est basée sur une Red Hat Enterprise Linux 8.4.

{{< highlightFile "/etc/os-release" "sh" "hl_lines=18" >}}
NAME="Red Hat Enterprise Linux CoreOS"
VERSION="48.84.202108062347-0"
ID="rhcos"
ID_LIKE="rhel fedora"
VERSION_ID="4.8"
PLATFORM_ID="platform:el8"
PRETTY_NAME="Red Hat Enterprise Linux CoreOS 48.84.202108062347-0 (Ootpa)"
ANSI_COLOR="0;31"
CPE_NAME="cpe:/o:redhat:enterprise_linux:8::coreos"
HOME_URL="https://www.redhat.com/"
DOCUMENTATION_URL="https://docs.openshift.com/container-platform/4.8/"
BUG_REPORT_URL="https://bugzilla.redhat.com/"
REDHAT_BUGZILLA_PRODUCT="OpenShift Container Platform"
REDHAT_BUGZILLA_PRODUCT_VERSION="4.8"
REDHAT_SUPPORT_PRODUCT="OpenShift Container Platform"
REDHAT_SUPPORT_PRODUCT_VERSION="4.8"
OPENSHIFT_VERSION="4.8"
RHEL_VERSION="8.4"
OSTREE_VERSION='48.84.202108062347-0'
{{< / highlightFile >}}

La version du noyau Linux est, à peu de choses près, la même sur CoreOS que sur RHEL.

{{< highlightWithTitle "RHEL 8.4" "sh" "hl_lines=3" >}}
[nmasse@localhost ~]$ rpm -qa |grep kernel
kernel-modules-4.18.0-305.el8.x86_64
kernel-4.18.0-305.el8.x86_64
kernel-core-4.18.0-305.el8.x86_64
kernel-tools-4.18.0-305.el8.x86_64
kernel-tools-libs-4.18.0-305.el8.x86_64
{{< / highlightWithTitle >}}

&nbsp;

{{< highlightWithTitle "CoreOS" "sh" "hl_lines=5" >}}
[core@coreos ~]$ rpm -qa |grep kernel
kernel-core-4.18.0-305.10.2.el8_4.x86_64
kernel-modules-4.18.0-305.10.2.el8_4.x86_64
kernel-modules-extra-4.18.0-305.10.2.el8_4.x86_64
kernel-4.18.0-305.10.2.el8_4.x86_64
{{< / highlightWithTitle >}}

La glibc est exactement la même sur CoreOS et sur RHEL.

{{< highlightWithTitle "RHEL 8.4" "sh" "hl_lines=4 7" >}}
[nmasse@localhost ~]$ rpm -qa |grep glibc
glibc-langpack-en-2.28-151.el8.x86_64
glibc-common-2.28-151.el8.x86_64
glibc-2.28-151.el8.x86_64

[nmasse@localhost ~]$ sha1sum /lib64/libc-2.28.so
5dd511ebea3476a03d710eff1bab8a72a47fdf71  /lib64/libc-2.28.so
{{< / highlightWithTitle >}}

&nbsp;

{{< highlightWithTitle "CoreOS" "sh" "hl_lines=4 7" >}}
[core@coreos ~]$ rpm -qa |grep glibc
glibc-common-2.28-151.el8.x86_64
glibc-all-langpacks-2.28-151.el8.x86_64
glibc-2.28-151.el8.x86_64

[core@coreos ~]$ sha1sum /lib64/libc-2.28.so
5dd511ebea3476a03d710eff1bab8a72a47fdf71  /lib64/libc-2.28.so
{{< / highlightWithTitle >}}

Et la [documentation OpenShift](https://docs.openshift.com/container-platform/4.9/architecture/architecture-rhcos.html) confirme ces investigations avec l'information suivante :

> **Based on RHEL**: The underlying operating system consists primarily of RHEL components.
> The same quality, security, and control measures that support RHEL also support RHCOS.
> For example, RHCOS software is in RPM packages, and each RHCOS system starts up with a RHEL
> kernel and a set of services that are managed by the systemd init system.

Et l'installation standard de CoreOS correspond approximativement à une installation minimale de RHEL.
Une RHEL 8.4 minimale arrive en standard avec 404 packages installés. CoreOS arrive avec 503 packages installés, quelques un en moins (yum) et quelques un en plus (skopeo, podman, etc.).

Disons le plus clairement: Red Hat CoreOS est une déclinaison minimale de Red Hat Enterprise Linux dédiée aux conteneurs.

## Conclusion

Nous venons de présenter CoreOS, son mécanisme de mise à jour ainsi que les principales différences avec Red Hat Enterprise Linux.
Dans le prochain article, nous passerons à la pratique en utilisant CoreOS !

