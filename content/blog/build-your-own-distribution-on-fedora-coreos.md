---
title: "Build your own distribution based on Fedora CoreOS"
date: 2020-11-25T00:00:00+02:00
opensource:
- Fedora
---

[Fedora CoreOS](https://getfedora.org/fr/coreos) is a new Linux distribution from the [Fedora Project](https://docs.fedoraproject.org/en-US/project/) that features filesystem immutability (you cannot change the system while it is running) and atomic upgrades (you cannot break your system if there is a crash or power loss during the upgrade).
Upon installation, Fedora CoreOS (FCOS) can be tailored to your needs using [Ignition files](https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/).
Once installed, you can install RPMs, tweak configuration files, etc.

This article tries to explore Fedora CoreOS customizability one step further by building your own distribution based on Fedora CoreOS.
The idea would be to have everything wired in the Operating System image and minimal configuration in the Ignition file.

## Prerequisites

To build your own distribution based on Fedora CoreOS, you will need a Linux system (Fedora 33 has been used when writing this article) with **ostree**, **git**, **rclone** and **podman**.

```sh
sudo dnf install ostree git rclone podman
```

You will also use **cosa**, the [CoreOS Assembler](https://github.com/coreos/coreos-assembler).
Cosa is packaged as a container image and podman is used to run it.
A shell wrapper to run cosa is [provided](https://github.com/coreos/coreos-assembler/blob/master/docs/building-fcos.md#define-a-bash-alias-to-run-cosa) but it has some drawbacks, such as not working on ZSH.

Instead, create a shell script in **/usr/local/bin** that runs cosa:

```sh
cat > /usr/local/bin/cosa <<"EOF"
#!/bin/bash

podman run --rm -ti --security-opt label=disable --privileged --user=root                        \
           -v ${PWD}:/srv/ --device /dev/kvm --device /dev/fuse                                  \
           --tmpfs /tmp -v /var/tmp:/var/tmp --name cosa                                         \
           ${COREOS_ASSEMBLER_CONFIG_GIT:+-v $COREOS_ASSEMBLER_CONFIG_GIT:/srv/src/config/:ro}   \
           ${COREOS_ASSEMBLER_GIT:+-v $COREOS_ASSEMBLER_GIT/src/:/usr/lib/coreos-assembler/:ro}  \
           ${COREOS_ASSEMBLER_CONTAINER_RUNTIME_ARGS}                                            \
           ${COREOS_ASSEMBLER_CONTAINER:-quay.io/coreos-assembler/coreos-assembler:latest} "$@"
EOF
chmod +x /usr/local/bin/cosa
```

## Test your build chain

Cosa requires a dedicated **build directory** where it will store cached RPMs, built ostrees and installation images.

Create a dedicated build directory for cosa.

```sh
mkdir -p $HOME/tmp/fedora-coreos
```

Before trying to customize things, you should try to rebuild the Fedora CoreOS images from the [official Fedora CoreOS repository](https://github.com/coreos/fedora-coreos-config/tree/stable).
The **fedora-coreos-config** repository has three main branches: **stable**, **testing** and **next**, that match the three channels of Fedora CoreOS.
For a first try, the **stable** branch is a good choice.

Move to the build directory and initialize it with the Fedora CoreOS sources.

```sh
cd $HOME/tmp/fedora-coreos
cosa init --branch stable https://github.com/coreos/fedora-coreos-config.git
```

Then, **cosa fetch** will fetch the needed RPMs and meta-data.

```sh
cosa fetch
```

And **cosa build** will build the ostree and the qemu image.

```sh
cosa build
```

Finally, run **cosa buildextend** commands to generate the metal images + the Live ISO image.
The **metal4k** image is reused by the **buildextend-live** command to generate the Live ISO image, so do not skip it if you plan to generate the ISO image!

```sh
cosa buildextend-metal
cosa buildextend-metal4k
cosa buildextend-live
```

The generated ostree and images can be found under **./builds/latest/x86_64/**.

```
$ ls -lh builds/latest/*/fedora-coreos-*.{raw,qcow2,tar,iso}
-rw-r--r--. 1 nicolas nicolas 758M Nov 25 16:06 builds/latest/x86_64/fedora-coreos-32.20201125.dev.0-live.x86_64.iso
-r--r--r--. 1 nicolas nicolas 2.9G Nov 25 15:57 builds/latest/x86_64/fedora-coreos-32.20201125.dev.0-metal.x86_64.raw
-r--r--r--. 1 nicolas nicolas 2.9G Nov 25 15:58 builds/latest/x86_64/fedora-coreos-32.20201125.dev.0-metal4k.x86_64.raw
-r--r--r--. 1 nicolas nicolas 721M Nov 25 15:33 builds/latest/x86_64/fedora-coreos-32.20201125.dev.0-ostree.x86_64.tar
-r--r--r--. 1 nicolas nicolas 1.8G Nov 25 15:34 builds/latest/x86_64/fedora-coreos-32.20201125.dev.0-qemu.x86_64.qcow2
```

Congratulations, you successfully rebuilt Fedora CoreOS!

## How is built Fedora CoreOS

The directory **src/config** created by **cosa** is a checkout of the [official Fedora CoreOS repository](https://github.com/coreos/fedora-coreos-config/tree/stable).

Move to the **src/config** directory and discover the project structure.

```
cd src/config && tree
```

Cosa starts with the **manifest.yaml** that includes other YAML files under the **manifests** directory.
Those manifests specifies the RPMs to install, commands to execute, yum repos to activate, etc. to build the final ostree.

Whenever the manifest specifies a **repos** section, it looks for the corresponding **.repo** file. For instance, the **manifest.yaml** specifies:

```yaml
repos:
  - fedora-coreos-pool
```

And there is the matching **fedora-coreos-pool.repo** at the root of the git repository.

```
$ cat fedora-coreos-pool.repo
[fedora-coreos-pool]
name=Fedora coreos pool repository - $basearch
baseurl=https://kojipkgs.fedoraproject.org/repos-dist/coreos-pool/latest/$basearch/
enabled=1
repo_gpgcheck=0
type=rpm-md
gpgcheck=1
skip_if_unavailable=True
```

The **packages** and **packages-$arch** directives specify which packages to include in the images.
Which version of the packages to install is not part of the manifest but rather specified in the ***.lock** files.

```sh
ls -l manifest-lock.*
-rw-r--r--. 1 nicolas nicolas   657 25 nov.  15:24 manifest-lock.overrides.aarch64.yaml
-rw-r--r--. 1 nicolas nicolas   657 25 nov.  15:24 manifest-lock.overrides.ppc64le.yaml
-rw-r--r--. 1 nicolas nicolas   645 25 nov.  15:24 manifest-lock.overrides.s390x.yaml
-rw-r--r--. 1 nicolas nicolas   651 25 nov.  15:24 manifest-lock.overrides.x86_64.yaml
-rw-r--r--. 1 nicolas nicolas 25127 25 nov.  15:24 manifest-lock.x86_64.json
```

Those are generated automatically and promoted between environments to achieve reproducible builds.

There is also an **overlay.d** directory containing overlays.
Each overlay is a set of files to be included as-is in the final images.

The **live** directory is used to configure how the ISO installation medium is generated and the **image.yaml** file is used to configure how images are generated.

## Customize Fedora CoreOS

As explained in [official Fedora CoreOS repository](https://github.com/coreos/fedora-coreos-config/tree/stable#layout), the Fedora team prefers other distributions to include the **fedora-coreos-config** as a git submodule rather than forking it.

Create a new git repository and add the **fedora-coreos-config** repository as a git submodule.

```sh
GIT="$HOME/git/my-coreos-config"
mkdir -p "$GIT"
cd $GIT
git init
git submodule add -b stable https://github.com/coreos/fedora-coreos-config.git
```

Create an **overlay.d** directory and make symbolic links to the upstream overlays.

```sh
mkdir overlay.d
cd overlay.d
for f in ../fedora-coreos-config/overlay.d/*; do ln -s $f; done
cd ..
```

Re-use the **.lock** files from the upstream distribution so that we get the same RPM versions in our final images.

```sh
for i in fedora-coreos-config/manifest-lock.*; do ln -s "$i"; done
```

Create a symbolic link to the **fedora-coreos-pool.repo** file from the upstream distribution.

```sh
ln -s fedora-coreos-config/fedora-coreos-pool.repo
```

Create also a symbolic link to the **live** directory of the upstream distribution since you will re-use this part as-is.
Copy **image.yaml** (no symbolic link since you will modify its content later).


```sh
ln -s fedora-coreos-config/live
cp fedora-coreos-config/image.yaml .
```

For the sake of this demonstration, you can instruct **cosa** to add a specific RPM to the image and validate on the running system that the RPM has been installed.

Add a top-level manifest (**manifest.yaml**) that sources the upstream Fedora CoreOS manifest and install **hdparm** (or any other RPM of your choice).

```yaml
ref: my/${basearch}/coreos/stable
include: fedora-coreos-config/manifest.yaml

packages:
- hdparm

repos:
- fedora
```

Notice how we changed the ref of the generated ostree from 'fedora/${basearch}/coreos/stable' to '**my**/${basearch}/coreos/stable' in order to differentiate the two distributions.

Since **hdparm** is part of the **fedora** repositories, do not forget to copy **fedora.repo** from the upstream distribution and disable the signature check (the **gpgkey** field points to a file that is not part of the upstream git repository).

```sh
cp fedora-coreos-config/fedora.repo .
sed -i -e 's|gpgcheck=.*|gpgcheck=0|' fedora.repo
```

Commit all your changes to your git repository since it is mandatory for cosa to have at least one commit in your git repository.

```
git add .
git commit -m 'initial commit'
```

At this point, you should be able to build your custom CoreOS distribution using the **cosa init**, **cosa fetch** and **cosa build** commands.
There is however one subtlety: since you have not yet pushed your changes to a remote git repository, **cosa init** will not be able to fetch them.
Hopefully, the **COREOS_ASSEMBLER_CONFIG_GIT** environment variable can be used to point cosa to a local copy of the git repository.

Create a new build directory and initialize it with the Fedora CoreOS sources.
It does not matter which git repository you specify here, it is only to make **cosa init** happy.
The **COREOS_ASSEMBLER_CONFIG_GIT** environment variable will properly replace it with the specified local copy.

Please note that it is **mandatory** to have the build directory **outside** your git repository.
This is a hard requirement from **cosa**.

```sh
BUILD="$HOME/tmp/my-coreos"
mkdir -p "$BUILD"
cd "$BUILD"
cosa init https://github.com/coreos/fedora-coreos-config.git
```

You can then build your custom CoreOS distribution with the following commands.

```sh
export COREOS_ASSEMBLER_CONFIG_GIT="$GIT"
cosa fetch
cosa build
cosa buildextend-metal
cosa buildextend-metal4k # metal4k is needed to generate the livecd
cosa buildextend-live
```

## Test your custom CoreOS distribution

Simply run **cosa run** to boot a Virtual Machine with your last build.

```sh
cosa run
```

You can assert that the **hdparm** command (or the RPM of your choice) has been installed!

```
Fedora CoreOS 32.20201124.dev.3
Tracker: https://github.com/coreos/fedora-coreos-tracker
Discuss: https://discussion.fedoraproject.org/c/server/coreos/

Last login: Wed Nov 25 16:56:11 2020
[core@cosa-devsh ~]$ hdparm -V
hdparm v9.58
```

While you are testing your new distribution image, have a look at the configured **ostree remotes**.

```
[core@cosa-devsh ~]$ sudo ostree remote list
fedora
fedora-compose
[core@cosa-devsh ~]$ sudo ostree remote show-url fedora
https://ostree.fedoraproject.org
```

As you can see, our custom image is configured to point to the upstream Fedora CoreOS servers for update.
As a result, you cannot update the distribution Over-the-Air!
Currently, updating your distribution would require re-flashing all your servers or devices with the new image.

```
[core@cosa-devsh ~]$ sudo rpm-ostree upgrade
error: While pulling my/x86_64/coreos/stable: No such branch 'my/x86_64/coreos/stable' in repository summary
```

To have a working custom distribution based on Fedora CoreOS, you have to to upload the generated **ostree** somewhere and point the generated images to your servers.

## Distribute updates Over-the-Air

To distribute updates Over-the-Air, the generated ostree needs to be exposed through a web server somewhere on the internet.
In this article I used an S3 bucket hosted at Backblaze B2 but you can use any provider that offers to serve static files over HTTP.

Create a new public bucket for your ostree, generate an application key and [find the bucket public url](https://www.backblaze.com/blog/b2-for-beginners-inside-the-b2-web-interface/).

Configure **rclone** to connect to your new bucket using the **rclone config** command.

Create a new directory to hold your distribution ostree and initialize it.

```sh
OSTREE="$HOME/tmp/my-distribution-ostree"
mkdir -p "$OSTREE"
ostree init --repo="$OSTREE" --mode=archive
```

Extract the generated **ostree** from the last build and import it into your distribution ostree.

```sh
cd "$BUILD"
rm -rf tmp/build-repo
mkdir -p tmp/build-repo
tar -xf builds/latest/*/fedora-coreos*ostree*.tar -C tmp/build-repo
ostree --repo="$OSTREE" pull-local tmp/build-repo my/x86_64/coreos/stable
```

Mirror your distribution ostree to your S3 bucket.

```sh
S3_BUCKET="backblaze:my-ostree"
rclone sync -P "$OSTREE" "$S3_BUCKET"
```

## Test your updates

Boot a Virtual Machine with your last cosa build in order to check that updates are working.

```sh
cosa run
```

Add a new ostree remote that points to the public URL of your S3 bucket.

```sh
sudo ostree remote add my-ostree https://f003.backblazeb2.com/file/my-ostree/ --no-gpg-verify
```

Issue an **rpm-ostree rebase** command to switch to your custom ref.

```sh
sudo rpm-ostree rebase -m my-ostree -b my/x86_64/coreos/stable
```

If this step completes successfully, this confirms your update service is working!

## Ship images with updates enabled

Now that your update service is working, it would be nice if the generated images could be configured with the correct ostree remote and ref.

Create a new overlay in **overlay.d** and scaffold the folder hierarchy for **/etc/ostree/remotes.d/**.

```sh
cd "$GIT"
mkdir -p overlay.d/99my/etc/ostree/remotes.d/
```

Add the new ostree remote by creating **my-ostree.conf** under **overlay.d/99my/etc/ostree/remotes.d/**.
Do not forget to change the URL to match your S3 bucket public URL!

```sh
[remote "my-ostree"]
url=https://f003.backblazeb2.com/file/my-ostree/
gpg-verify=false
```

Add a new **postprocess** directive to **manifest.yaml** that will remove the upstream **fedora** remote.

```yaml
ref: my/${basearch}/coreos/stable
include: fedora-coreos-config/manifest.yaml

packages:
- hdparm

repos:
- fedora

postprocess:
  # remove the "fedora" ostree remote
  - |
    #!/usr/bin/env bash
    set -xeuo pipefail
    rm /etc/ostree/remotes.d/fedora.conf
```

Finally, edit **image.yaml** to change the **ostree-remote** directive.

```yaml
[...]

# Optional remote by which to prefix the deployed OSTree ref
ostree-remote: my-ostree

[...]
```

## Rebuild everything

Rebuild your whole distribution with **cosa fetch**, **cosa build**, **cosa buildextend-\***.
Extract the generated ostree from the last build and import it into your distribution ostree, with the **tar** and **ostree pull-local** commands.
Mirror your distribution ostree to your S3 bucket with **rclone sync**.

Run your last built image with **cosa run** and issue a **sudo rpm-ostree upgrade** to ensure updates are working.

Since this is a lot of steps, you might want to [automate everything with a script or playbook](https://github.com/nmasse-itix/itix-coreos-config/blob/main/build.sh).

## Conclusion

This article explored the required steps to produce a custom distribution based on Fedora CoreOS, including the **git repository layout**, the **build chain**, the **update service** and the **testing** of the generated images.

Of course, this article only scratches the surface and many more steps are required to build a real distribution (such as GPG signing, security updates, CI testing, etc.) but I hope it gave you a good overview!
