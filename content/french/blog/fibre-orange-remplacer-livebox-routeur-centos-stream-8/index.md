---
title: "Fibre Orange : Remplacer sa Livebox par un routeur CentOS Stream 8"
date: '2023-12-14T00:00:00+02:00'
#description: ""
opensource:
- CentOS Stream
topics:
- Network
resources:
#- src: '*.yaml'
- src: '*.png'
- src: '*.jpeg'
---

Je suis abonné à l'offre Fibre d'Orange depuis 2016.
Et si je suis globalement satisfait de la qualité du réseau, je ne peux pas en dire autant de la Livebox fournie par Orange.
Les limitations sont nombreuses pour un geek souhaitant faire de l'hébergement de services à la maison : une seule plage IPv6 en /64, pas de configuration possible des tables de routage pour avoir plusieurs sous-réseaux IPv4, etc.
J'ai donc décidé de remplacer la Livebox par un routeur basé sur CentOS Stream 8.
Et l'aventure ne fut pas un long fleuve tranquille !
Cet article présente la configuration que j'ai mise en place et qui me donne aujourd'hui satisfaction.

<!--more-->

## Besoin

En tant que geek, j'ai des besoins bien particuliers quant au routeur qui gère mon accès internet :

- Segmenter mon réseau en 5 sous-réseaux : Administration, DMZ, LAN, IoT et Invité.
- Offrir une plage d'adresse IPv4 et IPv6 à chaque sous-réseau.
- Héberger un Homelab à la maison (avec flux sortants et **entrants**)
- Faire tourner des VMs pour héberger mes services

J'ai volontairement laissé de coté :

- Le support des chaînes TV d'Orange
- Le support de la téléphonie Orange

## Matériel

Pour le serveur en lui-même, j'ai choisi un HP DL20 Gen9 pour les raisons suivantes :

