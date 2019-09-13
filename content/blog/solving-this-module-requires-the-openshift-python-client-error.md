---
title: "Solving the Ansible error 'This module requires the OpenShift Python client'"
date: 2019-09-13T00:00:00+02:00
opensource: 
- OpenShift
- Ansible
---

If you are using MacOS to develop Operators based on Ansible or simply running Ansible playbooks straight from your Mac, you might encounter this error:

> **This module requires the OpenShift Python client**.

When coping with this error message, two items need to be checked:

- The *openshift* python module needs to be installed **using the *pip* command bundled with your Ansible**.
- If you are not using the *implicit localhost*, **your inventory needs to be updated**.

## Install the openshift python module

As a MacOS user, you most likely installed Ansible using *brew*.
When doing so, Ansible comes bundled with everything needed for its execution: python, all python modules, etc.
There is a caveat with this approach: the bundled python interpreter does not load the python modules that are installed system-wide.

This means that if you installed the openshift python module using `pip install openshift`, it will not be picked up by Ansible.

**The openshift python module needs to be installed using the pip command bundled with your Ansible.**

First, discover which version of Ansible you are running:

```raw
$ ansible --version
ansible 2.7.10
  config file = /etc/ansible/ansible.cfg
  configured module search path = ['/Users/nmasse/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/local/Cellar/ansible/2.7.10/libexec/lib/python3.7/site-packages/ansible
  executable location = /usr/local/bin/ansible
  python version = 3.7.3 (default, Mar 27 2019, 09:23:39) [Clang 10.0.0 (clang-1000.11.45.5)]
```

Then, you can install the *openshift* module using the *pip* command bundled with your Ansible:

```sh
/usr/local/Cellar/ansible/2.7.10/libexec/bin/pip install openshift
```

Of course, in the previous command you will have to replace `2.7.10` with your version of Ansible!

If that does not solve the problem, continue with the next item: **check your inventory**.

## Check your inventory

When Ansible runs a task locally (using `connection: local` for instance), there are two python interpreter loaded:

- One for the Ansible process that reads, parses and execute your playbook.
- One for each task that is run.

When running a task locally, there is a caveat with the [Ansible implicit localhost](https://docs.ansible.com/ansible/latest/inventory/implicit_localhost.html).

If your inventory contains a *localhost* entry, it disables the **implicit localhost** entry and you need to set the python interpreter explicitly.

Hopefully, the fix is easy.
In your inventory, replace your *localhost* entries with this one:

```ini
localhost ansible_connection=local ansible_python_interpreter="{{ansible_playbook_python}}"
```

Happy Ansible hacking!
