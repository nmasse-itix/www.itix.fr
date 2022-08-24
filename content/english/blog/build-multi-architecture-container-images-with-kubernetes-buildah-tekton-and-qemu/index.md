---
title: "Build multi-architecture container images with Kubernetes, Buildah, Tekton and Qemu"
date: 2022-08-24T00:00:00+02:00
opensource:
- Kubernetes
- Tekton
- Buildah
topics:
- Containers
- Continuous Integration
resources:
- '*.png'
- '*.svg'
---

ARM servers are becoming mainstream (Ampere Altra server, Raspberry Pi SoC, etc.) and people start using them with containers and Kubernetes.
While [official Docker Hub images](https://hub.docker.com/search?q=&image_filter=official) are built for all major architectures, the situation is less clear for other Open Source projects.
It is possible to acquire an ARM server and use it to build container images, but it puts an additional constraint on the Continuous Integration chain.
This article explores another option: build ARM container images on a regular x86 server, using Kubernetes, Buildah, Tekton and Qemu.

<!--more-->

## Sample application

To illustrate this article, we will build a container image of [Samba](https://www.samba.org/) for x86_64 and ARMv8 architectures.
Images for other architectures can be built too by applying the same principles.

The Containerfile we will use is available on a [Git repository](https://github.com/nmasse-itix/buildah-multiarchitecture-build).
There is nothing special in it.
It uses CentOS Stream 9 for the base image, installs Samba, creates users and groups and specifies a custom entrypoint script.

```docker
FROM quay.io/centos/centos:stream9

RUN dnf install -y samba samba-client cifs-utils shadow-utils \
 && dnf clean all
VOLUME /srv/samba
EXPOSE 445

RUN groupadd -g 1000 itix \
 && useradd -d /home/nicolas -g itix -u 1000 -m nicolas

ADD entrypoint.sh /

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ ]
```

You may have noticed that buildah has a `--arch` option to build container images for other architectures.
To achieve this, it relies on **qemu** being installed and configured to run the actual commands of the `Containerfile`, translating the binaries from the target architecture (in our example, ARMv8) to the host architecture (usually an x86_64 server).

But with the default setup, if we try to build the container image for ARMv8 on a x86_64 server, it fails.

```
$ git clone https://github.com/nmasse-itix/buildah-multiarchitecture-build.git
$ cd buildah-multiarchitecture-build
$ buildah build -t localhost/samba:latest --arch arm64 --variant v8 . 

STEP 1/8: FROM quay.io/centos/centos:stream9
Trying to pull quay.io/centos/centos:stream9...
Getting image source signatures
Copying blob 79959ab2260f done  
Copying config ca251c790c done  
Writing manifest to image destination
Storing signatures
STEP 2/8: RUN dnf install -y samba samba-client cifs-utils shadow-utils  && dnf clean all
exec container process `/bin/sh`: Exec format error
error building at STEP "RUN dnf install -y samba samba-client cifs-utils shadow-utils  && dnf clean all": error while running runtime: exit status 1
```

The rest of this article explains the setup to **build container images for multiple architectures**, using **Kubernetes**, **Buildah**, **Tekton** and **Qemu**.

## Pre-requisites

The pre-requisites to **build container images for multiple architectures** are:

- a Kubernetes cluster with cluster-admin privileges (I tested this article on a [Minikube](https://minikube.sigs.k8s.io/docs/) instance)
- [Tekton Pipelines](https://tekton.dev/docs/pipelines/install/#installing-tekton-pipelines-on-kubernetes) installed on your Kubernetes cluster (at the time of writing this article, Tekton Pipelines was v0.39.0)

## Layout the building blocks!

Create a **ci** namespace to hold the configuration described in this article.

```sh
kubectl create namespace ci
```

Import the **git-clone** Task from the **Tekton Catalog**.

```sh
kubectl -n ci apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.8/git-clone.yaml
```

Create the **buildah** Task in the **ci** namespace as follow.

{{< highlightFile "task.yaml" "yaml" "hl_lines=9-10 25-29 31 44-46 64-66" >}}
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: buildah
spec:
  params:
  - name: buildahVersion
    type: string
  - name: buildahPlatforms
    type: array
  - name: outputContainerImage
    type: string
  workspaces:
  - name: src
    mountPath: /src
  - name: containers
    mountPath: /var/lib/containers
  steps:
  - name: buildah
    image: quay.io/containers/buildah:$(params.buildahVersion)
    workingDir: /src
    env:
    - name: TARGET_IMAGE
      value: "$(params.outputContainerImage)"
    securityContext:
      capabilities:
        add:
        - 'SYS_ADMIN'
      privileged: true
    args:
    - "$(params.buildahPlatforms[*])"
    script: |
      #!/bin/bash

      set -Eeuo pipefail

      function build () {
        echo "========================================================="
        echo " buildah build $TARGET_IMAGE for ${1:-default}"
        echo "========================================================="
        echo

        extra_args=""
        if [ -n "${1:-}" ]; then
          extra_args="$extra_args --platform $1"
        fi
        if [ -n "${CONTAINERFILE:-}" ]; then
          extra_args="$extra_args --file $CONTAINERFILE"
        fi

        buildah bud --storage-driver vfs --manifest tekton -t $TARGET_IMAGE $extra_args .
        echo
      }

      function push () {
        echo "========================================================="
        echo " buildah push $1"
        echo "========================================================="
        echo
        buildah manifest push --storage-driver vfs --all tekton "docker://$1"
        echo
      }

      for platform; do
        build "$platform"
      done

      push "$TARGET_IMAGE:latest"

      exit 0
{{< /highlightFile >}}

The important parts of the task have been highlighted:

- The task has a parameter named **buildahPlatforms** that receives the list of all architectures the container image has to be built for.
- The task needs to be privileged since it will spawn containers within its container.
- The script run by the task receives the **buildahPlatforms** parameter as command line arguments and iterate over them.

Create the **buildah-multiarch** Tekton Pipeline in the **ci** namespace as follow.
The highlighted part of the pipeline contains the list of the target architectures.

{{< highlightFile "pipeline.yaml" "yaml" "hl_lines=9-13" >}}
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: buildah-multiarch
spec:
  workspaces:
  - name: scratch
  params:
  - name: buildahPlatforms
    type: array
    default:
    - linux/x86_64
    - linux/arm64/v8
  - name: gitRepositoryURL
    type: string
  - name: outputContainerImage
    type: string
  tasks:
  # Clone the git repository
  - name: git-clone
    params:
    - name: url
      value: "$(params.gitRepositoryURL)"
    - name: verbose
      value: "false"
    workspaces:
    - name: output
      workspace: scratch
      subPath: src
    taskRef:
      name: git-clone
  # Build and push the container images
  - name: buildah
    runAfter:
    - git-clone
    params:
    - name: buildahVersion
      value: latest
    - name: outputContainerImage
      value: "$(params.outputContainerImage)"
    - name: buildahPlatforms
      value:
      - "$(params.buildahPlatforms[*])"
    workspaces:
    - name: src
      workspace: scratch
      subPath: src
    - name: containers
      workspace: scratch
      subPath: containers
    taskRef:
      name: buildah
{{< /highlightFile >}}

If the target container registry requires authentication to push a container image, you will need to create a **Service Account** and a **Secret**.

Create the **tekton-robot** Secret in the **ci** namespace as follow.

{{< highlightFile "serviceaccount.yaml" "yaml" "" >}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tekton-robot
secrets:
- name: quay-authentication
imagePullSecrets:
- name: quay-authentication
{{< /highlightFile >}}

Create the secret to authenticate against your target registry (quay.io in my case) as follow.

{{< highlightFile "secret.yaml" "yaml" "" >}}
apiVersion: v1
kind: Secret
metadata:
  name: quay-authentication
data:
  .dockerconfigjson: '[REDACTED]'
type: kubernetes.io/dockerconfigjson
{{< /highlightFile >}}

Note: you can get this secret, by creating a [Robot Account](https://docs.quay.io/glossary/robot-accounts.html) under your [Organization](https://docs.quay.io/glossary/organizations.html).
Then, you can assign it **write** permissions on the target repository.
Finally, you can click on your robot account and download the Kubernetes secret.

{{< attachedFigure src="quay-robot-account.png" title="Download the Kubernetes secret of your Quay robot account." >}}

At this stage, if you run the pipeline, it will fail and complains it cannot run ARMv8 binaries on a x84_64 host (**Exec format error**).

## Configure Qemu for multi-architecture build

Deploy **Qemu** on all the nodes of your Kubernetes cluster by creating the **multiarch-qemu** DaemonSet in the namespace of you choice as follow.

{{< highlightFile "daemonset.yaml" "yaml" "" >}}
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: multiarch-qemu
spec:
  selector:
    matchLabels:
      name: multiarch-qemu
  template:
    metadata:
      labels:
        name: multiarch-qemu
    spec:
      containers:
      - name: multiarch-qemu
        image: docker.io/multiarch/qemu-user-static:6.1.0-8
        command:
        - /bin/sh
        - -c
        - /register --reset --persistent yes && while :; do sleep 3600; done
        securityContext:
          privileged: true
{{< /highlightFile >}}

This DaemonSet will run a container that will configure Qemu, on each node of your Kubernetes cluster.

The DaemonSet requires to be privileged to configure **binfmt_misc** (see next section for more details).
It runs a script that registers Qemu with the binfmt_misc system and sleeps forever.

## Qemu configuration: under the hood

At this stage, you may be scratching your head, trying to understand how a DaemonSet can configure Qemu to work inside the buildah container.
If you want to discover the magic behind it, read on! Otherwise, just skim to the next section.

Buildah relies on the "Kernel Support for miscellaneous Binary Formats" ([binfmt_misc](https://docs.kernel.org/admin-guide/binfmt-misc.html)) to run binaries of other architectures when building container images.

**binfmt_misc** can be configured to call qemu when running, let's say of an ARMv8 binary on a x86_64 host.
But this configuration is not at the namespace level (ie. not per container): the configuration is global to the whole host.

Fortunatelly, the Kernel developers have found a workaround: if you pass the "F" flag in the binfmt_misc configuration, the qemu binary is loaded and kept in memory.

> The usual behaviour of binfmt_misc is to spawn the binary lazily when the misc format file is invoked. However, this doesn’t work very well in the face of mount namespaces and changeroots, so the F mode opens the binary as soon as the emulation is installed and uses the opened image to spawn the emulator, meaning it is always available once installed, regardless of how the environment changes.

To allow the qemu binary to be called from another container, you just need the qemu binaries to be statically compiled.

The **docker.io/multiarch/qemu-user-static** container image (the one used by the DaemonSet above) packages a statically linked qemu, along with a script to register it with **binfmt_misc** (with the "F" flag).
That's the magic behind it!

## Run the pipeline!

Create the **PipelineRun** in the **ci** namespace to start the pipeline.
Do not forget to change the **outputContainerImage** parameter to match the URL of your container registry!

{{< highlightFile "pipelinerun.yaml" "yaml" "hl_lines=13" >}}
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: buildah-multiarch-
spec:
  serviceAccountName: tekton-robot
  pipelineRef:
    name: buildah-multiarch
  params:
  - name: gitRepositoryURL
    value: https://github.com/nmasse-itix/buildah-multiarchitecture-build.git
  - name: outputContainerImage
    value: quay.io/nmasse_itix/samba
  workspaces:
  - name: scratch
    volumeClaimTemplate:
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
{{< /highlightFile >}}

You can follow the pipeline execution with the **tkn** command.

```sh
tkn -n ci pipelineruns logs -f
```

Once the pipeline finished, on my registry (Quay.io), I could see the container images for both architectures under the "latest" tag.

{{< attachedFigure src="quay-repository.png" title="On Quay.io, you can see the container images for both architectures: ARMv8 and x86_64." >}}

## Conclusion

This article went through the setup of a **multi-architecture Continuous Integration system**, based on **Kubernetes**, **Buildah** and **Tekton**.
It also revealed the magic behind the configuration of **binfmt_misc** in a Kubernetes environment.
