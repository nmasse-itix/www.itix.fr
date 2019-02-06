---
title: "Use Ansible to manage the QoS of your OpenShift workload"
date: 2019-02-06T00:00:00+02:00
opensource: 
- OpenShift
- Ansible
---

As I was administering my OpenShift cluster, I found out that I had a too
much memory requests. To preserve a good quality of service on my cluster,
I had to tacle this issue.

Resource requests and limits in OpenShift (and Kubernetes in general) are
the concepts that helps define the quality of service of every running Pod.

Resource requests can target memory, CPU or both. When a Pod has a
resource request (memory, CPU or both), it is guaranted to receives those
resources and when it has a resource limit, it is cannot overconsume those
resources.

Based on the requests and limits, OpenShift divides the workload into three
classes of Quality of Service: Guaranteed, Burstable and Best Effort.

When the requests are equal to the limits, the Pod has a "Guaranteed" QoS.
When the requests are less than the limits, the Pod has a "Burstable" QoS.
And when no requests and no limits are set, the Pod has a "Best Effort" QoS.

All of this is true when there are enough resources for every running Pods.
But as soon as a resource shortage happens, OpenShift will start to throttle
CPU or kill Pods if there is no more memory.

It does so by first killing the Pods that have the "Best Effort" QoS, if the
situation does not improve, it continues with Pods that have the "Burstable"
QoS. Since the Kubernetes Scheduler used the requests and limits to schedule
Pods, you should not run into a situation where "Guaranteed" Pods needs to be
killed (hopefully).

**So, you definitely don't want to have all your eggs (Pods) in the same basket
(class of QoS)!**

Back to the original issue, I needed to find out which Pod were part of the
Burstable or Guaranteed QoS class and lower the less critical ones to the Best
Effort class. I settled for an Ansible playbook to help me fix this.

The first step was discovering which Pods were part of the Burstable or
Guaranteed QoS class. And since most Pods are created from a `Deployment`,
`DeploymentConfig` or `StatefulSet`, I had to find out which of those objects
had a `requests` or `limits` field in it.

This first task has been accomplished very easily with a first playbook:

```yaml
- name: List all DeploymentConfig having a request or limit set
  hosts: localhost
  gather_facts: no
  tasks:

  - name: Get a list of all DeploymentConfig on our OpenShift cluster
    command: oc get dc -o json --all-namespaces
    register: oc_get_dc
    changed_when: false

  - block:

    - debug:
        var: to_update

    vars:
      all_objects: '{{ (oc_get_dc.stdout|from_json)[''items''] }}'
      to_update: '{{ all_objects|json_query(json_query) }}'
      json_query: >
        [? spec.template.spec.containers[].resources.requests
            || spec.template.spec.containers[].resources.limits ].{
            name: metadata.name,
            namespace: metadata.namespace,
            kind: kind
        }
```

If you run it with `ansible-playbook /path/to/playbook.yaml` you will get a list
of all `DeploymentConfig` having requests or limits set:

```raw
PLAY [List all DeploymentConfig having a request or limit set] ***********************************************

TASK [Get a list of all DeploymentConfig on our OpenShift cluster] *******************************************
ok: [localhost]

TASK [debug] *************************************************************************************************
ok: [localhost] => {
    "to_update": [
        {
            "kind": "DeploymentConfig",
            "name": "router",
            "namespace": "default"
        },
        {
            "kind": "DeploymentConfig",
            "name": "docker-registry",
            "namespace": "default"
        },
        ...

PLAY RECAP ***************************************************************************************************
localhost                  : ok=2    changed=0    unreachable=0    failed=0
```

I completed the playbook to also find out the `Deployment` and `StatefulSet`
objects having requests or limits set.

```raw
  tasks:

  [...]

  - name: Get a list of all Deployment on our OpenShift cluster
    command: oc get deploy -o json --all-namespaces
    register: oc_get_deploy
    changed_when: false

  - name: Get a list of all StatefulSet on our OpenShift cluster
    command: oc get sts -o json --all-namespaces
    register: oc_get_sts
    changed_when: false

  - block:

    [...]

    vars:
      all_objects: >
        {{ (oc_get_dc.stdout|from_json)['items'] }}
        + {{ (oc_get_deploy.stdout|from_json)['items'] }}
        + {{ (oc_get_sts.stdout|from_json)['items'] }}
```

And last but not least, I added a call to the `oc set resources` command
in order to bring back those objects to the Best Effort QoS class.

```raw
  [...]

  - block:

    [...]

    - debug:
        msg: 'Will update {{ to_update|length }} objects'

    - pause:
        prompt: 'Proceed ?'

    - name: Change the QoS class to "Best Effort"
      command: >
        oc set resources {{ obj.kind }} {{ obj.name }} -n {{ obj.namespace }}
        --requests=cpu=0,memory=0 --limits=cpu=0,memory=0
      loop: '{{ to_update }}'
      loop_control:
        loop_var: obj
```

Since I do not want all Pods to have the Best Effort QoS class, I added a
blacklist of critical namespaces that should not be touched.

```raw
- name: Change the QoS class of commodity projects
  hosts: localhost
  gather_facts: no
  vars:
    namespace_blacklist:
    - default
    - openshift-sdn
    - openshift-monitoring
    - openshift-console
    - openshift-web-console

  tasks:

    [...]

    - name: Change the QoS class to "Best Effort"
      command: >
        oc set resources {{ obj.kind }} {{ obj.name }} -n {{ obj.namespace }}
        --requests=cpu=0,memory=0 --limits=cpu=0,memory=0
      loop: '{{ to_update }}'
      loop_control:
        loop_var: obj
      when: obj.namespace not in namespace_blacklist
```

You can find the complete playbook [here](change-qos.yaml). Of course, it is
very rough and would need to more work to be used on a daily basis but for a
single use this is sufficient.
