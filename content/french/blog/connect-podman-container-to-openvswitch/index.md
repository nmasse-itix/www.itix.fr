---
title: "Connecter un conteneur Podman à Open vSwitch"
date: 2025-06-25T00:00:00+02:00
#lastMod: 2025-06-25T00:00:00+02:00
opensource:
- Open vSwitch
- Podman
topics:
- Containers
- Networking
resources:
- '*.png'
- '*.svg'
---

J'utilise **Open vSwitch** pour connecter mes différentes machines virtuelles entre elles.
Mais si je veux aussi connecter un conteneur Podman à **Open vSwitch** pour qu'il puisse communiquer avec mes VM, je fais comment?
Suivez-moi, c'est pas si compliqué !

<!--more-->

Dans les options possibles de la commande **podman run**, il n'existe malheureusement aucune option `--network openvswitch,port=foo`.
Mais il y en a une qui peut nous servir : `--network ns:bar`.
Cette option nous permet de créer un conteneur et le raccorder à un *namespace* réseau existant.

## Connecter le conteneur à Open vSwitch

La première étape consiste à créer un *namespace* réseau ("podman-c1" pour notre premier conteneur Podman ?) :

```sh
ip netns add podman-c1
```

Ensuite, créer le port et l'interface **Open vSwitch**, si ce n'est pas déjà fait.
Dans l'exemple suivant, je crée l'interface **ivs123** sur le bridge Open vSwitch **ivs** :

```sh
ovs-vsctl add-port ivs ivs123 -- set interface ivs123 type=internal
```

Normalement, une interface **ivs123** devrait apparaitre sur votre machine :

```
$ ip addr show ivs123
5: ivs123: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether d6:dd:a0:24:09:2c brd ff:ff:ff:ff:ff:ff
```

Puis, on assigne cette interface au *namespace* créé initialement.
On monte également l'interface **lo**.

```sh
ip link set ivs123 netns podman-c1
ip -n podman-c1 link set lo up
```

Il faut encore affecter une adresse IP à notre conteneur :

```sh
ip -n podman-c1 addr add 192.168.3.99/24 dev ivs123
ip -n podman-c1 link set ivs123 up
```

Pour tester facilement notre setup, je propose de créer une image de conteneur avec tout le nécessaire.
Pour cela, créer un fichier **Containerfile** avec le contenu suivant:

{{< highlightFile "Containerfile" "docker" "" >}}
FROM quay.io/centos/centos:stream10
RUN dnf install -y iproute bind-utils net-tools iputils && dnf clean all
{{< / highlightFile >}}

Construire l'image de conteneur avec :

```sh
podman build -t localhost/test-openvswitch:latest .
```

Et le moment tant attendu : on peut maintenant démarrer notre conteneur !

```sh
podman run -it --rm --name test-openvswitch --network ns:/var/run/netns/podman-c1 localhost/test-openvswitch:latest
```

Normalement, vous devriez voir dans votre conteneur l'interface **Open vSwitch** :

```
[root@4cb3046e7300 /]# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
5: ivs123: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether d6:dd:a0:24:09:2c brd ff:ff:ff:ff:ff:ff
    inet 192.168.3.99/24 scope global ivs123
       valid_lft forever preferred_lft forever
```

## Tester l'interconnexion conteneur <--> VM

Si vous n'avez pas l'habitude de manipuler **Open vSwitch** et Libvirt, voici un résumé pour démarrer rapidement.

Installer les paquets nécessaires :

```sh
dnf install -y openvswitch @virtualization
systemctl enable --now openvswitch
systemctl enable --now libvirtd
```

