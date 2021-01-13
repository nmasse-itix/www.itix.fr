---
title: "Implémenter le motif de conception 'Strangler Fig' dans OpenShift"
date: '2021-01-13T00:00:00+02:00'
#description: ""
opensource:
- OpenShift
topics:
- Containers
resources:
#- src: '*.yaml'
#- src: '*.png'
---

Le motif de conception [Strangler Fig](https://docs.microsoft.com/en-us/azure/architecture/patterns/strangler-fig) a été documenté par [Martin Fowler](https://martinfowler.com/bliki/StranglerFigApplication.html) en 2004.
Il fait référence à un arbre nommé le "[figuier étrangleur](https://fr.wikipedia.org/wiki/Figuier_%C3%A9trangleur)" qui s'appuie sur son hôte pour ses premières années de vie, jusqu'à ce que ses racines touchent le sol.
Il peut ainsi se nourrir et grandir de manière autonome.
Son hôte sert alors de support et finit par mourir "étranglé".

C'est une analogie avec la ré-ingénierie d'un système en production: les composants d'un monolithe sont réécrits un à un, sous forme de micro-services, à coté du système existant.
Les composants du monolithe sont alors remplacés au fil de l'eau par leur équivalent micro-service.
Une fois tous les composants du monolithe remplacés, il peut alors être décommissionné.

La question qui m'a été posée est: est-il possible d'implémenter ce motif à l'aide des outils et fonctions d'OpenShift ?

<!--more-->

La réponse est **oui** et les fonctions de *Path Routing* d'OpenShift 4 sont faites pour cela !

## Path Routing dans OpenShift&nbsp;4

Les fonctions de *Path Routing* permettent l'implémentation du motif de conception **Strangler Fig** et sont présentes depuis OpenShift 3.
La documentation de la version 4 ne mentionne plus cette possibilité mais [Red Hat a bien confirmé que ces fonctions sont toujours supportées](https://access.redhat.com/solutions/4675571).

La [documentation de la version 3 sur le *Path Routing*](https://docs.openshift.com/container-platform/3.11/architecture/networking/routes.html#path-based-routes) reste valable pour la version 4.

## Cas pratique

Imaginons un monolithe portant deux fonctions métiers *APP1* et *APP2*.
Pour l'exemple, ce monolithe sera simulé par un serveur *Nginx* servant les fonctions *APP1* sur /APP1/index.html et *APP2* sur /APP2/index.html.

Commençons par créer un projet dédié à cet exemple.

```sh
oc new-project strangler-fig
```

Puis, déployons notre monolithe (simulé ici par un Nginx).

```sh
oc new-build --name monolith --strategy=docker --docker-image quay.io/centos7/nginx-116-centos7:1.16 -D - <<EOF
FROM quay.io/centos7/nginx-116-centos7:1.16
RUN mkdir -p /tmp/src/APP1/ /tmp/src/APP2/ \
 && echo OLDAPP1 > /tmp/src/APP1/index.html \
 && echo OLDAPP2 > /tmp/src/APP2/index.html \
 && chown 1001:0 -R /tmp/src

RUN /usr/libexec/s2i/assemble
CMD /usr/libexec/s2i/run
EOF
oc logs -f bc/monolith
oc new-app --name monolith -i monolith
```

Le monolithe est alors exposé sous la forme d'une route OpenShift.

```sh
oc create route edge mon-appli --service=monolith --hostname=mon-appli.apps.ocp4.itix.fr
```

**Note:** Les fonctions de *Path Routing* nécessitent une route de type *Edge* ou *Reencrypt*.
Dans le cas d'une route *Passthrough*, le flux TLS n'est pas déchiffré par le routeur OpenShift et les fonctions de *Path Routing* ne peuvent pas être appliquées.

Une rapide vérification nous confirme de que les deux fonctions métiers du monolithe sont bien exposées.

```
$ curl https://mon-appli.apps.ocp4.itix.fr/APP1/index.html
OLDAPP1

$ curl https://mon-appli.apps.ocp4.itix.fr/APP2/index.html
OLDAPP2
```

Imaginons maintenant que la fonction métier *APP1* a été réécrite sous la forme d'un micro-service.
Déployons ce micro-service à coté du monolithe.

```sh
oc new-build --name new-svc-1 --strategy=docker --docker-image quay.io/centos7/nginx-116-centos7:1.16 -D - <<EOF
FROM quay.io/centos7/nginx-116-centos7:1.16
RUN mkdir -p /tmp/src/APP1/ \
 && echo NEWAPP1 > /tmp/src/APP1/index.html \
 && chown 1001:0 -R /tmp/src

RUN /usr/libexec/s2i/assemble
CMD /usr/libexec/s2i/run
EOF
oc logs -f bc/new-svc-1
oc new-app --name new-svc-1 -i new-svc-1
```

Nous pouvons ensuite créer une route pour ce micro-service sur le même nom d'hôte que le monolithe mais en spécifiant le préfixe du chemin d'accès à la fonction *APP1* (paramètre `--path`).

```sh
oc create route edge new-svc-1 --service=new-svc-1 --hostname=mon-appli.apps.ocp4.itix.fr --path=/APP1
```

Sans surprise, la fonction métier *APP1* a bien été routée vers le micro-service.
La fonction métier *APP2* est toujours servie par le monolithe.

```sh
$ curl https://mon-appli.apps.ocp4.itix.fr/APP1/index.html
NEWAPP1

$ curl https://mon-appli.apps.ocp4.itix.fr/APP2/index.html
OLDAPP2
```

Il est important de noter que le micro-service remplaçant *APP1* a été obligé de conserver l'ensemble des URLs de *APP1* inchangées.
C'est une contrainte à prendre en compte au moment des spécifications.

Pour rendre le cas pratique un peu plus concret, imaginons que le micro-service remplaçant *APP2* ne respecte pas cette contrainte et qu'il a été décidé d'exposer l'ensemble des services d'APP2 à la racine.

Déployons ce nouveau micro-service à coté du monolithe.

```sh
oc new-build --name new-svc-2 --strategy=docker --docker-image quay.io/centos7/nginx-116-centos7:1.16 -D - <<EOF
FROM quay.io/centos7/nginx-116-centos7:1.16
RUN mkdir -p /tmp/src \
 && echo NEWAPP2 > /tmp/src/index.html \
 && chown 1001:0 -R /tmp/src

RUN /usr/libexec/s2i/assemble
CMD /usr/libexec/s2i/run
EOF
oc logs -f bc/new-svc-2
oc new-app --name new-svc-2 -i new-svc-2
```

Nous pouvons ensuite créer une route pour ce micro-service sur le même nom d'hôte que le monolithe mais en spécifiant le préfixe du chemin d'accès à la fonction *APP2* (paramètre `--path`).
Afin d'accommoder le changement d'URL entre le monolithe et le micro-service le remplaçant, nous utilisons [une annotation de route](https://docs.openshift.com/container-platform/4.6/networking/routes/route-configuration.html#nw-route-specific-annotations_route-configuration) (commande `oc annotate`).

```sh
oc create route edge new-svc-2 --service=new-svc-2 --hostname=mon-appli.apps.ocp4.itix.fr --path=/APP2
oc annotate route/new-svc-2 haproxy.router.openshift.io/rewrite-target=/
```

Toujours sans surprise, la fonction métier *APP2* a bien été routée vers le micro-service.

```
$ curl https://mon-appli.apps.ocp4.itix.fr/APP1/index.html
NEWAPP1

$ curl https://mon-appli.apps.ocp4.itix.fr/APP2/index.html
NEWAPP2
```

Maintenant que toutes les fonctions métiers du monolithe ont été remplacées par leur équivalent en micro-service, le monolithe peut être décommissionné.

```sh
oc delete bc,is,svc,deploy,route monolith
```

## Et si mon monolithe n'est pas dans OpenShift ?

Au début de cet article, j'ai pris l'hypothèse que le monolithe était déployé dans OpenShift mais cela n'est pas toujours le cas.
Parfois, seuls les micro-services remplaçant le monolithe sont éligibles à un déploiement sur OpenShift.
Dans ce cas de figure, il reste néanmoins possible de mettre en œuvre le motif de conception *Strangler Fig* dans OpenShift 4 !

Pour ce faire, nous aurons besoin de déclarer l'adresse du monolithe dans OpenShift, sous la forme d'un *Service* et d'un *Endpoints*.

L'objet *Service* est de type *Headless*, c'est à dire qu'il n'y a pas d'adresse IP interne affectée à ce service.
Il précise également les ports sur lequel le monolithe est joignable.

```yaml
kind: "Service"
apiVersion: "v1"
metadata:
  name: "monolith"
spec:
  clusterIP: None
  ports:
  - name: "http"
    protocol: "TCP"
    port: 80
    targetPort: 80
    nodePort: 0
selector: {}
```

L'objet *Endpoints* reprend les ports du monolithe et précise son adresse IP.
En guise de démonstration, j'ai mis ici l'adresse IP du service *ftp.lip6.fr*.

```yaml
kind: "Endpoints"
apiVersion: "v1"
metadata:
  name: "monolith"
subsets:
- addresses:
  - ip: "195.83.118.1" 
  ports:
  - port: 80
    name: "http"
    protocol: TCP
```

Nous pouvons créer la route associée.

```sh
oc create route edge mon-appli --service=monolith --hostname=mon-appli.apps.ocp4.itix.fr
```

Si vous ouvrez la route dans votre navigateur, vous verrez apparaitre la page d'accueil du miroir *ftp.lip6.fr* proxyfié par OpenShift.

Le reste de la procédure (création des deux micro-services avec le *Path Routing* associé) est identique.

## Pour aller plus loin

Il peut exister d'autre cas où le micro-service nécessiterait plus qu'un simple routage sur l'URL.
Notamment lorsqu'il est nécessaire d'enrichir le contenu de la réponse avec la réponse d'un autre micro-service.

On peut imaginer que l'affichage du détail d'une commande affiche les informations client et les informations de facture.
Si ces deux fonctions sont découpées en deux micro-services distincts, il peut être nécessaire de faire l'intégration du tout dans un troisième micro-service.

Ce cas de figure dépasse ce qui est disponible en standard dans OpenShift.
Il faudra alors se tourner vers [Red Hat Fuse](https://www.redhat.com/fr/technologies/jboss-middleware/fuse) / [Apache Camel](https://camel.apache.org/).

## Conclusion

Cet article a présenté le motif de conception *Strangler Fig* et son implémentation dans OpenShift au moyen de la fonction *Path Routing*.
