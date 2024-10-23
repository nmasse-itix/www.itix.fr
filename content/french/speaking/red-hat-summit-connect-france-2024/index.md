---
title: "Red Hat Summit Connect France 2024"
date: 2024-10-08T00:00:00+02:00
draft: false
resources:
- '*.jpeg'
- '*.png'
- '*.mp4'
# Featured images for Social Media promotion (sorted from by priority)
images:
- open-code-quest-microservices.png
- rhel-booth-mission-impossible-demo.jpeg
- rhel-booth-mission-impossible-demo-3.jpeg
topics:
- Developer Relations
- Site Reliability Engineer
- Artificial Intelligence
- Edge Computing
---

Le 8 Octobre 2024, j'ai participé au [Red Hat Summit Connect France 2024](https://www.redhat.com/fr/summit/connect/emea/paris-2024) à double titre :

- Je me suis occupé du Leaderboard de l'atelier **Open Code Quest** et j'ai assuré le rôle de SRE pour la plateforme de cet atelier.
- J'étais présent sur le stand RHEL pour présenter notre démo "Mission Impossible" avec le train Lego.

<!--more-->

## Open Code Quest : Une aventure technologique et héroïque

L'atelier **Open Code Quest** a rassemblé des passionnés de technologie dans un cadre immersif où se mêlaient innovation technologique et univers de super-héros.
L'objectif était d'offrir aux participants une découverte approfondie de Quarkus, OpenShift, OpenShift AI, saupoudrés d'une pincée de sécurité et avec une expérience développeur sans couture.
Le tout en les plongeant dans une aventure captivante où chaque exercice impliquait des super-héros.

Lors de cet atelier, les participants devaient développer pas moins de quatre micro-services pour construire une application de simulation de combat entre super héros et super villains.

{{< attachedFigure src="open-code-quest-microservices.png" >}}

Les micro-services ont été développés en Quarkus, le framework Java natif pour le cloud, en démontrant comment il peut transformer le développement d’applications en alliant rapidité de développement, légèreté et performance.
En particulier, Quarkus réduit considérablement l'empreinte mémoire des applications, tout en permettant un démarrage quasi instantané.

Nous avons également positionné en tête de pont **Red Hat Developer Hub**, la distribution Red Hat de **Backstage**, une plateforme open source développée par Spotify pour améliorer la gestion des environnements complexes.
**Red Hat Developer Hub** a captivé l'attention des participants en offrant une interface unifiée pour centraliser la gestion des microservices, pipelines CI/CD et autres outils essentiels au développement.
Son extensibilité a permis d'intégrer facilement des plugins adaptés aux besoins de l'atelier, simplifiant ainsi le cycle de vie des applications.
Pour les développeurs comme pour les architectes, **Red Hat Developer Hub** s'est révélé être un outil précieux, facilitant la collaboration et apportant une vision claire de l'infrastructure tout en améliorant la productivité.

Lors de l'**Open Code Quest**, nous avons également mis en lumière **Red Hat Trusted Application Pipelines**, un produit conçu pour sécuriser et automatiser la chaîne de construction des applications.
Basé sur les technologies **Tekton Chains** et **SBOM** (Software Bill of Materials), ce produit offre une traçabilité complète et garantit l'intégrité des composants logiciels à chaque étape du pipeline CI/CD.
Les participants ont pu découvrir comment ces outils permettent de renforcer la sécurité des déploiements en fournissant des preuves de conformité et en assurant la transparence sur les dépendances utilisées dans les applications.

Je vous laisse découvrir la liste complète de l'outillage utilisé dans l'atelier **Open Code Quest** :

{{< attachedFigure src="open-code-quest-namespaces.png" >}}