Créer un bridge **Open vSwitch** (chez moi il s'appelle "ivs") :

```sh
ovs-vsctl add-br ivs
```

Créer le réseau libvirt qui référence le bridge **Open vSwitch**.
Pour cela, vous devrez créer le fichier de définition au format XML :

{{< highlightFile "ovs-net.xml" "xml" "" >}}
<network>
    <name>ivs</name>
    <forward mode="bridge" />
    <bridge name="ivs" />
    <virtualport type='openvswitch'>
    </virtualport>
    <portgroup name='default' default='true'>
    </portgroup>
</network>
{{< /highlightFile >}}

Puis créer le réseau libvirt depuis ce fichier de définition :

```sh
sudo virsh net-define ovs-net.xml
sudo virsh net-start ivs
sudo virsh net-autostart ivs
```

Télécharger l'image Qemu de **Fedora Server** depuis [la page de téléchargement](https://fedoraproject.org/server/download) et la placer dans `/var/lib/libvirt/images/fedora-server` :

Exemple avec la version 42 de Fedora Server :

```sh
mkdir -p /var/lib/libvirt/images/fedora-server/
curl -o /var/lib/libvirt/images/fedora-server/Fedora-Server-Guest-Generic-42-1.1.x86_64.qcow2 https://download.fedoraproject.org/pub/fedora/linux/releases/42/Server/x86_64/images/Fedora-Server-Guest-Generic-42-1.1.x86_64.qcow2
```

Créer la VM Fedora Server :

```sh
virt-install --name test-openvswitch --autostart --cpu host-passthrough --vcpu 2 --ram 4096 --os-variant fedora42 --disk /var/lib/libvirt/images/fedora-server/Fedora-Server-Guest-Generic-*.qcow2 --network network=ivs,portgroup=default,mac.address=RANDOM --console pty,target.type=virtio --serial pty --graphics none --import
```

Normalement, virt-install devrait vous connecter immédiatement à la console série.
Une fois le *boot* de la VM terminé, vous pourrez définir le mot de passe root et vous y connecter.

```
================================================================================
================================================================================


1) [ ] Language settings                 2) [x] Time settings
       (Language is not set.)                   (America/New_York timezone)
3) [x] Network configuration             4) [!] Root password
       (Connecting...)                          (Root account is disabled)
5) [!] User creation
       (No user will be created)


Please make a selection from the above ['c' to continue, 'q' to quit, 'r' to
refresh]: 4

================================================================================
================================================================================
Root password

Please select new root password. You will have to type it twice.


Password: secret
Password (confirm): secret

================================================================================
================================================================================
Question

The password you have provided is weak: The password fails the dictionary check
- it is based on a dictionary word
Would you like to use it anyway?


Please respond 'yes' or 'no': yes

================================================================================
================================================================================

1) [ ] Language settings                 2) [x] Time settings
       (Language is not set.)                   (America/New_York timezone)
3) [x] Network configuration             4) [x] Root password
       (Connecting...)                          (Root password is set)
5) [ ] User creation
       (No user will be created)


Please make a selection from the above ['c' to continue, 'q' to quit, 'r' to
refresh]: c

Fedora Linux 42 (Server Edition)
Kernel 6.14.0-63.fc42.x86_64 on x86_64 (ttyS0)

Web console: https://localhost:9090/

localhost login: root
Password: secret
```

Définir l'adresse IP de la VM de test :

```
nmcli device set enp1s0 managed no
ip link set enp1s0 up
ip addr add 192.168.3.100/24 dev enp1s0
```

Et le moment de vérité : "la VM va t'elle pouvoir pinguer le conteneur ?".

```
[root@localhost ~]# ip -br addr show
lo               UNKNOWN        127.0.0.1/8
enp1s0           UP             192.168.3.100/24

[root@localhost ~]# ping -c4 192.168.3.99
PING 192.168.3.99 (192.168.3.99) 56(84) bytes of data.
64 bytes from 192.168.3.99: icmp_seq=1 ttl=64 time=1.13 ms
64 bytes from 192.168.3.99: icmp_seq=2 ttl=64 time=0.412 ms
64 bytes from 192.168.3.99: icmp_seq=3 ttl=64 time=0.361 ms
64 bytes from 192.168.3.99: icmp_seq=4 ttl=64 time=0.350 ms

--- 192.168.3.99 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3090ms
rtt min/avg/max/mdev = 0.350/0.562/1.125/0.325 ms
```

Sans surprise, oui ! 😎

## Automatiser la configuration dans un Quadlet

Pour mon cas d'usage, j'ai eu besoin d'automatiser toute la configuration réseau du conteneur sous la forme d'un [Quadlet Podman](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html).
Pour éviter de coder dans le Quadlet tous les paramètres réseau, je me suis appuyé sur un client DHCP, une adresse MAC statique et un bail statique dans mon serveur DHCP.

Le quadlet résultat est celui-ci :

{{< highlightFile "/etc/containers/systemd/test-openvswitch.container" "ini" "" >}}
[Unit]
Description=Sample container to test the integration with Open vSwitch
Before=openvswitch.service
Wants=openvswitch.service

[Container]
ContainerName=test-openvswitch
Image=localhost/test-openvswitch:latest
Entrypoint=/bin/sleep
Exec=INF
AddCapability=CAP_NET_BIND_SERVICE
Network=ns:/var/run/netns/test-openvswitch

[Service]
Environment=IFNAME=ivs123 NS=test-openvswitch

##
## This creates a namespace, bind the specified interface to it and run a DHCP client to get an IPv4 address
##
ExecStartPre=/bin/sh -Eeuo pipefail -c 'if [ ! -f /var/run/netns/$NS ]; then ip netns add $NS; fi; if ! ip -n $NS -br addr show | grep -q "^$IFNAME"; then ip link set $IFNAME netns $NS; fi; ip -n $NS link set lo up'
ExecStartPost=/bin/sh -Eeuo pipefail -c 'nsenter --net=/var/run/netns/$NS dhcpcd --script /bin/true --duid=ll --lastlease --lastleaseextend --persistent --waitip=4 -4 $IFNAME'

##
## This stops the DHCP client, unbind the specified interface and remove the namespace
##
ExecStopPost=/bin/sh -c 'nsenter --net=/var/run/netns/$NS dhcpcd -x $IFNAME -4'
ExecStopPost=/bin/sh -Eeuo pipefail -c 'if ip -n $NS -br addr show | grep -q "^$IFNAME"; then ip -n "$NS" link set $IFNAME netns 1; fi; ip netns delete $NS'

[Install]
# Start by default on boot
WantedBy=multi-user.target default.target
{{< /highlightFile >}}

L'adresse mac statique du conteneur peut se définir au niveau de l'interface **Open vSwitch**.
Dans la commande suivante, les guillemets sont échappés car ils font partie de la valeur attendue par **Open vSwitch**.

```sh
ovs-vsctl set interface ivs123 mac=\"04:01:06:00:06:01\"
```

## Conclusion

En résumé, connecter un conteneur Podman à **Open vSwitch** permet d’intégrer les conteneurs dans une topologie réseau virtualisée existante, aux côtés des machines virtuelles.
Cette approche garantit une interconnexion transparente entre les différentes charges de travail, tout en bénéficiant de la flexibilité d’**Open vSwitch**.

L’automatisation via Quadlet industrialise cette intégration en assurant une configuration persistante, maintenable et adaptée aux environnements de production.
Une solution robuste pour celles et ceux qui cherchent à unifier leurs infrastructures conteneurisées et virtualisées.
