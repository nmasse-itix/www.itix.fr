---
title: "Bash Snippet: Print a config file without comments"
date: 2019-04-23T00:00:00+02:00
---

Logging in on a server, printing a configuration file and trying to find the relevant setting from thousands of comment lines.
Sounds familiar?

Not that comments are useless in a configuration file but sometimes it's handy to print a configuration file without the comment lines.
Especially when the file is thousand lines long but the useful lines fit the twenty five lines of a standard terminal.

The `egrep` command which is standard on most Linux distributions and on MacOS, can strip out the unwanted lines:

```sh
egrep -v '^\s*(#|$)' /etc/ssh/sshd_config
```

The `-v` switch prints out the lines that **do not** match the given regex `^\s*(#|$)`.
And this regex captures:

- empty lines
- lines with only whitespaces
- lines that contains only comments

And now, your active sshd configuration fits a 25 lines terminal!

```raw
$ egrep -v '^\s*(#|$)'  /etc/ssh/sshd_config
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
SyslogFacility AUTHPRIV
PermitRootLogin no
AuthorizedKeysFile	.ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
GSSAPIAuthentication yes
GSSAPICleanupCredentials no
UsePAM yes
X11Forwarding yes
UseDNS no
AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES
AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT
AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE
AcceptEnv XMODIFIERS
Subsystem	sftp	/usr/libexec/openssh/sftp-server
```
