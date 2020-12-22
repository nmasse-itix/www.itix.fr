---
title: "Check the Ansible version number in a playbook"
date: 2019-11-18T00:00:00+02:00
opensource:
- Ansible
topics:
- IT Automation
---

My Ansible playbooks sometimes use features that are available only in a very recent versions of Ansible.

To prevent unecessary troubles to the team mates that will execute them, I like to add a task at the very beginning of my playbooks to check the Ansible version number and abort if the requirements are not met.

```yaml
- name: Verify that Ansible version is >= 2.4.6
  assert:
    that: "ansible_version.full is version_compare('2.4.6', '>=')"
    msg: >-
      This module requires at least Ansible 2.4.6. The version that comes
      with RHEL and CentOS by default (2.4.2) has a known bug that prevent
      this role from running properly.
```
