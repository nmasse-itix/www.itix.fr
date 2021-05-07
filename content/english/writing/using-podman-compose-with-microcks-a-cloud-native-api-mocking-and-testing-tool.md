---
title: "Using Podman Compose with Microcks: A cloud-native API mocking and testing tool"
date: 2021-04-22T00:00:00+02:00
draft: false
opensource:
- Microcks
- Podman
---

Microcks is a cloud-native API mocking and testing tool. It helps you cover your API’s full lifecycle by taking your OpenAPI specifications and generating live mocks from them. It can also assert that your API implementation conforms to your OpenAPI specifications. You can deploy Microcks in a wide variety of cloud-native platforms, such as Kubernetes and Red Hat OpenShift. Developers who do not have corporate access to a cloud-native platform have used Docker Compose. Although Docker is still the most popular container option for software packaging and installation, Podman is gaining traction.

Podman was advertised as a drop-in replacement for Docker. Advocates gave the impression that you could issue alias docker=podman and you would be good to go. The reality is more nuanced, and the community had to work to get proper docker-compose support in Microcks for Podman.

This article discusses the barriers to getting Microcks to work with Podman and the design decisions we made to get around them. It includes a brief example of using Podman in rootless mode with Microcks.

[Continue reading on developers.redhat.com](https://developers.redhat.com/blog/2021/04/22/using-podman-compose-with-microcks-a-cloud-native-api-mocking-and-testing-tool/)

[Continue reading on microcks.io](https://microcks.io/blog/podman-compose-support/)
