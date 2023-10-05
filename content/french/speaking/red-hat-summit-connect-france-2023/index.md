---
title: "Red Hat Summit Connect France 2023"
date: 2023-10-03T00:00:00+02:00
draft: false
resources:
- '*.jpeg'
- src: slides.pdf
topics:
- Security
- DevOps
---

Le 3 Octobre 2023, j'ai participé au [Red Hat Summit Connect France 2023](https://www.redhat.com/en/summit/connect/emea/paris-2023) en tant que conférencier pour la *Keynote* d'ouverture sur les thèmes du **DevOps**, de l'**Intelligence Artificielle** et de la **Sécurité**. J'étais accompagné de ma collègue **Aude**, qui a présenté les annonces **Infrastructure** et **Automatisation**.
La salle était pleine et des caméras retransmettaient la *Keynote* dans les autres salles de **La Felicità**.
Il y avait plus de 600 personnes ce jour là.

Retrouvez ci-dessous les principaux éléments de ma *Keynote* !

{{< attachedFigure src="RedHat.HL-56.jpeg" >}}

Le DevOps est un sujet absolument **passionnant**, pour lequel les entreprises en attendent de **produire plus de valeur, avec toujours moins de coûts**.
Mais rien de tout cela n'est vraiment **nouveau**.
Le **cloud computing** et **l’open source** sont deux facteurs ayant facilité l'essor du DevOps:

- Le *cloud computing* a offert des APIs standardisées permettant la consommation de ressources informatiques.
- L'open source a offert de nombreux outils pour la pratique du DevOps.

Le logiciel est omniprésent dans nos vie.
Nous travaillons tous pour une entreprise qui produit du logiciel (les objets du quotidiens deviennent connectés, les marques se réapproprient le contact client avec des apps, etc).
Le logiciel apporte de nouveaux revenus et il est important de livrer ces nouvelles applications le plus rapidement possible.
Dans cet univers dopé au logiciel, les développeurs sont un peu les rockstars de cette nouvelle économie.
**Mais n’oublions pas ceux qui oeuvrent en coulisses !**

En coulisses, s’activent de nombreuses compétences qui sont nécessaires aux travail des développeurs : faire en sorte de choisir les outils, les mettre en oeuvre, vérifier que tout tourne.
Tout cela permet aux développeurs de se **concentrer sur ce qu’il font le mieux**: concevoir et façonner une application.
Cette discipline, c’est ce qu’on appelle le **Platform Engineering**.

Tout cela n’est pas complètement nouveau. C’est l’évolution naturelle des pratiques DevOps.
Mais le nombre d’outils grandit de jours en jours et la complexité croît de manière exponentielle.
Et c’est le risque de s’enliser dans une dette technique abyssale qui se creuse encore plus, jour après jour.
Chaque ajout d’un nouvel outil implique plus de complexité et du temps de formation que vous n’avez pas.

Un étude de 2022 a montré que pour **76% des organisations**, la charge cognitive est si forte pour les développeurs qu’elle est **source de peur et de baisse de productivité** pour eux.

La communauté Open Source est arrivée avec une solution à ce problème: **Backstage**.
Backstage, en anglais, ce sont les coulisses, tout ce qui permet aux rockstars de se produire en spectacle.
Backstage, c’est un IDP: **Internal Developer Platform**, une plateforme unique qui permet d’orchestrer, piloter tous les outils utilisés par les développeurs.

Red Hat offre une intégration et un packaging de Backstage dans une offre appelée **Red Hat Developer Hub**.
Developer Hub ajoute à Backstage le support de plugins essentiels développés par Red Hat, tels que **Quay** ou **Keycloak**.
On cherche à apporter une expérience développeur plus cohérente sans compromettre la célérité.
Developer Hub inclus également des *validated templates*.
Ce sont des motifs pré-conçus pour concevoir, façonner et déployer du logiciel.

Developer Hub vous offre une plateforme développeur Open Source, avec la stabilité, le support et la fiabilité que vous pouvez en attendre.
Developer Hub **est basé sur Red Hat OpenShift** et tire parti des compétences que vous avez déjà sur OpenShift.
Et c’est probablement l’information la plus importante de la journée : **si vous avez déjà OpenShift, Red Hat Developer Hub vous tend les bras pour améliorer la productivité de vos développeurs.**

{{< attachedFigure src="RedHat.HL-61.jpeg" >}}

Et je ne peux pas terminer cette partie sur le développement applicatif sans parler du sujet à la mode : **l’intelligence artificielle**.
L’IA est utilisée pour résoudre des problèmes compliqués, qui s’il devaient être implémentés de manière traditionnelle, ne le serait pas ou alors trop coûteux pour être rentable.
Que ce soit ChatGPT ou MidJourney, l’IA est aujourd’hui mise à disposition du grand public.
Et c’est très bien: l’IA a de nombreux impacts positifs sur la société : elle contribue à nous rendre plus efficaces, plus performants.

