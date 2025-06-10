---
title: "Running qemu-user-static with Podman"
date: 2025-06-10T00:00:00+02:00
opensource:
- Podman
- Qemu
topics:
- Containers
---

Recently, I had to run ARM64 containers on a customer's x86 laptop.
Easy, you might say: just install qemu-user-static on the laptop!
And you also have a ready-made container on Docker Hub, just in case!

That's it?
Not so sure...

<!--more-->

## Current situation

While it is easy to install **qemu-user-static** on **Fedora**, this is not the case for **CentOS Stream** or **Red Hat Enterprise Linux**.
You can always retrieve the package from a Fedora repository and install it on these Fedora downstream distributions.
This works, but it remains an orphaned package that will never be updated.

What about the image [docker.io/multiarch/qemu-user-static](https://hub.docker.com/r/multiarch/qemu-user-static) that can be found on Docker Hub?
It hasn't been updated in two years, and the latest version of qemu available is 7.2.
Considering that version 10 of qemu was released recently, this is a bit messy...

## TL;DR

Two one-liners, one for building the image and one for executing it.
Build the container image **localhost/qemu-user-static**:

```sh
sudo podman build -f https://red.ht/qemu-user-static -t localhost/qemu-user-static /tmp
```

Run **qemu-user-static**:

```sh
sudo podman run --rm --privileged --security-opt label=filetype:container_file_t --security-opt label=level:s0 --security-opt label=type:spc_t localhost/qemu-user-static
```

That's it!
You can now run a container image that is in a different hardware architecture than your machine.

Example:

```
$ arch
x86_64

$ podman run -it --rm --platform linux/arm64/v8 docker.io/library/alpine     
/ # arch
aarch64
```

## Image building

I chose to base my image on the official Fedora images (version 42 at the time of writing this article).
If you have already worked with the **docker.io/multiarch/qemu-user-static** image, you will see that I have modernized it a bit:

- No more scripts from the **qemu** repo, the **systemd-binfmt** component provides everything you need.
- No more options to pass during execution, the script unregisters all binaries registered with the **binfmt** subsystem and registers all its `qemu-*-static` binaries instead.

The result is stripped down:

```dockerfile
FROM quay.io/fedora/fedora:42

RUN dnf install -y qemu-user-static \
 && dnf clean all

ADD container-entrypoint /

ENTRYPOINT ["/container-entrypoint"]
CMD []
```

The **container-entrypoint** script is also reduced to the bare minimum:

```sh
#!/bin/sh

set -Eeuo pipefail

if [ ! -d /proc/sys/fs/binfmt_misc ]; then
    echo "No binfmt support in the kernel."
    echo "  Try: '/sbin/modprobe binfmt_misc' from the host"
    exit 1
fi

if [ ! -f /proc/sys/fs/binfmt_misc/register ]; then
    echo "Mounting /proc/sys/fs/binfmt_misc..."
    mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
fi

echo "Cleaning up..."
find /proc/sys/fs/binfmt_misc -type f -name 'qemu-*' -exec sh -c 'echo -1 > {}' \;

echo "Registering..."
exec /usr/lib/systemd/systemd-binfmt
```

## Execution

Once the image has been built, it must be executed so that the `qemu-*-static` binaries are registered with the **binfmt** system.
But there is a small subtlety: on a Linux distribution such as Fedora, CentOS Stream, or RHEL, the SELinux system keeps a close eye on things!
And if something tries to break through the containerization engine's security, SELinux detects it and the action is prohibited.

And that's exactly what happens when you naively run the previously built image: the `qemu-*-static` binaries have a SELinux label that prevents them from being executed by the containerization engine when it is about to launch PID 1 of the container to be emulated.

The solution? Launch the container with SELinux options that give the container the correct SELinux labels so that the action is allowed.
This is the role of the `--security-opt` options:

- `label=filetype:container_file_t`: the files in the container image are labeled with the SELinux type **container_file_t**.
- `label=label=level:s0`: the files in the container image are labeled with the SELinux level **s0**.

As you may have recognized, these two options ensure that the files in our image **localhost/qemu-user-static** have the SELinux label for shared volumes.
These files can therefore be shared between containers.

The options `--security-opt label=type:spc_t` and `--privileged` allow the container to run as root, mount the pseudo file system **binfmt_misc**, and register the `qemu-*-static` binaries.

The complete command line is:

```sh
sudo podman run --rm --privileged --security-opt label=filetype:container_file_t --security-opt label=level:s0 --security-opt label=type:spc_t localhost/qemu-user-static
```

If you forget these security options, when you try to run a container in a different architecture, podman will terminate without error but without executing anything...

With a bit of luck, you will then see the following error message in your logs:

```
[10051.131634] audit: type=1400 audit(1749488918.807:3124): avc:  denied  { read execute } for  pid=32544 comm="dumb-init" path="/usr/bin/qemu-x86_64-static" dev="overlay" ino=434591 scontext=system_u:system_r:container_t:s0:c53,c117 tcontext=system_u:object_r:container_file_t:s0:c1022,c1023 tclass=file permissive=0
[10051.131656] audit: type=1701 audit(1749488918.807:3125): auid=10018 uid=1000 gid=1000 ses=1 subj=system_u:system_r:container_t:s0:c53,c117 pid=32544 comm="dumb-init" exe="/usr/bin/qemu-x86_64-static" sig=11 res=1
```

Although it may seem cryptic at first glance, the message says it all: you are trying to execute (`{ read execute }`) a binary (`/usr/bin/qemu-x86_64-static`) that has the label `system_u:object_r:container_file_t:s0:c1022,c1023` from a process that has the label `system_u:system_r:container_t:s0:c53,c117` (note the difference at the end of the label!) and this access is denied (`avc: denied`).

## Conclusion

This issue has been a thorn in my side for the past few weeks, and I'm glad I finally found a solution!
I hope you find it as useful as I did.
