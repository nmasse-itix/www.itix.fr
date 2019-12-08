---
title: "Ansible: Add a prefix or suffix to all items of a list"
date: 2019-11-18T00:00:00+02:00
opensource:
- Ansible
---

Recently, in [one of my Ansible playbooks](../airgap-openshift-installation-move-registry-created-using-oc-adm-release-mirror-between-environments) I had to prefix all items of a list with a chosen string.

Namely, from the following list:

```python
[ "bar", "bat", "baz" ]
```

I want to have:

```python
[ "foobar", "foobat", "foobaz" ]
```

The recipe I used to add a prefix to all items of a list is:

```yaml
- debug:
    var: result
  vars:
    prefix: foo
    a_list: [ "bar", "bat", "baz" ]
    result: "{{ [prefix] | product(a_list) | map('join') | list }}"
```

If you need to add a suffix to all items of a list instead, you can use:

```yaml
- debug:
    var: result
  vars:
    suffix: foo
    a_list: [ "bar", "bat", "baz" ]
    result: "{{ a_list | product([suffix]) | map('join') | list }}"
```
