---
title: "Secure your OpenShift 4 cluster with OpenID Connect authentication"
date: 2020-04-17T00:00:00+02:00
opensource:
- OpenShift
topics:
- OpenID Connect
---

OpenShift, starting with the version 4, is installed with a temporary administrator account, [kubeadmin](https://docs.openshift.com/container-platform/4.3/authentication/remove-kubeadmin.html).
When searching for a definitive solution, it might be tempting to go for the very classical "login and password" prompt, backed by an [htpasswd file](https://docs.openshift.com/container-platform/4.3/authentication/identity_providers/configuring-htpasswd-identity-provider.html).
But this is yet another password to remember!

OpenShift can handle the [OpenID Connect](https://openid.net/connect/) protocol and thus offers Single Sign On to its users.
No additional password to remember: you can login to the OpenShift console with your [Google Account](../use-google-account-openid-connect-provider) for instance.

## Pre-requisites

The rest of this article assumes you have already setup your OpenID Connect client in the Google Developer Console as explained in this article: [Use your Google Account as an OpenID Connect provider](../use-google-account-openid-connect-provider).

Then, create a secret in the **openshift-config** namespace containing the client secret generated by the Google Developer Console.

```sh
oc create secret generic google-client-secret --from-literal=clientSecret="<YOUR CLIENT_SECRET>" -n openshift-config
```

The rest of the procedure differs, depending if you are the member of a Google Suite or a regular GMail user.

## Configure Google Authentication in OpenShift 4 for Google Suite users

Create an **OAuth** object in the **openshift-config** namespace.
Do not forget to add the Client ID generated by the Google Developer Console in the **clientID** field.
You will also have to set the custom domain of your Google Suite in the **hostedDomain** field.

```sh
oc apply -f - <<EOF
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
  namespace: openshift-config
spec:
  identityProviders:
  - name: Google
    mappingMethod: claim
    type: Google
    google:
      clientID: "<YOUR CLIENT_ID>.apps.googleusercontent.com"
      clientSecret:
        name: google-client-secret
      hostedDomain: "example.com"
EOF
```

If you have a Google Suite, there is nothing more to configure.
You can login to the OpenShift Console with your Google account!

You can even work collaboratively since every user of your Google Suite can login and use your OpenShift cluster!
If you do not want to share your OpenShift cluster, you can disable the [self-provisioner role](https://docs.openshift.com/container-platform/4.3/applications/projects/configuring-project-creation.html#disabling-project-self-provisioning_configuring-project-creation).

## Configure Google Authentication in OpenShift 4 for regular GMail users

If you have only a regular Gmail account, the procedure is a bit different and slightly longer.

You will need to set the **mappingMethod** field to **lookup** and leave the **hostedDomain** field empty.

```sh
oc apply -f - <<EOF
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: Google
    mappingMethod: lookup
    type: Google
    google:
      clientID: "<YOUR CLIENT_ID>.apps.googleusercontent.com"
      clientSecret:
        name: google-client-secret
      hostedDomain: ""
EOF
```

If you try to login on the OpenShift console with your GMail account, it will fail with the following message: "Could not find user".
**This is expected since we have not yet create the matching user in OpenShift.**

Create a user.

```sh
oc create user nicolas --full-name="Nicolas MASSE"
```

Then, retrieve your Google internal User ID from the OpenShift OAuth logs.

```sh
for pod in $(oc get pods -l app=oauth-openshift -o name -n openshift-authentication); do
  oc logs --tail=10 $pod -n openshift-authentication | grep useridentitymapping.user.openshift.io
done
```

You should get at least one line looking as such:

```
E0417 14:18:55.872542       1 errorpage.go:26] AuthenticationError: lookup of user for "Google:114331641802984310666" failed: useridentitymapping.user.openshift.io "Google:114331641802984310666" not found
```

The string behind "Google:" is your Google internal User ID.

Create an OpenShift identity object from such internal user ID.

```sh
oc create identity Google:114331641802984310666
```

Finally, create an identity mapping between this identity and the user you created earlier.

```sh
oc create useridentitymapping Google:114331641802984310666 nicolas
```

And now you can login on your OpenShift 4 cluster with your GMail account!