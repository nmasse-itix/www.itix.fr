---
title: "Faire fonctionner qemu-user-static avec Podman"
date: 2025-06-10T00:00:00+02:00
opensource:
- Podman
- Qemu
topics:
- Containers
---

Récemment, j'ai eu à faire tourner des conteneurs ARM64 sur le laptop x86 d'un client.
Facile me direz-vous : tu n'as qu'à installer qemu-user-static sur le laptop !
Et t'as aussi un conteneur tout prêt sur Docker Hub, au cas où !

La messe est dite ?
Pas si sûr...

<!--more-->

## État des lieux

En effet, s'il est facile d'installer **qemu-user-static** sur **Fedora**, ce n'est pas le cas de **CentOS Stream** ou **Red Hat Enterprise Linux**.
On peut toujours récupérer le paquet d'un repository Fedora et l'installer sur ces downstream de Fedora.
Ça marche mais ça reste un paquet orphelin qui ne sera jamais mis à jour...

Et l'image [docker.io/multiarch/qemu-user-static](https://hub.docker.com/r/multiarch/qemu-user-static) que l'on peut trouver sur le Docker Hub ?
Elle n'a pas été mise à jour depuis 2 ans et la dernière version disponible de qemu est la 7.2.
Quand on sait que la version 10 de qemu a été publiée récemment, ça fait désordre...

## TL;DR

Deux one-liners, un pour la construction de l'image et un pour son exécution.

Construire l'image de conteneur **localhost/qemu-user-static** :

```sh
sudo podman build -f https://red.ht/qemu-user-static -t localhost/qemu-user-static /tmp
```

Exécuter **qemu-user-static** :

```sh
sudo podman run --rm --privileged --security-opt label=filetype:container_file_t --security-opt label=level:s0 --security-opt label=type:spc_t localhost/qemu-user-static
```

Ça y est !
Vous pouvez maintenant exécuter une image de conteneur qui est dans une architecture matérielle différente de celle de votre machine.

Exemple :

```
$ arch
x86_64

$ podman run -it --rm --platform linux/arm64/v8 docker.io/library/alpine     
/ # arch
aarch64
```

## Construction de l'image

J'ai choisi de baser mon image sur les images officielles Fedora (version 42 lors de l'écriture de cet article).
Si vous avez déjà travaillé avec l'image **docker.io/multiarch/qemu-user-static**, vous verrez que j'ai un peu modernisé tout ça :

- Plus de script en provenance du repo **qemu**, le composant **systemd-binfmt** fournit tout le nécessaire.
- Plus d'option à passer lors de l'exécution, le script désenregistre tous les binaires enregistrés auprès de sous-système **binfmt** et enregistre tous ses binaires `qemu-*-static` à la place.

Le résultat est dépouillé :

```dockerfile
FROM quay.io/fedora/fedora:42

RUN dnf install -y qemu-user-static \
 && dnf clean all

ADD container-entrypoint /

ENTRYPOINT ["/container-entrypoint"]
CMD []
```

Le script **container-entrypoint** est lui aussi réduit à son strict nécessaire :

```sh
#!/bin/sh

set -Eeuo pipefail

if [ ! -d /proc/sys/fs/binfmt_misc ]; then
    echo "No binfmt support in the kernel."
    echo "  Try: '/sbin/modprobe binfmt_misc' from the host"
    exit 1
fi

if [ ! -f /proc/sys/fs/binfmt_misc/register ]; then
    echo "Mounting /proc/sys/fs/binfmt_misc..."
    mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
fi

echo "Cleaning up..."
find /proc/sys/fs/binfmt_misc -type f -name 'qemu-*' -exec sh -c 'echo -1 > {}' \;

echo "Registering..."
exec /usr/lib/systemd/systemd-binfmt
```

## Exécution

Une fois l'image construite, il faut l'exécuter pour que les binaires `qemu-*-static` soient enregistrés auprès du système **binfmt**.
Mais il y a une petite subtilité : sur une distribution Linux type Fedora, CentOS Stream ou RHEL, le système SELinux veille au grain !
Et si quelque chose tente de percer l'étanchéité du moteur de conteneurisation, SELinux le détecte et l'action est interdite.

Et c'est exactement ce qui se produit quand on exécute naïvement l'image construite précédemment : les binaires `qemu-*-static` ont une étiquette SELinux qui interdit leur exécution par le moteur de conteneurisation au moment où il s'apprête à lancer le PID 1 du conteneur à émuler.

La solution ? Lancer le conteneur avec les options SELinux qui donne au conteneur les bonnes étiquettes SELinux afin que l'action soit autorisée.
C'est le rôle des options `--security-opt` :

- `label=filetype:container_file_t`: les fichiers de l'image de conteneur sont étiquetés avec le type SELinux **container_file_t**.
- `label=label=level:s0`: les fichiers de l'image de conteneur sont étiquetés avec le niveau SELinux **s0**.

Ces deux options, vous l'avez peut-être reconnu, font que les fichiers de notre image **localhost/qemu-user-static** ont l'étiquette SELinux des volumes partagés.
Le partage de ces fichiers est donc autorisé entre les conteneurs.

Les options `--security-opt label=type:spc_t` et `--privileged` permettent au conteneur de s'exécuter en root, de pouvoir procéder au montage du pseudo système de fichier **binfmt_misc** et d'enregistrer les binaires `qemu-*-static`.

La ligne de commande complète est :

```sh
sudo podman run --rm --privileged --security-opt label=filetype:container_file_t --security-opt label=level:s0 --security-opt label=type:spc_t localhost/qemu-user-static
```

Si vous oubliez ces options de sécurité, lorsque vous voudrez exécuter un conteneur dans une architecture différente, podman se terminera sans erreur mais sans rien exécuter...

Avec un peu de chance, vous repèrerez alors dans vos logs le message d'erreur suivant :

```
[10051.131634] audit: type=1400 audit(1749488918.807:3124): avc:  denied  { read execute } for  pid=32544 comm="dumb-init" path="/usr/bin/qemu-x86_64-static" dev="overlay" ino=434591 scontext=system_u:system_r:container_t:s0:c53,c117 tcontext=system_u:object_r:container_file_t:s0:c1022,c1023 tclass=file permissive=0
[10051.131656] audit: type=1701 audit(1749488918.807:3125): auid=10018 uid=1000 gid=1000 ses=1 subj=system_u:system_r:container_t:s0:c53,c117 pid=32544 comm="dumb-init" exe="/usr/bin/qemu-x86_64-static" sig=11 res=1
```

Même si ça peut sembler cryptique au premier abord, le message dit l'essentiel : tu essayes d'éxécuter (`{ read execute }`) un binaire (`/usr/bin/qemu-x86_64-static`) qui a l'étiquette `system_u:object_r:container_file_t:s0:c1022,c1023` depuis un processus qui a l'étiquette `system_u:system_r:container_t:s0:c53,c117` (notez la différence sur la fin de l'étiquette !) et cet accès est refusé (`avc: denied`).

## Conclusion

Ce sujet a été le caillou dans ma chaussure durant ces dernières semaines, je suis content d'être parvenu à trouver une solution !
Et j'espère que la dite solution vous sera autant utile à vous qu'elle l'a été pour moi.
