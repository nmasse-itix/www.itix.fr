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

Le 8 Octobre 2024, j'ai participé au [Red Hat Summit Connect France 2024](https://www.redhat.com/fr/summit/connect/emea/paris-2024) [💾](TODO) à double titre :

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

Une partie de la journée, j'étais sur le stand RHEL, accompagné de [Adrien](https://www.linkedin.com/in/adrien-legros-78674a133/), [Mourad](https://www.linkedin.com/in/mourad-ouachani-0734218/) et [Pauline](https://www.linkedin.com/in/trg-pauline/) pour installer la démo "Mission Impossible" et répondre aux questions du public.

Cette démo, nous l'avons conçue pour l'événement {{< internalLink path="/speaking/platform-day-2024/index.md" >}} sur le thème du dernier opus du film **Mission Impossible: Dead Reckoning**.
Dans cette démo, **Ethan Hunt** a besoin d'aide pour arrêter le train **Lego City #60337** avant qu'il ne soit trop tard !
Rien de moins que le sort de l'humanité est en jeu !

{{< attachedFigure src="mission-impossible-plot.png" >}}

Le scénario nécessite que **Ethan Hunt** monte à bord du train pour y connecter une carte **Nvidia Jetson Orin Nano** au réseau informatique du train et y déploie une IA qui reconnaitra les panneaux de signalisation et arrêtera le train à temps avant qu'il ne déraille !
Une console permettra d'avoir une vue déportée de la caméra de vidéo surveillance du train, avec les résultats de l'inférence du modèle d'IA incrustés.

{{< attachedFigure src="mission-impossible-scenario.png" >}}

Pour mettre en oeuvre cette démo, nous avons équipé le train **Lego** d'une carte **Nvidia Jetson Orin Nano**, d'une webcam et d'une batterie portable.
La carte Nvidia Jetson Orin est un System On Chip (SoC), elle comprend tout le matériel dont **Ethan Hunt** a besoin pour sa mission : CPU, RAM, stockage...
Ainsi qu'un un GPU pour accélérer les calculs !
Le Jetson reçoit le flux vidéo de la caméra embarquée et transmet les ordres au Hub **Lego** via le protocole **Bluetooth Low Energy**.
Il est alimenté via une batterie portable pour la durée de la mission.

{{< attachedFigure src="rhel-booth-mission-impossible-demo.jpeg" >}}

Nous sommes dans un contexte de Edge Computing.
Sur le Jetson, on a installé **Red Hat Device Edge**.
C’est une variante de Red Hat Enterprise Linux adaptée aux contraintes du **Edge Computing**.
On y a installé **Microshift**, le Kubernetes de Red Hat taillée pour le Edge.
Et dans Microshift, on a déployé *over-the-air* les microservices, un **broker MQTT** et le modèle d’intelligence artificielle.

Le Jetson est relié, pour la durée de la mission, à un cluster OpenShift dans le cloud AWS via une connexion 5G.
Dans le cloud AWS, on a une VM RHEL 9 qui nous permet de construire les images **Red Hat Device Edge** pour le SoC Jetson.
Dans le cluster OpenShift, l'application application de vidéo surveillance qui diffuse le flux vidéo de la caméra embarquée du train.
Le flux vidéo est relayé depuis le Jetson au travers d’un **broker Kafka** !
Il faut ajouter à cela des pipelines MLops pour entraîner le modèle d’IA.
Et enfin des pipelines CI/CD pour construire les images de conteneur de nos micro-services pour les architectures x86 et ARM.

{{< attachedFigure src="mission-impossible-hardware-architecture.png" >}}

Pour permettre à **Ethan Hunt** de mener à bien sa mission, il a fallu garantir la transmission de la donnée de bout en bout.
Pour cela, nous avons implémenté cinq services qui communiquent via un système d’envoi de messages asynchrone (**MQTT**).

Le premier service capture dix images par seconde à intervalle régulier.
Chaque image est redimensionnée en 600x400 pixels et encapsulée dans un événement avec un identifiant unique.
Cet événement est transmis au modèle d'IA qui l’enrichit avec le résultat de la prédiction.
Ce dernier est transmis à un service de transformation qui a pour rôle d'extraire l'action du train, la transmettre au contrôleur de train pour ralentir ou stopper le train et en parallèle envoyer l'événement au service de streaming (**Kafka**) déployé sur un Openshift distant, qui affiche en temps réel, les images et la prédiction.

{{< attachedFigure src="mission-impossible-software-architecture.png" >}}

Et enfin, il nous a fallu construire d’un modèle d’intelligence artificielle.
Pour cela, nous avons suivi les bonnes pratiques pour gérer le cycle de vie du modèle, c’est ce qu’on appelle le **MLOps** :

- **Acquérir la donnée** : Nous avons utilisé un jeu de donnée open source comprenant des données provenant d’une caméra embarqué sur une voiture, qui ont été annotées avec les panneaux rencontrés sur son trajet.
  Les photos ont été prises sur des routes dans l’union européenne et montrent donc des panneaux de signalisation "normalisés" (potentiellement un peu différents des panneaux **Lego**).
- **Développer un modèle d’IA** : Nous avons choisi un algorithme d’apprentissage et procédé à l'entraînement du modèle sur un cluster OpenShift avec des GPU pour accélérer le calcul.
- **Déployer le modèle** : Nous avons déployé le modèle dans un serveur d’inférence pour le consommer via des APIs.
  Il a fallu intégrer le modèle à l’architecture logicielle (via MQTT).
- **Mesurer les performances et ré-entraîner** : En observer le comportement du modèle, nous avons pu mesurer la qualité des prédictions et constater que tous les panneaux **Lego** n'était pas bien reconnus.
  Nous avons pris la décision de réentrainer le modèle en l’affinant avec un jeu de données enrichi.

{{< attachedFigure src="mission-impossible-ai.png" >}}

Si vous n'avez pas pu venir nous voir sur le stand, je vous propose une session de rattrapage dans la vidéo ci-dessous (capturée lors du {{< internalLink path="/speaking/platform-day-2024/index.md" >}}).
On y voit le train s'arrêter lorsqu'il détecte le panneau de signalisation correspondant.

{{< embeddedVideo src="mission-impossible-demo.mp4" autoplay="true" loop="true" muted="true" width="1920" height="1080" >}}

Cette démonstration permet de démontrer la pertinence des solutions Red Hat pour mener à bien des projets informatique combinant **Intelligence Artificielle** et **Edge Computing**, et ce à large échelle.

## Conclusion

À travers l'atelier **Open Code Quest** et la démonstration captivante du train **Lego**, les participants ont pu explorer des solutions innovantes pour le développement d’applications, l'Intelligence Artificielle, le *Edge Computing* et la sécurité de la *Supply Chain*.
Tout le travail autour de la plateforme ainsi que l'originalité du Leaderboard ont permis de dynamiser l’événement, renforçant la compétition amicale entre les participants tout en leur offrant une expérience technique et humaine que l'on espère inoubliable.

Pour moi, ce Red Hat Summit Connect a été l'occasion de mettre en valeur l'importance de technologies comme Quarkus et OpenShift, mais aussi de partager une aventure collective où chaque participant a pu repartir avec de nouvelles compétences, de l'inspiration, et l'envie de continuer à explorer ces solutions.
Nous espérons pouvoir continuer à faire évoluer cet événement pour offrir toujours plus de défis et d'innovations aux communautés de développeurs, architectes, et ingénieurs.
À très bientôt pour de nouvelles aventures technologiques !
