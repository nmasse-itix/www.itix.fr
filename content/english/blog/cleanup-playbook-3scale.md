---
title: "A cleanup playbook for 3scale"
date: 2020-04-28T00:00:00+02:00
opensource:
- 3scale
- Ansible
topics:
- API Management
- IT Automation
---

If you are running integration tests embedding 3scale or are doing a lot of 3scale demos, you might sooner or later **have plenty of services declared in the 3scale Admin console**, which could reveal difficult to work with.
And with the new feature named *API-as-a-Product*, there are now **Backends and Products** to delete, making the cleanup by hand a bit tedious.

This article explains how to cleanup a 3scale tenant using Ansible.

## Pre-requisites

Make sure Ansible is installed locally and is a fairly recent version.

```
$ ansible --version
ansible 2.8.10
  config file = /etc/ansible/ansible.cfg
  configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3.6/site-packages/ansible
  executable location = /usr/bin/ansible
  python version = 3.6.8 (default, Oct 11 2019, 15:04:54) [GCC 8.3.1 20190507 (Red Hat 8.3.1-4)]
```

Find the name of your 3scale Admin Portal and set it as a environment variable.

For 3scale SaaS tenants, it will be something like this:

```sh
export ADMIN_PORTAL_HOSTNAME="<TENANT>-admin.3scale.net"
```

For 3scale 2.8 installed on-premises, you can find the default admin portal hostname by querying OpenShift.

```sh
export ADMIN_PORTAL_HOSTNAME="$(oc get route -l zync.3scale.net/route-to=system-provider -o go-template='{{(index .items 0).spec.host}}')"
```

Now, generate an Access Token with read/write privileges over the **Account Management API** and set it as a shell variable.

```sh
export THREESCALE_TOKEN="123...456"
```

For 3scale 2.8 installed on-premises, there is a default token that you can use if you wish.

```sh
export THREESCALE_TOKEN="$(oc get secret system-seed -o go-template --template='{{.data.ADMIN_ACCESS_TOKEN|base64decode}}')"
```

Fetch the cleanup playbook.

```sh
curl -Lo cleanup.yaml {{< baseurl >}}blog/cleanup-playbook-3scale/cleanup.yaml
```

## Cleanup 3scale

The cleanup playbook uses the environment variables set previously to connect to the 3scale Admin Portal and get a list of the Products, Backends and ActiveDocs objects that makes up a 3scale service.
This list is filtered to exclude the default service **api** (*Echo API*).
The list is then filtered using the **systemname_filter** parameter to include only Products, Backends and ActiveDocs that have the given string in their system_name.

Then all the matching Products, Backends and ActiveDocs are removed.

For instance, to remove all objects related to the **dev_library_1** and **prod_library_1** services, you could run the playbook like this:

```sh
ansible-playbook cleanup.yaml -e systemname_filter=library
```

And to remove the **dev_library_1** and **dev_petstore_1** services, you could run the playbook like this:

```sh
ansible-playbook cleanup.yaml -e systemname_filter=dev_
```

## Conclusion

This article explained how to cleanup a 3scale tenant using Ansible, by deleting all *Products*, *Backends* and *ActiveDocs* matching a given criterion.
Now, you can reset your development environment or demo environment easily!
