---
title: "Mettre à jour la configuration de l'Identity Provider OpenShift, version ceinture, bretelles et parachute"
date: 2023-12-18T00:00:00+02:00
opensource: 
- OpenShift
---

Depuis OpenShift 4, la configuration de l'*Identity Provider* OpenShift est gérée sous la forme de *Custom Resource Definitions* (CRD) Kubernetes.
Ce mécanisme permet de modifier sa configuration en utilisant l'API Kubernetes.
Mais si l'accès à l'API Kubernetes est soumis à l'authentification du dit *Identity Provider*, n'y a t'il pas un risque de se retrouver dehors avec la clé à l'intérieur ?
Effectivement, c'est un risque.

Dans cet article, je présente une méthode pour mettre à jour la configuration de l'*Identity Provider* OpenShift quand on n'a ni le mot de passe **kubeadmin**, ni le fichier **kube.config** généré à l'installation.

<!--more-->

Mettre à jour la configuration de l'*Identity Provider* OpenShift, c'est prendre le risque de se retrouver dehors avec la clé à l'intérieur.
Pour éviter cela, j'essaie d'avoir toujours une solution "ceinture, bretelles et parachute".

La ceinture, c'est le contrôle de surface appliqué par l'opérateur **authentication** d'OpenShift : si je me trompe dans le nom d'un champ ou sa syntaxe, une erreur est levée et la configuration n'est pas appliquée.

Les bretelles, c'est la session CLI ou Console avec les privilèges **cluster-admin**, que je garde bien précieusement à portée de main.

Et si tout ça échoue, il me faut le parachute !
Mon parachute, dans cet article, c'est le *Service Account* ayant des droits **cluster-admin**.

Je commence donc par créer un projet temporaire.

```
$ oc new-project tmp-auth

Now using project "tmp-auth" on server "https://api.workshop-opp.sandbox2156.opentlc.com:6443".

You can add applications to this project with the 'new-app' command. For example, try:

    oc new-app rails-postgresql-example

to build a new example application in Ruby. Or use kubectl to deploy a simple Kubernetes application:

    kubectl create deployment hello-node --image=registry.k8s.io/e2e-test-images/agnhost:2.43 -- /agnhost serve-hostname

```

Je crée ensuite un objet *Service Account*.

```
$ oc create serviceaccount backdoor
serviceaccount/backdoor created
```

Je donne les droits **cluster-admin** à ce *Service Account*.

```
$ oc adm policy add-cluster-role-to-user cluster-admin -z backdoor -n tmp-auth
clusterrole.rbac.authorization.k8s.io/cluster-admin added: "backdoor"
```

Je récupère le jeton d'authentification du *Service Account*.

```
$ oc get secrets -o name | sed -r 's|^(secret/backdoor-token-.*)$|\1|;t;d'
secret/backdoor-token-dx5lv

$ SECRET_NAME=$(oc get secrets -o name | sed -r 's|^(secret/backdoor-token-.*)$|\1|;t;d')

$ mkdir /tmp/backdoor
$ oc extract $SECRET_NAME --to=/tmp/backdoor
/tmp/backdoor/ca.crt
/tmp/backdoor/namespace
/tmp/backdoor/service-ca.crt
/tmp/backdoor/token
```

Et enfin, je récupère une session CLI en utilisant ce jeton.

```
$ oc login --token $(cat /tmp/backdoor/token)

Logged into "https://api.workshop-opp.sandbox2156.opentlc.com:6443" as "system:serviceaccount:tmp-auth:backdoor" using the token provided.

You have access to 127 projects, the list has been suppressed. You can list all projects with 'oc projects'

Using project "tmp-auth".

$ oc whoami
system:serviceaccount:tmp-auth:backdoor
```

Et comme l'authentification des *Service Accounts* ne dépend pas de la configuration de l'*Identity Provider* OpenShift, si quelque chose se passe mal, je peux toujours reprendre la configuration manuellement.

Évidemment, une fois la configuration validée, je peux supprimer mon *Service Account*, mon projet et enlever les droits **cluster-admin**.

```
$ oc adm policy remove-cluster-role-from-user cluster-admin -z backdoor -n tmp-auth
$ oc delete project tmp-auth
```

Est-il nécessaire de le faire à chaque modification de la configuration ? Non.
Mais quand le changement est important et qu'on n'a pas la possibilité de tester sa modification avant, c'est plus rassurant !
