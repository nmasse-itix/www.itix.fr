---
title: "Retour d’expérience sur la mise en place d’une chaîne d’intégration continue (CI) multi-architectures X86 et ARM"
date: 2025-05-23T00:00:00+02:00
draft: false
opensource: 
- Tekton
- OpenShift
topics:
- Continuous Integration
---

Développer sur une machine X86 pour du ARM ? Et si votre CI ne suivait pas ?

Dans un monde où les architectures X86 et ARM cohabitent — entre laptops, serveurs, mobiles, voitures et objets connectés — comment s’assurer que votre chaîne d’intégration continue (CI) est à la hauteur ?

Dans le numéro 269 de Programmez!, je partage mon retour d’expérience sur la mise en place d’une chaîne de CI multi-architectures, capable de gérer efficacement des workloads ARM et X86. Entre émulation Qemu, cloud AWS et homelab sur CPU Ampere Altra, je décortique plusieurs approches, leurs forces, leurs galères… et les compromis à faire.

<!--more-->

- Performances vs simplicité
- Cloud vs on-prem
- Orchestration Kubernetes, stockage partagé, binfmt, UID/GID, et plus encore…

Un article technique, concret, avec des conseils issus du terrain — et quelques sueurs froides 😅

👉 Rendez-vous en kiosque pour acheter le magazine [Programmez! n°269](https://www.programmez.com/magazine/programmez-269) et plongez dans les coulisses de cette CI multi-archi qui tourne (presque) comme sur des roulettes !
