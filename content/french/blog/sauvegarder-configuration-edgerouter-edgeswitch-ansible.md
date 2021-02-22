---
title: "Sauvegarder la configuration de ses EdgeSwitch et EdgeRouter avec Ansible"
date: 2021-02-22T00:00:00+02:00
opensource: 
- Ansible
topics:
- IT Automation
---

J'utilise des équipements de marque Ubiquiti dans mon réseau informatique à la maison: un EdgeSwitch et un EdgeRouter.
Et jusqu'à présent, je n'avais pas mis en place de moyen simple et automatisé pour sauvegarder leur configuration.
C'est désormais chose faite avec ce playbook Ansible qui me sauvegarde la configuration des deux équipements et me l'enregistre dans un entrepôt Git.

<!--more-->

La sauvegarde du EdgeRouter est plutôt triviale car sa configuration est sauvegardée dans `/config/config.boot`.
Un simple **cat** appelé depuis le module **raw** récupère cette configuration et le module **copy** peut le sauvegarder localement.

```yaml
- name: Backup EdgeRouter configuration
  hosts: edgerouter
  gather_facts: no
  become: no
  tasks:
  - name: Create a folder for each device
    file:
      path: '{{ playbook_dir }}/{{ inventory_hostname }}'
      state: directory
    delegate_to: localhost

  - name: Fetch config.boot
    raw: cat /config/config.boot
    register: config_boot

  - copy:
      dest: '{{ playbook_dir }}/{{ inventory_hostname }}/config.boot'
      content: '{{ config_boot.stdout }}' 
    delegate_to: localhost
```

La sauvegarde du EdgeSwitch a été plus difficile.
Il n'existe pas d'accès SSH direct au système de fichiers ou à un shell: tout passe par une CLI type Juniper/Cisco.

J'ai donc rusé: j'utilise les API REST de l'interface Web Ubiquiti.
Un appel avec le module **uri** d'Ansible pour poster le login / mot de passe et récupérer un jeton d'authentification.
Un second appel toujours avec le même module pour récupérer une sauvegarde de la configuration.

```yaml
- name: Backup EdgeSwitch Configuration
  hosts: edgeswitch
  gather_facts: no
  become: no
  vars_prompt:
  - name: ubnt_password
    prompt: "EdgeSwitch Admin Password?"
  tasks:
  - name: Create a folder for each device
    file:
      path: '{{ playbook_dir }}/{{ inventory_hostname }}'
      state: directory
    delegate_to: localhost

  - name: Login on EdgeSwitch
    uri:
      url: 'https://{{ ansible_host }}/api/v1.0/user/login'
      method: POST
      body_format: json
      body:
        username: '{{ ubnt_username }}'
        password: '{{ ubnt_password }}'
      headers:
        Accept: "application/json, text/plain, */*"
        User-Agent: "Mozilla/5.0 (X11; Fedora; Linux x86_64; rv:84.0) Gecko/20100101 Firefox/84.0"
        Origin: 'https://{{ ansible_host }}'
        Referer: 'https://{{ ansible_host }}/'
      validate_certs: no
    register: auth
    delegate_to: localhost

  - name: Backup EdgeSwitch configuration
    uri:
      url: 'https://{{ ansible_host }}/api/v1.0/system/backup'
      method: GET
      headers:
        x-auth-token: '{{ auth.x_auth_token }}'
      return_content: no
      dest: '{{ playbook_dir }}/{{ inventory_hostname }}/edgeswitch.tgz'
      validate_certs: no
    delegate_to: localhost

  - name: Extract EdgeSwitch configuration
    command: 
      cmd: tar -xf {{ playbook_dir }}/{{ inventory_hostname }}/edgeswitch.tgz -C {{ playbook_dir }}/{{ inventory_hostname }} ./cfg-backup
      warn: no
    delegate_to: localhost
```

Je n'avais pas envie de stocker mon mot de passe administrateur dans l'inventaire c'est pourquoi le playbook le demande à l'utilisateur au démarrage (section **vars_prompt**).
Mais on pourrait tout à fait remplacer le **vars_prompt** par un accès au [coffre fort Ansible](https://docs.ansible.com/ansible/latest/user_guide/vault.html).

Le login administrateur, lui, est stocké dans le fichier inventaire via la variable **ubnt_username**.

```ini
[edgeswitch]
my-switch.example.test ansible_host=1.2.3.4 ubnt_username=nicolas
```

Les fichiers de configuration sont stockés dans un répertoire propre à chaque équipement... dont il n'y a plus qu'à suivre les versions dans un entrepôt Git !
