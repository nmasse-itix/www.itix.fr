---
title: "Red Hat Open Demo: Red Hat Open Demo-Build multi-architecture CI/CD pipelines to run your apps in the cloud and at the Edge!"
date: 2024-09-05T00:00:00+02:00
draft: false
resources:
- '*.jpeg'
- '*.png'
- '*.pdf'
# Featured images for Social Media promotion (sorted from by priority)
images:
- slide-cover.png
topics:
- Artificial Intelligence
- Edge Computing
---

On September 5, 2024, I presented a webinar named [Red Hat Open Demo-Build multi-architecture CI/CD pipelines to run your apps in the cloud and at the Edge!](https://events.redhat.com/profile/form/index.cfm?PKformID=0x11759490001), based on the technology intelligence I have gone through in the past months.

<!--more-->

In the rapidly advancing field of edge computing, deploying applications across diverse hardware platforms, such as ARM and x86_64, has become essential.
Multi-architecture container images have emerged as a powerful solution, supporting multiple processor architectures within a single image package and simplifying the deployment process across platforms.

{{< attachedFigure src="slide-arm-devices.png" >}}

During this demonstration, I explored how these multi-architecture images work seamlessly across different CPU architectures, automatically selecting the appropriate client architecture from a registry.
Using tools like Podman, Buildah, and Tekton, I showcased how easy it is to build these images.
Additionally, I demonstrated the robust support for multi-architecture CI/CD pipelines offered by platforms like Red Hat OpenShift on AWS.

Here’s what was covered during the demo:

- **Overview of Use Cases**: I began with a comprehensive overview of scenarios where multi-architecture support is critical, especially in edge and hybrid cloud environments.
  
- **Running OpenShift on AWS in Multi-Architecture Mode**: Participants saw OpenShift running in a multi-architecture setup on AWS, showcasing its flexibility in supporting nodes with multiple CPU architectures.

- **Persistent Storage for CI/CD Pipelines (AWS EFS)**: I explored the AWS Elastic File System (EFS) as a possible solution for persistent storage within CI/CD pipelines, for managing artifacts across nodes.

- **Multi-Architecture Pipelines for Quarkus, NodeJS, and Buildah**: The demo included a hands-on look at creating pipelines that support multiple architectures, focusing on Quarkus, NodeJS, and raw Containerfile with Buildah.
  This allowed participants to understand how to structure pipelines for a wide range of application types.

- **Tekton Task Binding to the Right Node**: I also demonstrated how Tekton tasks could be directed to specific nodes based on architecture, ensuring efficient execution across mixed environments.

{{< attachedFigure src="slide-architecture.png" >}}

Key Highlights from the Demo:

1. **Live Demonstration of an OpenShift Cluster with Mixed Architecture Nodes**: The highlight was the live showcase of an OpenShift cluster featuring ARM and x86_64 nodes, which enabled participants to observe multi-architecture functionality in real-time.

2. **Hands-on Session on Tekton Pipelines**: Attendees took part in a practical session focused on creating and managing Tekton pipelines for multi-architecture builds, covering both foundational setup and advanced configurations.

3. **Building and Pushing Multi-Architecture Container Images to quay.io**: I concluded with a real-time demonstration of building and pushing multi-architecture images to the quay.io registry, emphasizing the role of registry support in deploying cross-platform applications efficiently.

4. **Running the same container on two different CPU architectures**: I ran a container image built with the multi-architecture pipeline on both my Laptop (x86_64) and {{< internalLink path="/blog/homelab-server-2u-short-depth-front-io-ampere-altra-arm64-architecture/index.md" title="my Ampere Altra server" >}} (ARM64).

This demo has been designed for DevOps professionals, cloud architects, and developers looking to leverage OpenShift and AWS in multi-architecture container image creation.
The session provided them with both a high-level understanding and practical skills to implement and manage these capabilities in their environments.

If you have not been able to attend the live session, I invite you to [watch the replay](https://events.redhat.com/profile/form/index.cfm?PKformID=0x11759490001) and [download the slides](slides.pdf)!

If you are ready to dive deeper, have a look at the article I wrote on this subject: {{< internalLink path="/blog/build-multi-architecture-container-images-with-kubernetes-buildah-tekton-aws/index.md" >}}!
