---
title: "Sécurisez vos applications avec Red Hat SSO!"
date: 2021-11-26T00:00:00+02:00
draft: false
opensource: 
- Keycloak
topics:
- Security
---

Je signe ce mois-ci un article sur Red Hat SSO (la distribution de Keycloak éditée par Red Hat) dans le Hors série #5 du magazine *Programmez!*

<!--more-->

## Sommaire

\- Du SSO dans vos projets !  
\- Déploiement dans OpenShift  
\- Première connexion et création d'un royaume  
\- Sécurisation d'une application Quarkus  
\- Mise en place de l'authentification  
\- Gestion des habilitations  
\- Traçabilité

[Achetez le Hors série #5 de Programmez!](https://www.programmez.com/magazine/programmez-hors-serie-5-pdf) et retrouvez le code sur [github.com](https://github.com/nmasse-itix/programmez-article-sso) !

## Pour aller plus loin…

Dans cette section, qui n'a pu être intégrée au magazine faute de place, je vous propose quelques exercices pour aller plus loin avec Red Hat SSO.

* Dans la partie Realm Settings du royaume "master", changez la durée d’inactivité de la session (onglet **Tokens**, paramètre **SSO Session Idle**) à 8h.
  Ainsi vous pourrez travailler sur l’interface Red Hat SSO toute une journée sans être déconnecté !
* Exportez votre royaume en allant dans **Manage** > **Export** et en cochant toutes les options.
  Le fichier généré est au format JSON et ses secrets ont été caviardés : il ne vous reste plus qu’à le sauvegarder dans votre repository Git !
* Red Hat SSO peut charger ce fichier JSON au démarrage si vous le lui demandez via les *System Properties* `keycloak.migration.*` (la procédure est dans la documentation).
  C’est utile pour disposer d’une instance neuve et pré-configurée avant les tests.
* Dans le royaume "master", allez dans la section **Manage** > **Identity Providers** et ajoutez un fournisseur d’identité de type **OpenShift v4**.
  Vous pourrez ainsi vous connecter à votre instance Red Hat SSO en utilisant votre session OpenShift.
  Pratique !
  Le formulaire vous demande un Client ID et un Client Secret que vous obtiendrez en créant une CRD de type `OAuthClient` dans OpenShift.
