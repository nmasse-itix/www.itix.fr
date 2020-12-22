---
title: "Airgap OpenShift Installation: move the registry created using oc adm release mirror between environments"
date: 2019-11-18T00:00:00+02:00
opensource:
- Ansible
- OpenShift
- Skopeo
topics:
- Containers
---

Some customers, especially large banks, have very tight security requirements.
Most of them enforce a complete disconnection of their internal networks from the Internet.

When installing OpenShift in such environments (this is named "disconnected" or ["airgap" installation](http://www.cloud-computing-koeln.de/openshift-4-2-disconnected-install/)), all the OpenShift images have to be fetched (thanks to [oc adm release mirror](https://docs.openshift.com/container-platform/4.2/installing/installing_restricted_networks/installing-restricted-networks-preparations.html)) in a dedicated registry from a bastion host that is both on the internal network and on the Internet.

However, for some customers this is not secure enough. Most of them would rather download all the images locally (using *oc adm release mirror* ?), transport them on a removable media to the internal network and provision the target registry.

As described in this article, [skopeo](https://github.com/nmasse-itix/OpenShift-Examples/blob/master/Using-Skopeo/README.md) and Ansible can be a nice complement of *oc adm release mirror* to achieve this setup. Let's discover how!

The rest of this guide assumes that you followed [the official documentation](https://docs.openshift.com/container-platform/4.2/installing/installing_restricted_networks/installing-restricted-networks-preparations.html) and fetched on the bastion node all the required images in a dedicated registry using *oc adm release mirror*.

First, you will need a token that has administrative privileges on this registry.

```raw
$ oc whoami -t
AZERTYUIOPQSDFGHJKLMWXCVBN1234567890azertyu
```

Store it somewhere for later use.

```sh
export TOKEN=$(oc whoami -t)
```

Confirm your token can fetch the registry catalog.

```raw
$ curl -s https://docker-registry.default.svc:5000/v2/_catalog -H "Authorization: Bearer $TOKEN" |jq .

{
  "repositories": [
    "openshift/httpd",
    "openshift/java",
    "openshift/jenkins",
    [...]
    "openshift/php",
    "openshift/python"
  ]
}
```

As you may have guessed, this is the list of all the images provisioned by the *oc adm release mirror* command that we will need to export using skopeo.
But before doing so, we need to get the list of all the tags of each image.

Hopefully, there is also an API for this.

```raw
$ curl -s https://docker-registry.default.svc:5000/v2/openshift/php/tags/list -H "Authorization: Bearer $TOKEN" |jq .

{
  "name": "openshift/php",
  "tags": [
    "latest",
    "5.5",
    "5.6",
    "7.0",
    "7.1"
  ]
}
```

As an example, to export *openshift/php:5.5* from the *docker-registry.default.svc:5000* registry to the local filesystem (in */tmp/oci_registry*), you could use:

```sh
skopeo --insecure-policy copy --src-tls-verify=false --src-creds=admin:$TOKEN docker://docker-registry-default.app.itix.fr/openshift/php:5.5 oci:/tmp/oci_registry:openshift/php:5.5
```

We now have the basis to build the Ansible playbook that will dump the registry created by *oc adm release mirror* to the filesystem.

The first step of this playbook would be to fetch the registry catalog.
There is nothing fancy here, just a plain application of the [uri module](https://docs.ansible.com/ansible/latest/modules/uri_module.html).

```yaml
- hosts: localhost
  gather_facts: no
  vars:
    registry: docker-registry.default.svc:5000
    validate_certs: false
  tasks:
  - name: Fetch the catalog of the docker registry
    uri:
      url: 'https://{{ registry }}/v2/_catalog'
      headers:
        Authorization: Bearer {{ token }}
      status_code: 200
      return_content: yes
      validate_certs: '{{ validate_certs }}'
    register: catalog
```

The next step is to iterate on this catalog to fetch the tags of each image.
The [url lookup](https://docs.ansible.com/ansible/latest/plugins/lookup/url.html) plugin is used to query the registry API.
The image name is added in front of each tag (to construct the full image name: `image:tag`) using the [cartesian product filter](https://docs.ansible.com/ansible/latest/user_guide/playbooks_filters.html#product-filters).

```yaml
  - name: Construct a list of all available images
    set_fact:
      images: >
        {{ images|default([]) + new_images }}
    vars:
      image_tags: >
        {{ (lookup("url", "https://"~registry~"/v2/"~item~"/tags/list",
                          headers={"Authorization": "Bearer "~token},
                          validate_certs=validate_certs)|from_json).tags }}
      new_images: >
        {{ [item] | product(image_tags) | map('join', ':') | list }}
    loop: '{{ catalog.json.repositories }}'

  - debug:
      var: images
```

When using the url lookup plugin on MacOS, you might need to set the *OBJC_DISABLE_INITIALIZE_FORK_SAFETY* environment variable as explained in [#32499](https://github.com/ansible/ansible/issues/32499).

```sh
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

Finally, skopeo is called to download each image to */tmp/oci_registry*.

```yaml
- hosts: localhost
  gather_facts: no
  vars:
    target: /tmp/oci_registry
    [...]

  tasks:

  [...]

  - name: Downloading OpenShift images...
    command: skopeo --insecure-policy copy --src-tls-verify={{ validate_certs|bool|ternary('true','false') }} --src-creds=admin:{{ token }} 'docker://{{ registry }}/{{ item }}' 'oci:{{ target }}:{{ item }}'
    with_items: '{{ images }}'
```

The complete playbook [is available here](pull.yaml) and can be run as follow.

```sh
ansible-playbook pull.yaml -e token=$TOKEN
```

This will dump the registry at *docker-registry.default.svc:5000* to */tmp/oci_registry*.
If you want to target another registry or store the images somewhere else, you can pass the *registry* or *target* extra variables.

```sh
ansible-playbook pull.yaml -e token=$TOKEN -e registry=docker-registry-default.app.openshift.test -e target=/tmp/oci_registry
```

The images are stored as an OCI registry whose format is standardized.
It can be moved somewhere else, using a removable media for instance.

How this OCI registry can be imported in the target registry is a subject for another article.

Stay tuned.
