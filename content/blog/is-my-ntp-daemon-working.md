---
title: "Is my NTP daemon working?"
date: 2019-03-29T00:00:00+02:00
opensource: 
- Fedora
---

If the time on your workstation or server is not stable, strange errors might
appear, such as:

```raw
$ tar zxvf /tmp/archive.tgz
tar: my-file: time stamp 2019-03-28 14:04:45 is 0.042713488 s in the future
```

This can happen when your [NTP](https://en.wikipedia.org/wiki/Network_Time_Protocol)
daemon is not synchronized. This means it cannot reliably determine the current
time.

First, make sure your NTP daemon is started:

```raw
$ sudo systemctl status ntpd
● ntpd.service - Network Time Service
   Loaded: loaded (/usr/lib/systemd/system/ntpd.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2019-03-28 17:13:10 CET; 16h ago
  Process: 33844 ExecStart=/usr/sbin/ntpd -u ntp:ntp $OPTIONS (code=exited, status=0/SUCCESS)
 Main PID: 33845 (ntpd)
    Tasks: 1
   Memory: 924.0K
   CGroup: /system.slice/ntpd.service
           └─33845 /usr/sbin/ntpd -u ntp:ntp -g
```

For your NTP daemon to be started, the state must be `active (running)`.

Then, you can query its status with the `ntpdc` command:

```raw
$ sudo ntpdc -c sysinfo
system peer:          www.almaprovence.fr
system peer mode:     client
leap indicator:       00
stratum:              3
precision:            -25
root distance:        0.00130 s
root dispersion:      0.02950 s
reference ID:         [212.83.145.32]
reference time:       e0485cce.58fb4baf  Fri, Mar 29 2019  9:58:54.347
system flags:         auth ntp kernel stats 
jitter:               0.000259 s
stability:            0.000 ppm
broadcastdelay:       0.000000 s
authdelay:            0.000000 s
```

In this output, you need to check the **stratum**.

The stratum tells you how far you are from the reference clock (the world
[atomic clock](https://en.wikipedia.org/wiki/Atomic_clock)). The closer you are,
the lower is the `stratum` and the more stable your clock will be.

Usually, your stratum will be between 3 and 5. By convention, 16 means
"unsynchronized".

You can query the list of peers your NTP daemon is synchronized to with the
`ntpq` command:

```raw
$ sudo ntpq -c peers
     remote           refid      st t when poll reach   delay   offset  jitter
==============================================================================
-stardust.ploup. 195.13.23.5      3 u  782 1024  377    4.272   -1.984   2.479
+server.bertold. 193.190.230.66   2 u  679 1024  377    4.235   -0.152   0.629
*www.almaprovenc 145.238.203.14   2 u  854 1024  377    0.321   -0.225   0.502
+ns.rail.eu.org  138.96.64.10     2 u  563 1024  377    0.455    0.413   0.630
```

Again, check the `st` column (abbreviation for `stratum`) and make sure your
peers have a correct stratum. As above, 16 means "unsynchronized".

The `offset` and `jitter` column are also useful:

- the `offset` tells you how far away in time your peers are.
- the `jitter` tells you how stable your peers are.

Last but not least, you can troubleshoot network issues with the `ntpdate`
command.

For the test to be meaningful, you need to shut down temporarily the NTP
daemon:

```sh
sudo systemctl stop ntpd
```

Then, run the ntpdate command:

```raw
$ sudo ntpdate -q 0.rhel.pool.ntp.org
server 91.121.88.161, stratum 2, offset -0.000393, delay 0.02974
server 129.250.35.251, stratum 2, offset 0.004071, delay 0.02733
server 5.196.192.58, stratum 2, offset -0.005378, delay 0.03003
server 51.15.182.163, stratum 2, offset 0.000207, delay 0.02658
29 Mar 10:45:09 ntpdate[121271]: adjust time server 51.15.182.163 offset 0.000207 sec
```

It is important to shut down the NTP daemon and run the `ntpdate` command
with `sudo` in order for ntpdate to successfully bind to the NTP port, `123`.

If the `ntpdate` command fails, it is a strong indication that there is a network
issue between your host and the NTP peers.

After this step, do not forget to restart your NTP daemon:

```sh
sudo systemctl start ntpd
```
