---
title: "Testing hard-drive or SSD performance on Fedora"
date: 2019-03-22T00:00:00+02:00
opensource: 
- Fedora
---

If your Linux system appears to be slow, it might be an issue with your disks,
either hard drive or SSD. Hopefully, with a few commands you can get an idea
of the performances of your disks.

First, you will have to install `hdparm` using `yum` or `dnf`:

```sh
sudo yum install hdparm
```

Then, you will need to know which disk to test (your system might have multiple
disks). In this example, let's pretend we find our `/` partition to be slow.

The `df` command will show you on which disk is hosted the `/` filesystem:

```raw
# df -h /
Filesystem                Size  Used Avail Use% Mounted on
/dev/mapper/storage-root   10G  2.6G  7.5G  26% /
```

In this example, the `/` partition is on a logical volume (`root`) that is in
the `storage` volume group. If you suspect another partition, replace `/` with
the mountpoint of the other partition (`/var` for instance).

Let's find on which disk(s) is the volume group `storage` with the `pvdisplay`
command:

```raw
$ sudo pvdisplay
  --- Physical volume ---
  PV Name               /dev/sda2
  VG Name               storage
  PV Size               <557.88 GiB / not usable 4.00 MiB
  Allocatable           yes
  PE Size               4.00 MiB
  Total PE              142816
  Free PE               89056
  Allocated PE          53760
  PV UUID               9FT0O7-zs52-U11S-ROL1-ixVW-tgL9-9fVKXC
```

In the previous output, there is one physical volume (`/dev/sda2`) in the
`storage` volume group. So we need to measure the performances of `/dev/sda`.

The `hdparm -tT` command performs timing reads of the disk, with and without
the buffer cache of the Linux kernel.

```raw
$ sudo hdparm -tT /dev/sda

/dev/sda:
 Timing cached reads:   25732 MB in  1.99 seconds = 12926.07 MB/sec
 Timing buffered disk reads: 556 MB in  3.00 seconds = 185.23 MB/sec
```

According the man page, the `-t` parameter is used to:

> display the speed of reading directly
> from the Linux buffer cache without disk access.  This measurement is
> essentially an indication of the throughput of the processor, cache, and
> memory of the system under test.

According the man page, the `-T` parameter is used to:

> display the speed of reading
> through the buffer cache to the disk without any prior caching of data.
> This measurement is an indication of how fast the drive can sustain
> sequential data reads under Linux, without any filesystem overhead.

You can test the write speed with the `dd` command. This command will create a
file and write to it. The `conv=fdatasync` is used to actually write the content
to disk by flushing the buffers.

```sh
sudo dd if=/dev/zero of=/output conv=fdatasync bs=256k count=1k; rm -f /output
```

Make sure you write the file in the filesystem you want to test. For instance,
if you want to test the write speed on `/var`, replace `/output` with
`/var/output`.

```raw
$ sudo dd if=/dev/zero of=/output conv=fdatasync bs=256k count=128; rm -f /output
128+0 records in
128+0 records out
33554432 bytes (34 MB) copied, 0.0259041 s, 1.3 GB/s

$ sudo dd if=/dev/zero of=/output conv=fdatasync bs=256k count=512; rm -f /output
512+0 records in
512+0 records out
134217728 bytes (134 MB) copied, 0.110927 s, 1.2 GB/s

$ sudo dd if=/dev/zero of=/output conv=fdatasync bs=256k count=1k; rm -f /output
1024+0 records in
1024+0 records out
268435456 bytes (268 MB) copied, 0.32287 s, 831 MB/s

$ sudo dd if=/dev/zero of=/output conv=fdatasync bs=256k count=8k; rm -f /output
8192+0 records in
8192+0 records out
2147483648 bytes (2.1 GB) copied, 11.2527 s, 191 MB/s
```

Note: your write speed might be faster than your read speed. How can it be so?
Well, if your server has an high-end hardware disk controller, it might have
dedicated hardware buffers in addition to a small battery to retain data in case
of a power loss. In this case, if the file is small enough to fit the hardware
buffer of the disk controller, you are actually mesuring the bandwidth of your disk
controller.

To measure the write speed of your disk, you have to write a file **much larger**
than the hardware buffers of your disk controller.

In the previous examples, the hardware buffers of my server seems to be around
128 MB (the performances start to drop after that).

So the actual write speed of my disk is around 190 MB/s.