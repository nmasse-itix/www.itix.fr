---
title: "Red Hat Open Tour 2024 à Toulouse"
date: 2024-11-28T00:00:00+02:00
# Featured images for Social Media promotion (sorted from by priority)
images:
- cover1.webp
- cover2.webp
- cover3.webp
- cover4.webp
resources:
- '*.jpeg'
- '*.webp'
topics:
- Containers
- GitOps
- Artificial Intelligence
- Edge Computing
opensource:
- OpenShift
---

Le 28 Novembre 2024, j'ai participé à l'événement [Red Hat Open Tour](https://events.redhat.com/profile/form/index.cfm?PKformID=0x1275737abcd) durant lequel j'ai animé, avec mes collègues Adrien et Mourad, un atelier de travaux pratiques combinant **Edge Computing** et **Intelligence Artificielle**.

{{< attachedFigure src="mas-tolosa.jpeg" title="L'événement s'est déroulé au Mas Tolosa, à proximité de Toulouse." >}}

[L'énoncé de l'atelier](https://open-tour-2024.netlify.app/fr/) est basé sur ce que nous avions présenté lors du {{< internalLink path="/speaking/riviera-dev-2024/index.md" >}} : le scénario du 7ème opus de la saga **Mission Impossible: Dead Reckoning**... avec un train Lego !
**Ethan Hunt** a besoin d'aide pour arrêter le train.
Grâce un modèle d'intelligence artificielle conçu dans **OpenShift AI** et déployé sur un **Nvidia Jetson Orin** faisant tourner **Red Hat Device Edge**, le train reconnait les panneaux de signalisation et s'arrête tout seul !

L’atelier proposé lors de cet événement a offert une expérience unique aux participants en les embarquant dans un projet technologique ambitieux : exploiter une intelligence artificielle et des microservices, dans un contexte de Edge Computing, pour implémenter le pilote automatique d'un train Lego.

Ce défi a permis aux participants d'explorer de bout en bout les phases clés d’un cycle de développement moderne, incluant Intelligence Artificielle et Edge Computing, sans nécessiter de matériel spécialisé.

Les participants ont découvert les coulisses de l’entraînement d’un modèle IA grâce à une approche accessible.
L’accent a été mis sur l’utilisation des fonctionnalités d’**OpenShift AI** :

- Téléchargement de jeux de données hébergés dans des buckets S3.
- Création de données synthétiques et entraînement du modèle à travers des notebooks **Jupyter**.
- Exploitation de pipelines MLops pour tirer parti des GPU disponibles sur le cluster **OpenShift**.
- Tests d’inférence réalisés via des fonctionnalités intégrées de Model Serving.

Cette approche a permis de démystifier les étapes clés d'un projet d'Intelligence Artificielle.

{{< attachedFigure src="participants.jpeg" title="Les participants de cet atelier de travaux pratiques ont développé, durant 3 heures, le pilote automatique du train Lego." >}}

Pour rendre l’exercice accessible et réduire les prérequis matériels, la suite de l’atelier s’est appuyé sur une approche ingénieuse.
Plutôt que d’exiger un set Lego complet plus une carte Jetson Orin Nano par participant, tout a été conteneurisé et bouchonné :

- Des vidéos préenregistrées ont simulé les flux vidéo de la caméra.
- Les ordres destinés au Hub Lego étaient simplement affichés à l’écran, permettant aux participants d'observer le comportement simulé du train (accélérer, freiner, ralentir, etc).

Grâce à OpenShift DevSpaces, les participants ont pu se concentrer sur le code, sans se soucier de leur propre configuration locale.
Ce choix a non seulement réduit les coûts mais aussi permis une progression fluide, même pour les novices.

La dernière étape de l’atelier a mis en lumière l'utilité des pratiques DevOps :  

1. Construction d’images conteneurisées via des pipelines CI/CD multi-architecture.  
2. Déploiement dans un environnement de test où les microservices, bien que bouchonnés, restaient pleinement fonctionnels.  

Ces deux étapes ont démontré comment des technologies Cloud Native combinées à une approche GitOps peuvent simplifier et automatiser tout le processus depuis la construction de l'application jusqu'à son déploiement.

En choisissant de conteneuriser et bouchonner certains composants et en s’appuyant sur des outils comme **OpenShift AI** et **OpenShift DevSpaces**, cet atelier a prouvé qu’il est possible de transmettre des compétences avancées en IA, développement applicatif, DevOps et Edge Computing dans un cadre accessible, pédagogique et engageant.

Ce fût pour moi une vraie réussite qui illustre l’art de faire beaucoup avec peu.