Il y a de fortes chances qu’en ce moment même, votre organisation soit en train d’étudier les usages de l’IA pour conquérir de nouveaux marchés, améliorer les marges, fiabiliser les processus, etc.
Si vous saviez développer des applications cloud native, en revanche, il va falloir **changer quelques habitudes pour les application faisant appel à l’IA** : entraînement, inférence, ré-entrainement, mise à disposition du modèle, les changements sont nombreux.
Ces nouveaux usages, cette nouvelle manière de travailler est coûteuse en ressources. Et vos centres de données actuels pourraient bien se retrouver limités.
Disons le clairement: **l’IA va vous inciter à consommer plus de services chez les cloud providers**. Et par là même, vous forcer à réfléchir à votre stratégie multi-cloud / hybrid cloud.

C’est pour vous accompagner dans ce changement que nous avons lancé **OpenShift AI**.
OpenShift AI, disponible dans le cloud et on-premises, permet de gérer vos services d’intelligence artificielle sur Red Hat OpenShift.
Il offre à vos Data Scientists et développeurs AI/ML la flexibilité, la **portabilité** et la **simplicité** nécessaires pour développer des applications basées sur l’IA.
OpenShift AI vous permet de créer, entraîner et mettre à disposition vos modèles.

Et après vous avoir parlé de DevOps et d’IA, abordons le thème de la sécurité informatique.

{{< attachedFigure src="RedHat.HL-65.jpeg" >}}

La sécurité informatique, c’est un peu le parent pauvre de notre industrie: **on y pense quand il est trop tard**, quand le problème est là.
Cette situation est exacerbée par la **complexité** et l’étendue des architectures logicielles.
Red Hat a 30 ans d’expérience dans l’écriture de code Open Source et la gestion de sa sécurité.
Et avec notre service cloud **Advanced Cluster Security**, nous vous aidons à assurer la sécurité, y compris dans les environnements mouvants et changeants.
En quelques mots : **aller vite sans compromettre la sécurité, telle est notre volonté**.

Nos clients sont en phase avec notre vision.
Ils nous disent : "Nous voulons mitiger les risques et gérer la sécurité et dans le même temps, livrer nos applications rapidement".
Facile à dire, plus difficile à faire.

Dans les années à venir, la résilience aux vulnérabilité deviendra une métrique clé de la santé des organisations.
La perfection n’existe pas, il faudra apprendre à trébucher sans tomber.
Et si le nombre d’attaques contre les entreprises semble sans limite, le nombre de statistiques effrayantes en matière de sécurité l’est tout autant.

En voici une : Sonatype rapporte une **augmentation astronomique de 742 % des attaques sur la *supply chain*** sur les trois dernières années, en moyenne annuelle.

Les organisations **subissent une pression pour cartographier le logiciel utilisé** et les procédures en place pour le gérer.
Cette pression vient des clients, du régulateur et du risque lié à l’image de marque.
Les outils de l’environnement de développement n’ont pas été prévus pour gérer les informations de provenance et les attestations.
Red Hat peut vous aider à répondre à ce défi de taille.
Mais plus vous attendez, plus la sécurité coûte cher.
Un problème corrigé en dev coûte moins cher qu’un problème en production.

**Tout ce que fait Red Hat est Open Source.**
Alors, si je vous dis que la sécurité doit commencer par les communautés Open Source, ce n’est pas une surprise pour vous.
En entreprise, les équipe DevOps et sécurité ont souvent des objectifs différents.
Pourtant leur collaboration est indispensable.
C'est pourquoi nous avons imaginé **une approche holistique de la sécurité logicielle dans un service unique et intégré**.
Notre objectif est de rendre nos clients plus confiant dans la sécurité des applications qu’ils conçoivent, façonnent et déploient production.

La base de **Red Hat Trusted Application Pipeline** vient du travail fondateur de Red Hat dans la création, le lancement et la maintenance du projet **Sigstore**.
La réussite du projet Sigstore est **la preuve de la capacité de Red Hat à insuffler le changement dans les communautés Open Source** et à apporter une plus grande confiance dans la sécurité de logiciels Open Source.
Le projet **Sigstore** offre aux communautés Open Source un moyen de signer leur code et livrables, assurant ainsi **l’intégrité, l’authentification et la traçabilité de toute la chaîne de dépendances de la *supply chain* Open Source**.
Nous pensons que l’ouverture et la transparence sont des caractéristiques **non négociables** de toute approche de la sécurité informatique.
Et c’est ainsi que le projet Sigstore est né.

Avec un fournisseur renommé comme Red Hat, nos clients peuvent avoir confiance dans les logiciels qu'ils utilisent.
Les développeurs peuvent publier de nouvelles versions et mises à jour de logiciels plus rapidement qu'auparavant.
Permettez-moi de vous présenter **Red Hat Trusted Software Supply Chain**, notre solution qui améliore la résilience aux vulnérabilités de la supply chain.
C’est une sélections de packages, bibliothèque et dépendances spécialement sélectionnés par Red Hat.
C’est également une plateforme de CI pour construire des applicatifs de manière sécurisée.

{{< attachedFigure src="RedHat.HL-63.jpeg" >}}

[Téléchargez les slides de ma Keynote !]({{< attachedFileLink src="slides.pdf" >}})

À l'année prochaine !