Avant et pendant l'**Open Code Quest**, la gestion de la **plateforme** a joué un rôle clé dans la réussite de l'événement.
En tant que membre organisateur, j’ai eu la responsabilité, avec [Sébastien Lallemand](https://sebastienlallemand.net/), de préparer, dimensionner, installer et configurer les huit clusters OpenShift nécessaires au bon déroulement des ateliers.
Cela comprenait un cluster central, un dédié à l'IA, et six autres réservés aux participants pour leurs missions.
Cette phase cruciale de préparation a permis de garantir une infrastructure stable et performante.
Pendant l’événement, mon rôle de SRE (Site Reliability Engineer) consistait à surveiller de près les métriques critiques, telles que l'utilisation des ressources, afin d'assurer une expérience fluide et optimale pour tous les participants.
Grâce à cette surveillance proactive nous avons pu offir une disponibilité constante des environnements et ainsi faciliter le bon déroulement de l'atelier.

{{< attachedFigure src="open-code-quest-clusters.png" >}}

Un autre défi que j'ai relevé pour l'Open Code Quest a été la création d'un **Leaderboard** destiné à favoriser l'émulation entre les participants.
Ce projet m'a demandé de sortir des sentiers battus, car j'ai dû utiliser des outils tels que **Prometheus** et **Grafana** pour une tâche à laquelle ils ne sont pas destinés : départager les participants par ordre d'arrivée.
En contournant les limites de ces technologies de monitoring, j'ai fait preuve de créativité pour concevoir un système de classement en temps réel.
Malgré la complexité technique, le résultat a dépassé nos attentes : le Leaderboard a stimulé la compétition (amicale) entre les participants, ajoutant une dimension dynamique et engageante à l'événement.

Pour nous, l'**Open Code Quest** a été bien plus qu’un simple atelier. C’était une journée où experts et débutants ont pu échanger, apprendre et s’amuser ensemble, tout en découvrant des technologies utiles aux développeurs et architectes.
Que ce soit pour l’accélération du développement avec Quarkus, la fluidité de l'expérience développeur avec Red Hat Developer Hub, la gestion de la sécurité de la *supply chain* avec **Red Hat Trusted Application Pipelines** ou l'utilisation de l’IA avec Quarkus, chaque outil a apporté une valeur concrète, démontrée au fil des exercices.

Nous avons également eu l'occasion de créer un environnement propice au réseautage, où les participants ont pu échanger avec des experts et leurs pairs.

En tant que membre de l'équipe organisatrice, je suis extrêmement fier du succès de l'**Open Code Quest**.
Ce workshop a montré que l’on peut allier apprentissage technique et divertissement dans un cadre immersif et stimulant. Nous remercions tous les participants pour leur engagement et leur enthousiasme, ainsi que nos partenaires pour leur soutien. Nous espérons vous revoir lors de nos prochains événements pour continuer à explorer ensemble les innovations technologiques qui transforment notre monde.

Envie d'en savoir plus sur le Leaderboard ?
Comment j'ai pris en compte les spécificités de Prometheus pour concevoir le Leaderboard ?
Comment j'ai calibré les bonus et accélérateurs pour favoriser la compétition et l'émulation ?

Tout est expliqué dans ces deux articles :

1. {{< internalLink path="/blog/behind-the-scenes-at-open-code-quest-how-i-designed-leaderboard/index.md" >}}
2. {{< internalLink path="/blog/behind-the-scenes-at-open-code-quest-how-i-implemented-leaderboard-with-acm/index.md" >}}

## Démo "Mission Impossible" : Lego, AI & Edge Computing

### Scénario

{{< attachedFigure src="mission-impossible-plot.png" >}}
{{< attachedFigure src="mission-impossible-scenario.png" >}}

### Sous le capot

{{< attachedFigure src="mission-impossible-hardware-architecture.png" >}}
{{< attachedFigure src="mission-impossible-software-architecture.png" >}}
{{< attachedFigure src="mission-impossible-ai.png" >}}

### Action !

{{< embeddedVideo src="mission-impossible-demo.mp4" autoplay="true" loop="true" muted="true" width="1920" height="1080" >}}
{{< attachedFigure src="rhel-booth-mission-impossible-demo.jpeg" >}}


## Conclusion

À l'année prochaine !