- J'avais déjà du matériel HP dans le Lab
- Taille plutôt compacte (format lame 1U, court)
- Silencieux (une fois démarré, on n'entend quasiment pas les ventilateurs)
- Extensible

Je l'ai déniché pour 660 € sur eBay avec les caractéristiques suivantes :

- 2 disques 3,5 pouces de 4 To chacun, sur carte RAID matérielle
- CPU [Intel Xeon E3-1270 v6](https://www.cpubenchmark.net/cpu.php?cpu=Intel+Xeon+E3-1270+v6+%40+3.80GHz&id=3014)
- 48 Go de DDR4 ECC
- Carte réseau supplémentaire Intel I350 au format "FlexibleLOM", avec 4 ports RJ-45

{{< attachedFigure src="hp-dl20-gen9.png" title="Serveur HP DL20 Gen9, vue de face, vue de dos." >}}

Pour me raccorder au réseau fibre optique d'Orange, j'ai conservé l'ONT (*Optical Network Termination*) qui m'a été fourni avec la Livebox.
D'un coté, je branche la jarretière optique, et de l'autre je branche le câble RJ-45 qui va jusqu'au serveur HP.

{{< attachedFigure src="Boitier-Fibre-Orange.jpeg" title="Boitier Fibre Orange. Source: [Wikipedia](https://commons.wikimedia.org/wiki/File:Boitier-Fibre-Orange_-_IMG_6456.jpg)" >}}

## Logiciel

Au moment où j'ai commencé à installer le serveur, la dernière version publiée de [CentOS Stream](https://www.centos.org/centos-stream/) était la 8.
Mais partez plutôt sur la dernière version disponible !

L'installation de CentOS Stream s'effectue, comme la majorité des distributions Linux :

- Télécharger l'[ISO de CentOS Stream](https://www.centos.org/download/)
- [Copier l'ISO sur une clé USB](https://wiki.centos.org/HowTos(2f)InstallFromUSBkey.html)
- Démarrer le serveur et booter sur la clé USB

## Spécificités de l'offre Fibre Orange

L'offre Fibre d'Orange a quelques spécificités, désormais [bien connues des geeks de lafibre.info](https://lafibre.info/remplacer-livebox/) :

- [Patcher le client DHCP](https://lafibre.info/remplacer-livebox/en-cours-remplacer-sa-livebox-par-un-routeur-ubiquiti-edgemax/msg320099/#msg320099) pour envoyer les paquets avec la priorité 802.1p numéro 6.
- Configurer l'interface réseau pour utiliser le VLAN 832.
- [Configurer le client DHCP](https://lafibre.info/remplacer-livebox/cacking-nouveau-systeme-de-generation-de-loption-90-dhcp/) pour envoyer le login et le mot de passe Orange.
- [Assurer la cohérence IPv4/IPv6](https://lafibre.info/remplacer-livebox/durcissement-du-controle-de-loption-9011-et-de-la-conformite-protocolaire/)

Cet article couvre l'ensemble de ces points.

Il est à noter qu'à partir du noyau 5.7, le filtre *"egress"* de *netfilter* devrait permettre la capture des paquets DHCPv4 et l'étiquetage de leur priorité.
Le client DHCP patché ne serait alors plus nécessaire.

> Commit e687ad60af09 ("netfilter: add netfilter ingress hook after handle_ing() under unique static key") introduced the ability to classify packets on ingress.
>
> Allow the same on egress.
>
> This hook is also useful for NAT46/NAT64, tunneling and filtering of locally generated af_packet traffic such as dhclient.

Source: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=8537f78647c072bdb1a5dbe32e1c7e5b13ff1258

## Installation du client DHCP patché

J'ai backporté le [patch de Zoc](https://lafibre.info/remplacer-livebox/en-cours-remplacer-sa-livebox-par-un-routeur-ubiquiti-edgemax/msg320099/#msg320099) dans les RPMs dhclient de CentOS Stream 8.
Les sources sont dans le dépot Git [nmasse-itix/dhclient-orange](https://github.com/nmasse-itix/dhclient-orange) et les RPMs sont disponibles publiquement sur un [partage Backblaze B2](https://f003.backblazeb2.com/file/dhclient-orange/dhclient-orange.repo).

Installer le client DHCP patché.

```sh
sudo curl -o /etc/yum.repos.d/dhclient-orange.repo https://f003.backblazeb2.com/file/dhclient-orange/dhclient-orange.repo
sudo dnf remove dhcp-client
sudo dnf install dhcp-client-orange-isp
```

Configurer NetworkManager pour qu'il utilise dhclient plutôt que son client DHCP interne.

{{< highlightFile "/etc/NetworkManager/conf.d/dhclient.conf" "ini" "hl_lines=2" >}}
[main]
dhcp=dhclient
{{< / highlightFile >}}

Redémarrer NetworkManager.

```sh
sudo systemctl restart NetworkManager
```

## Configuration du client DHCP pour l'authentification Orange

Pour configurer le client DHCP pour l'authentification Orange, il vous faudra trois choses :

- L'adresse MAC de la Livebox que vous souhaitez remplacer (vous pouvez la trouver sur une étiquette sous la Livebox). Notez que dans le fichier de configuration ci-dessous, il faudra préfixer l'adresse MAC par "**01:**".
- La chaîne de caractère à envoyer dans l'option 90. Utilisez pour cela [le calculateur mis à disposition par la communauté lafibre.info](https://jsfiddle.net/kgersen/3mnsc6wy).
- Le nom de l'interface réseau sur laquelle vous avez connecté l'ONT Orange (**eno2** dans l'exemple ci-dessous), suffixé par **.832**.

Saisir le contenu du fichier /etc/dhcp/dhclient.conf.

{{< highlightFile "/etc/dhcp/dhclient.conf" "c" "hl_lines=4 7-8" >}}
option rfc3118-authentication code 90 = string;
option dhcp-client-identifier code 61 = string;

interface "eno2.832" {
    send vendor-class-identifier "sagem";
    send user-class "+FSVDSL_livebox.Internet.softathome.Livebox4";
    send dhcp-client-identifier 01:AA:BB:CC:DD:EE:FF;
    send rfc3118-authentication 00:00:00:00:00:00:00:00:00:00:00:1a:09:00:00:05:58:01:03:41:01:0B:66:74:69:2F:64:75:6D:6D:79:3c:12:31:32:33:34:35:36:37:38:39:30:31:32:33:34:35:36:03:13:41:b9:80:f2:ea:3f:06:3b:2b:e7:08:ac:ec:9c:38:9e:ba;
    request subnet-mask,routers,domain-name,broadcast-address,dhcp-lease-time,dhcp-renewal-time,dhcp-rebinding-time,rfc3118-authentication;
}
{{< / highlightFile >}}

## Configuration de l'interface réseau pour utiliser le VLAN 832

Configurer l'interface réseau (ici **eno2**) à l'aide de NetworkManager pour utiliser le VLAN 832.

```sh
sudo nmcli con add type ethernet con-name eno2.832 autoconnect yes ipv4.method disabled ipv6.method ignore connection.interface-name eno2
sudo nmcli con add type vlan dev eno2 con-name eno2.832 id 832 egress "0:0,1:0,2:0,3:0,4:0,5:0,6:6,7:0" autoconnect yes ipv4.method auto ipv6.method ignore
```

À ce stade, vous devez obtenir une adresse IPv4 publique lorsque vous activez l'interface.

```sh
sudo nmcli con up eno2.832
```

La suite de l'article est très dépendante de choix que j'ai pu faire par ailleurs dans mon réseau domestique.
Aussi, considérez la comme une indication plus qu'un tutoriel pas à pas.

## Configuration nécessaire à IPv6

Activer le routage des paquets IPv4 et IPv6.
Ne pas oublier d'adapter le nom de l'interface réseau !

{{< highlightFile "/etc/sysctl.d/99-fibre-orange.conf" "ini" "hl_lines=3" >}}
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net/ipv6/conf/eno2.832/accept_ra=2
net.ipv4.conf.all.src_valid_mark=1
{{< / highlightFile >}}

Recharger les paramètres noyaux avec la commande **sysctl**.

```sh
sudo sysctl --system
```

Configurer ensuite le client DHCPv6 pour l'authentification Orange.
Même mode opératoire que pour IPv4, il vous faudra trois choses :

- L'adresse MAC de la Livebox que vous souhaitez remplacer (vous pouvez la trouver sur une étiquette sous la Livebox). Notez que dans le fichier de configuration ci-dessous, il faudra préfixer l'adresse MAC par "**00:03:00:01:**".
- La chaîne de caractère à envoyer dans l'option 11. Utilisez pour cela [le calculateur mis à disposition par la communauté](https://jsfiddle.net/kgersen/3mnsc6wy).
- Le nom de l'interface réseau sur laquelle vous avez connecté l'ONT Orange (**eno2** dans l'exemple ci-dessous), suffixé par **.832**.

Saisir le contenu du fichier /etc/dhcp/dhclient6.conf.

{{< highlightFile "/etc/dhcp/dhclient.conf" "c" "hl_lines=5 9-10" >}}
option dhcp6.auth code 11 = string;
option dhcp6.vendorclass code 16 = string;
option dhcp6.userclass code 15 = string;

interface "eno2.832" {
    send dhcp6.vendorclass 00:00:04:0e:00:05:73:61:67:65:6d;
    send dhcp6.userclass 00:2b:46:53:56:44:53:4c:5f:6c:69:76:65:62:6f:78:2e:49:6e:74:65:72:6e:65:74:2e:73:6f:66:74:61:74:68:6f:6d:65:2e:6c:69:76:65:62:6f:78:34;
    send dhcp6.vendor-opts 00:00:05:58:00:06:00:0e:49:50:56:36:5f:52:45:51:55:45:53:54:45:44;
    send dhcp6.client-id 00:03:00:01:AA:BB:CC:DD:EE:FF;
    send dhcp6.auth 00:00:00:00:00:00:00:00:00:00:00:1a:09:00:00:05:58:01:03:41:01:0B:66:74:69:2F:64:75:6D:6D:79:3c:12:31:32:33:34:35:36:37:38:39:30:31:32:33:34:35:36:03:13:41:b9:80:f2:ea:3f:06:3b:2b:e7:08:ac:ec:9c:38:9e:ba;
    also request dhcp6.name-servers, dhcp6.vendorclass, dhcp6.userclass, dhcp6.auth;
}
{{< / highlightFile >}}

Créer le script de *dispatch* pour NetworkManager.
Ce script sera appelé automatiquement par NetworkManager après un *up* ou un *down* de l'interface réseau et lancera le client DHCPv6 en mode *Prefix Delegation*.
Ne pas oublier d'adapter le nom de l'interface réseau !

{{< highlightFile "/etc/NetworkManager/dispatcher.d/99-orange-ipv6" "sh" "hl_lines=5" >}}
#!/bin/bash

set -Eeuo pipefail

if [ "${DEVICE_IFACE:-}" != "eno2.832" ]; then
    exit 0
fi

# Set log file for this shell and all commands executed
exec &>>/var/log/orange-ipv6.log
trap 'ret=$? ; if [ $ret -gt 0 ]; then echo "NM dispatcher script called with action = ${NM_DISPATCHER_ACTION:-} finished at $(date -Isecond) with code $ret"; fi' EXIT ERR

case "$NM_DISPATCHER_ACTION" in
up)
    signal=TERM
    while [ -f "/var/run/NetworkManager/dhclient6-$DEVICE_IFACE.pid" ] && pgrep -F "/var/run/NetworkManager/dhclient6-$DEVICE_IFACE.pid" &>/dev/null; do
        if pkill -F /var/run/NetworkManager/dhclient6-$DEVICE_IFACE.pid --signal "$signal"; then
            signal=KILL
            sleep 5
        fi
    done
    dhclient -P -6 -cf /etc/dhcp/dhclient6.conf -lf "/var/lib/NetworkManager/dhclient-$CONNECTION_UUID-$DEVICE_IFACE.lease" -pf "/var/run/NetworkManager/dhclient6-$DEVICE_IFACE.pid" "$DEVICE_IFACE"
    ;;
down)
    if [ -f "/var/run/NetworkManager/dhclient6-$DEVICE_IFACE.pid" ]; then
        pkill -F /var/run/NetworkManager/dhclient6-$DEVICE_IFACE.pid || true
    fi
    ;;
*)
    ;;
esac

exit 0
{{< / highlightFile >}}

Créer le répertoire **/etc/dhcp/dhclient-exit-hooks.d**.

```sh
sudo mkdir -p /etc/dhcp/dhclient-exit-hooks.d
```

Créer le script de *hook* pour dhclient.
Il sera appelé par le client DHCPv6 après obtention d'un préfixe IPv6 et a pour tâche d'affecter les adresses IPv6 aux différentes interfaces du serveur.
Ne pas oublier d'adapter le nom de l'interface réseau et le nom de vos interfaces réseaux internes (chez moi, elles s'appelle ivs1, ivs2, etc.) !

{{< highlightFile "/etc/dhcp/dhclient-exit-hooks.d/99-orange-ipv6" "sh" "hl_lines=5 12" >}}
#!/bin/bash

set -Eeuo pipefail

if [ "${interface:-}" != "eno2.832" ]; then
    exit 0
fi

# Issue a log in case of error
trap 'ret=$? ; if [ "$ret" -gt 0 ]; then echo "dhclient hook script called with reason = ${reason:-} finished at $(date -Isecond) with code $ret"; fi' EXIT ERR

ifprefix="ivs"
internal_ifaces="$(ifconfig -a -s | egrep -o "^($ifprefix)[0-9]+" | sort -V)"
external_iface="$interface"

temp="$(mktemp -d -t orange.XXXXXX)"
trap 'rm -rf "$temp"' EXIT

function log () {
    if [ -n "${DEBUG:-}" ]; then
        echo "$@"
    fi
    "$@"
}

function cleanup_interface () {
    local interface="$1"
    current_ipv6_addr="$(ip -6 -br addr show dev "$interface" scope global | awk 'NR == 1 { print $3 }')"
    if [ -n "$current_ipv6_addr" ]; then
        log ip addr delete "$current_ipv6_addr" dev "$interface" || true
    fi
}

case "${reason:-}" in
BOUND6|REBIND6)
    # This should be set on startup. To be safe, recheck here.
    sysctl -q net/ipv6/conf/eno2.832/accept_ra=2

    if [ -n "${new_ip6_prefix:-}" ] ; then
        ipcalc -S 64 "$new_ip6_prefix" --no-decorate > "$temp/networks"
        for interface in $internal_ifaces $external_iface; do
            if [ "$interface" == "$external_iface" ]; then
                # eno2.832 gets subnet 0
                ipv6_network="$(head -n 1 $temp/networks)"
            else
                if [[ "$interface" =~ ^ivs ]]; then
                    # ivsX gets subnet X (X is guaranted to start at 1)
                    n="${interface#ivs}"
                else
                    echo "Unsupported interface: $interface"
                    continue
                fi
                ipv6_network="$(awk -v "net_id=$n" 'NR == net_id + 1 { print }' $temp/networks)"
            fi

            # Determine current and previous IPv6 addresses
            new_ipv6_addr="$(echo "$ipv6_network" | sed -r 's|::/([0-9]+)|::1/\1|')"
            old_ipv6_addr="$(ip -6 -br addr show dev "$interface" scope global | awk 'NR == 1 { print $3 }')"

            # Only replace the previous IPv6 address if the new one is different
            if [ "${new_ipv6_addr}" != "$old_ipv6_addr" ]; then
                cleanup_interface "$interface"
                log ip addr add "$new_ipv6_addr" dev "$interface"
            fi
        done
    fi
    ;;
RELEASE)
    for interface in $internal_ifaces; do
        cleanup_interface "$interface"
    done
    ;;
*)
    ;;
esac

exit 0
{{< / highlightFile >}}

N'oubliez pas de rendre ces deux scripts exécutables.

```sh
sudo chmod 755 /etc/NetworkManager/dispatcher.d/99-orange-ipv6
sudo chmod 755 /etc/dhcp/dhclient-exit-hooks.d/99-orange-ipv6
```

Pour que l'IPv6 fonctionne, il faut correctement étiqueter les paquets DHCPv6 en priorité 6.
Pour cela, j'utilise **nftables**.
Le script est très dépendant de mes choix de réseau, je vous invite donc à le prendre comme un exemple pour créer le votre ensuite.

Désactiver **firewalld**.

```sh
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo systemctl mask firewalld
```

Éditer le contenu du fichier **/etc/sysconfig/nftables.conf**.

{{< highlightFile "/etc/sysconfig/nftables.conf" "ini" "hl_lines=" >}}
# Uncomment the include statement here to load the default config sample
# in /etc/nftables for nftables service.

include "/etc/nftables/itix.nft"

# To customize, either edit the samples in /etc/nftables, append further
# commands to the end of this file or overwrite it after first service
# start by calling: 'nft list ruleset >/etc/sysconfig/nftables.conf'.
{{< / highlightFile >}}

Créer le fichier **/etc/nftables/update.nft**.

{{< highlightFile "/etc/nftables/update.nft" "ini" "hl_lines=" >}}
#!/usr/sbin/nft -f

flush table inet itix-fw
delete table inet itix-fw
flush table ip itix-nat
delete table ip itix-nat

include "/etc/nftables/itix.nft"
{{< / highlightFile >}}

Créer le fichier **/etc/nftables/itix.nft**.

{{< highlightFile "/etc/nftables/itix.nft" "c" "hl_lines=42 45 57 72 74 76 86" >}}
#!/usr/sbin/nft -f

table inet itix-fw {
    chain Public-Services {
        # Allow Ping
        icmp type echo-request counter accept

        # Allow SSH
        tcp dport { 22 } counter accept
    }

    chain Forward-IPv6-from-Internet {
        # Allow IPv6 ICMP
        ip6 nexthdr ipv6-icmp counter accept

        # Enable TCP/UDP ports > 1024
        tcp dport > 1024 counter accept
        udp dport > 1024 counter accept
    }

    chain Orange-IPv6-Priority {
        # DSCP is "Differenciated Service Code Point". See RFC 4594.
        # CS6 is "Class Selector 6 (Internetwork Control)".
        icmpv6 type { nd-neighbor-solicit, nd-router-solicit } ip6 dscp set cs6 meta priority set 0:6 counter
        udp sport { dhcpv6-client, dhcpv6-server } ip6 dscp set cs6 meta priority set 0:6 counter
    }

    chain Input {
        type filter hook input priority filter + 20
        policy drop

        # Accept packets related to existing connections
        ct state invalid counter drop
        ct state { established, related } counter accept

        # Loopback
        iifname lo counter accept

        # Accept all ethernet frames on the public interface so that we can then handle the VLANs
        iifname eno2 accept
        # Filter packets arriving on VLAN 832
        iifname eno2.832 counter jump Public-Services
        
        # Internal Interfaces
        iifname { ivs1, ivs2, ivs3, ivs4, ivs5 } counter accept
    }

    chain Output {
        type filter hook output priority filter + 20
        policy accept

        # Accept packets related to existing connections
        ct state invalid counter drop
        ct state { established, related } counter accept

        # Tag all DHCPv6 packets with priority 6
        oifname eno2.832 counter jump Orange-IPv6-Priority
    }

    chain Forward {
        type filter hook forward priority filter + 20
        policy drop
        
        # Accept packets related to existing connections
        ct state invalid counter drop
        ct state { established, related } counter accept

        # Loopback
        iifname lo counter accept

        # From the internal network to the internet
        iifname { ivs1, ivs2, ivs3, ivs4, ivs5 } oifname eno2.832 counter accept
        # From the internal network to the internal network
        iifname { ivs1, ivs2, ivs3, ivs4, ivs5 } oifname { ivs1, ivs2, ivs3, ivs4, ivs5 } counter accept
        # From the internet to the internal network
        iifname eno2.832 oifname { ivs1, ivs2, ivs3, ivs4, ivs5 } counter jump Forward-IPv6-from-Internet
    }
}

table ip itix-nat {
    chain Post-Routing {
        type nat hook postrouting priority srcnat
        policy accept

        # Masquerade all connections to the Internet
        iifname { ivs1, ivs2, ivs3, ivs4, ivs5 } oifname eno2.832 counter masquerade
    }

}
{{< / highlightFile >}}

Activer et démarrer le service **nftables**.

```sh
sudo systemctl enable nftables
sudo systemctl start nftables
```

Vérifier avec la commande **sudo nft list tables** que les deux tables **itix-fw** et **itix-nat** ont bien été chargées.

A ce moment là, vous pouvez essayer de faire un **nmcli con down eno2.832** puis **nmcli con up eno2.832** et vérifier que vous avez bien une adresse IPv4 publique et une adresse IPv6 globale.

## Vérification périodique et cohérence IPv4/IPv6

Orange applique des règles de cohérence entre les protocoles IPv4 et IPv6.
Rien n'est documenté officiellement, mais sur le forum [lafibre.info](https://lafibre.info/remplacer-livebox/durcissement-du-controle-de-loption-9011-et-de-la-conformite-protocolaire/) quelques indications ont été données.

Pour mettre en oeuvre ces règles, j'ai développé un script qui vérifie que les piles IPv4 et IPv6 sont opérationnelles et force un nouveau cycle DHCPv4 + DHCPv6 si nécessaire.
Pour éviter tout problème, je force également un renouvellement des baux DHCP toutes les 12 heures.

{{< highlightFile "/usr/local/bin/fibre-orange" "sh" "hl_lines=5" >}}
#!/bin/bash

set -Eeuo pipefail

ORANGE_IFACE="eno2.832"

declare -a TARGET_IPV4=("8.8.8.8" "8.8.4.4" "1.1.1.1" "1.0.0.1" "208.67.222.222" "208.67.220.220")
declare -a TARGET_IPV6=("2001:4860:4860::8888" "2001:4860:4860::8844" "2606:4700:4700::1111" "2606:4700:4700::1001" "2620:119:53::53" "2620:119:35::35")

function help () {
    echo "Usage: $0 {help|health-check|renew}"
}

function error () {
    echo "$1" >&2
}

function msg () {
    echo "$1"
}

function die () {
    error "$1" "$@"
    exit 1
}

function ping () {
    /bin/ping "$1" -c 4 -I "$ORANGE_IFACE" -n -q -W 10 "$2" > /dev/null 2>&1
}

function orange_healthcheck () {
    declare ipv4_check=0
    for ipv4 in ${TARGET_IPV4[@]}; do
        if ping -4 "$ipv4"; then
            ipv4_check=1
        else
            msg "$ipv4 is not reachable!"
        fi
    done

    if [ "$ipv4_check" == "0" ]; then
        error "IPv4 stack is down!"
    fi

    declare ipv6_check=0
    for ipv6 in ${TARGET_IPV6[@]}; do
        if ping -6 "$ipv6"; then
            ipv6_check=1
        else
            msg "$ipv6 is not reachable!"
        fi
    done

    if [ "$ipv6_check" == "0" ]; then
        error "IPv6 stack is down!"
    fi

    if [[ "$ipv4_check" == "0" || "$ipv6_check" == "0" ]]; then
        return 1
    fi

    return 0
}

function kill_process () {
    declare signal=TERM
    while :; do
        if [ -f "/var/run/NetworkManager/$1-$ORANGE_IFACE.pid" ] && pkill -F /var/run/NetworkManager/$1-$ORANGE_IFACE.pid --signal "$signal"; then
            msg "Killed $1 with $signal!"
            signal=KILL
            sleep 5
        else
            break
        fi
    done

    return 0
}

function is_dhclient4_running () {
    if [ ! -f /var/run/NetworkManager/dhclient-$ORANGE_IFACE.pid ] || ! pgrep -F /var/run/NetworkManager/dhclient-$ORANGE_IFACE.pid &>/dev/null; then
        return 1
    fi
    return 0
}

function orange_renew () {
    # Stop all dhclient instances
    kill_process dhclient6
    kill_process dhclient

    # Sometimes the "nmcli device reapply" fails to restart the DHCP client.
    # Monitor the dhclient process to know when it succeeded.
    while ! is_dhclient4_running; do
        nmcli device reapply "$ORANGE_IFACE"
        sleep 30
    done

    return 0
}

case "${1:-}" in
health-check)
    if ! orange_healthcheck; then
        error "Renewing IPv4 and IPv6 DHCP leases..."
        nmcli connection down $ORANGE_IFACE
        sleep 2
        nmcli connection up $ORANGE_IFACE
    fi
    ;;
renew)
    orange_renew
    ;;
help)
    help
    ;;
*)
    error "Unkown action '${1:-}'!"
    help
    exit 1
    ;;
esac

exit 0
{{< / highlightFile >}}

Rendre le script exécutable.

```sh
sudo chmod 755 /usr/local/bin/fibre-orange
```

Créer la crontab associée pour lancer ce script périodiquement.

{{< highlightFile "/etc/cron.d/fibre-orange" "crontab" "hl_lines=" >}}
*/5 * * * * root /usr/local/bin/fibre-orange health-check
0 */12 * * * root /usr/local/bin/fibre-orange renew
{{< / highlightFile >}}

## Conclusion

Cela fait déjà plusieurs années que le serveur est installé et avec les dernières informations glanées sur le forum **lafibre.info**, la configuration est robuste.
Je n'ai pas tout expliqué dans l'article car la configuration que j'ai mise en place est complexe et n'apporterait pas grand chose pour le geek souhaitant remplacer sa Livebox par un routeur **CentOS Stream 8**.

Par exemple, pour les sous-réseaux internes j'ai mis de l'**Open vSwitch**.
Pour acheminer les requètes HTTP & HTTPS, j'ai mis en place **Traefik**.
Pour héberger mes services, j'ai déployé **Kubernetes**.
Ça, je le garde pour un prochain article !
