---
title: "One-liner to decode a Kubernetes secret (base64 encoded)"
date: 2019-06-07T00:00:00+02:00
opensource: 
- OpenShift
---

Creating a Kubernetes secret from a value is easy:

```raw
$ oc create secret generic my-secret --from-literal=secretValue=super-secret
secret/my-secret created
```

But getting back this value (from a Shell script, for instance) is not so easy since it is now base64 encoded:

```raw
$ oc get secret my-secret -o yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: qlkube
type: Opaque
data:
  secretValue: c3VwZXItc2VjcmV0
```

Hopefully, since the latest versions of Kubernetes, there is now a one-liner to extract the field and base64 decode it:

```raw
$ oc get secret my-secret -o go-template --template="{{.data.secretValue|base64decode}}"
super-secret
```

Enjoy!
