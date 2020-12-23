---
title: "Bash Snippet: CLI World Clock"
date: 2019-03-18T00:00:00+02:00
---

When working in a global organization, colleagues are all around the world!
And thus answering to *"What time is it in their timezone?"* becomes a frequent
task. I initially used an online service for this but it is cumbersome and
requires me to leave my terminal.

Let's meet the CLI World clock!

<!--more-->

```sh
function t() {
  for tz in Europe/Paris Europe/Dublin US/Eastern US/Central US/Pacific; do
    echo -e "$tz:\t$(TZ=$tz date -R)"
  done
}
```

You can copy/paste this snippet in your terminal or add it to your `.bashrc`
to have it handy on every open terminal.

Each time I want to know which time it is for my colleagues, I run the `t`
command:

```raw
$ t
Europe/Paris:    Mon, 18 Mar 2019 18:33:49 +0100
Europe/Dublin:   Mon, 18 Mar 2019 17:33:49 +0000
US/Eastern:      Mon, 18 Mar 2019 13:33:49 -0400
US/Central:      Mon, 18 Mar 2019 12:33:49 -0500
US/Pacific:      Mon, 18 Mar 2019 10:33:49 -0700
```

The timezones used here comes from `/usr/share/zoneinfo/`.
