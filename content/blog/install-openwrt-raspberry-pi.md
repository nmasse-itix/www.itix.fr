---
title: "Install OpenWRT on your Raspberry PI"
date: 2019-12-19T00:00:00+02:00
opensource: 
- OpenWRT
---

[OpenWRT](https://openwrt.org/) is a Linux distribution for embedded systems.
It made design choices that take it apart from the usual Linux distributions: musl libc instead of the usual glibc, busybox instead of coreutils, ash instead of bash, etc.
As a result, the system is very light and blazing fast!

Continue reading to know how to **install OpenWRT on your Raspberry PI**.

## Install OpenWRT

OpenWRT has an [official documentation about the Raspberry PI support](https://openwrt.org/toh/raspberry_pi_foundation/raspberry_pi#installation) that tell which image to use for each version of the Raspberry PI.

For my Raspberry PI 3B, I downloaded the *brcm2708-bcm2710-rpi-3-ext4-factory* image.

```sh
curl -Lo /tmp/openwrt.img.gz http://downloads.openwrt.org/releases/18.06.5/targets/brcm2708/bcm2710/openwrt-18.06.5-brcm2708-bcm2710-rpi-3-ext4-factory.img.gz
gunzip /tmp/openwrt.img.gz
```

Then, to install OpenWRT on your Raspberry PI you would need to insert your SD card and write the OpenWRT firmware image onto it.

__On MacOS__:

```sh
sudo dd if=/tmp/openwrt.img of=/dev/diskX  bs=2m
sync
```

__On Linux__:

```sh
sudo dd if=/tmp/openwrt.img of=/dev/sdX bs=2M conv=fsync
```

Of course, you would have to replace **/dev/sdX** or **/dev/diskX** with the correct device path for your SD card. 

If *dd* seems too obscure for you, [Etcher](https://www.balena.io/etcher/) might be a better choice.

## First boot on OpenWRT

On first boot with OpenWRT installed, you would do two things:

- Configure the network
- Set a (strong) password for the root account

The easiest way to boot your Raspberry PI and do the initial configuration is to either connect a monitor and a keyboard or connect to the serial console. In this article, I chose the later option.

I am using the [UART Adapter](https://uart-adapter.com/). Once plugged in a free USB port, and the MacOS drivers installed (not needed on Linux), you can monitor the serial console of your Raspberry PI.

__On MacOS__:

```sh
screen /dev/tty.usbserial-MCBR88 115200
```

__On Linux__:

```sh
screen /dev/ttyUSB0 115200
```

You then need to connect the VIN, GND, TXD and RXD wires to the correct GPIO pins of your Raspberry PI.

![GPIO UART pins](uart-pins.jpeg)

Power-on your Raspberry PI, wait a couple seconds and press enter to display the OpenWRT prompt.

```raw
BusyBox v1.28.4 () built-in shell (ash)

  _______                     ________        __
 |       |.-----.-----.-----.|  |  |  |.----.|  |_
 |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
 |_______||   __|_____|__|__||________||__|  |____|
          |__| W I R E L E S S   F R E E D O M
 -----------------------------------------------------
 OpenWrt 18.06.5, r7897-9d401013fc
 -----------------------------------------------------

root@OpenWrt:~#
```

## Network configuration

Configure OpenWRT to connect to your network.
In the following example, I connected my Raspberry PI to the LAN interface.
If you want to use the Wifi instead, follow the [official documentation](https://openwrt.org/docs/guide-user/network/openwrt_as_clientdevice).

```sh
uci set network.lan.ipaddr=192.168.2.2
uci set network.lan.gateway=192.168.2.1
uci set network.lan.dns=192.168.2.1
uci commit
service network restart
```

## Change the root password

Set a secure password to the root account.

```sh
passwd root
```

## Create partitions to store your data

When you wrote the OpenWRT image to your SD card the OpenWRT firmware took only the first 256MB, thus leaving the rest of your SD card to store your data.

Install fdisk and use it to create partitions.

```sh
opkg update
opkg install fdisk
fdisk /dev/mmcblk0
```

To create two partitions (one for **/home** and one for **/srv**), use the following fdisk commands.

- **p** to print the current partition table.
- **n** then **e** to create an extended partition.
- **n** then **l** to create the first partition. When asked for the last sector, type **+2G** to make it 2GB large.
- **n** then **l** to create the second partition. When asked for the last sector, leave empty to fill the remaining space.
- **w** to write the partition table.

And reboot your Raspberry PI!

__Verbatim transcript:__

```raw
Command (m for help): p
Disk /dev/mmcblk0: 29.8 GiB, 32010928128 bytes, 62521344 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x5452574f

Device         Boot Start    End Sectors  Size Id Type
/dev/mmcblk0p1 *     8192  49151   40960   20M  c W95 FAT32 (LBA)
/dev/mmcblk0p2      57344 581631  524288  256M 83 Linux

Command (m for help): n
Partition type
   p   primary (2 primary, 0 extended, 2 free)
   e   extended (container for logical partitions)
Select (default p): e
Partition number (3,4, default 3): 
First sector (2048-62521343, default 2048): 581632
Last sector, +sectors or +size{K,M,G,T,P} (581632-62521343, default 62521343): 

Created a new partition 3 of type 'Extended' and of size 29.5 GiB.

Command (m for help): n
Partition type
   p   primary (2 primary, 1 extended, 1 free)
   l   logical (numbered from 5)
Select (default p): l

Adding logical partition 5
First sector (583680-62521343, default 583680): 
Last sector, +sectors or +size{K,M,G,T,P} (583680-62521343, default 62521343): +2G

Created a new partition 5 of type 'Linux' and of size 2 GiB.

Command (m for help): n
Partition type
   p   primary (2 primary, 1 extended, 1 free)
   l   logical (numbered from 5)
Select (default p): l

Adding logical partition 6
First sector (4780032-62521343, default 4780032): 
Last sector, +sectors or +size{K,M,G,T,P} (4780032-62521343, default 62521343): 

Created a new partition 6 of type 'Linux' and of size 27.5 GiB.

Command (m for help): p
Disk /dev/mmcblk0: 29.8 GiB, 32010928128 bytes, 62521344 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x5452574f

Device         Boot   Start      End  Sectors  Size Id Type
/dev/mmcblk0p1 *       8192    49151    40960   20M  c W95 FAT32 (LBA)
/dev/mmcblk0p2        57344   581631   524288  256M 83 Linux
/dev/mmcblk0p3       581632 62521343 61939712 29.5G  5 Extended
/dev/mmcblk0p5       583680  4777983  4194304    2G 83 Linux
/dev/mmcblk0p6      4780032 62521343 57741312 27.5G 83 Linux

Command (m for help): w
The partition table has been altered.
Failed to add partition 5 to system: Resource busy
Failed to add partition 6 to system: Resource busy

The kernel still uses the old partitions. The new table will be used at the next reboot. 
Syncing disks.
```

Create a filesystem on both partitions.

```sh
mkfs.ext4 /dev/mmcblk0p5
mkfs.ext4 /dev/mmcblk0p6
```

Mount the first partition on **/home** and the second one on **/srv**. Given both partitions are on a flash SD card, do not forget the *noatime* option!

```sh
opkg update
opkg install block-mount
block detect | uci import fstab
uci set fstab.@mount[2].target=/home
uci set fstab.@mount[2].enabled=1
uci set fstab.@mount[2].options=noatime
uci set fstab.@mount[3].target=/srv
uci set fstab.@mount[3].enabled=1
uci set fstab.@mount[3].options=noatime
uci commit
```

Create the **/srv** mount point (**/home** already exists).

```sh
mkdir -p /srv
```

Mount both partitions using the *block mount* command.

```sh
block mount
```

Confirm both partitions have been correctly mounted.

```raw
root@OpenWrt:~# mount
[...]
/dev/mmcblk0p5 on /home type ext4 (rw,noatime,data=ordered)
/dev/mmcblk0p6 on /srv type ext4 (rw,noatime,data=ordered)
```

## Configure Sudo

Create a regular user.

```sh
opkg update
opkg install shadow-useradd
useradd -s /bin/ash -N -m nicolas
passwd nicolas
```

From your workstation, confirm you can connect to your Raspberry PI using your username and password.

Install sudo and configure it so that the *users* group can run *root* commands.

```sh
opkg update
opkg install sudo
echo '%users ALL=(ALL) ALL' |EDITOR=/usr/bin/tee visudo
```

Alternatively, if you don't want the password prompt:

```sh
echo '%users ALL=(ALL) NOPASSWD: ALL' |EDITOR=/usr/bin/tee visudo
```

From your workstation, confirm you can connect to your Raspberry PI using your username and password, and get a root shell using:

```sh
sudo -i
```

## Disable SSH password login

You can secure even more your OpenWRT installation by using SSH keys and disabling SSH connections with passwords.

If you do not have one, you can generate an SSH key on your workstation using:

```sh
ssh-keygen -N ""
```

And copy it to **/etc/dropbear/authorized_keys**.

```sh
ssh-keygen -y | ssh root@192.168.2.2 tee /etc/dropbear/authorized_keys
```

Copy it also to your user account.

```sh
ssh-copy-id nicolas@192.168.2.2
```

Now, a very important step is to check that you can connect to your Raspberry PI using your SSH key.

```sh
ssh -o PasswordAuthentication=no -o ChallengeResponseAuthentication=no root@192.168.2.2
```

If you successfully connected to your Raspberry PI **without typing your password**, you can disable SSH password connections.

```sh
uci set dropbear.@dropbear[0].PasswordAuth="off"
uci set dropbear.@dropbear[0].RootPasswordAuth="off"
uci set dropbear.@dropbear[0].RootLogin="on"
uci commit dropbear
service dropbear restart
```

## Set the system hostname

If your Raspberry PI has a DNS hostname, you can set it now.

```sh
uci set system.@system[0].hostname='raspberry-pi.somewhere.test'
uci commit
```

## Cleanup

OpenWRT was originally a Linux distribution for routers, so it comes bundled with network software that might be useless for you. You can remove those unneeded software if you wish.

```sh
opkg remove --force-remove --force-removal-of-dependent-packages ppp ppp-mod-pppoe odhcpd-ipv6only dnsmasq hostapd-common luci luci-ssl-openssl luci-base lua luci-app-firewall luci-lib-ip luci-lib-jsonc luci-lib-nixio luci-proto-ipv6 luci-proto-ppp luci-theme-bootstrap uhttpd uhttpd-mod-ubus
```

## Conclusion

OpenWRT is now installed on your Raspberry PI.
You can start installing software on it, such as the [nginx reverse proxy](../nginx-with-tls-on-openwrt/) or miniflux, an RSS reader.
