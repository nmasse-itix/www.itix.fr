---
title: "Installation et mise à jour d'un OpenShift en environnement déconnecté"
date: 2021-08-20T00:00:00+02:00
opensource:
- OpenShift
topics:
- Containers
resources:
- '*.png'
- '*.svg'
---

Beaucoup de mes clients travaillent en environnement déconnecté.
C'est à dire que les environnements de production ne sont pas connecté à internet de manière directe: les flux entrants passent par un reverse proxy et les flux sortant sont souvent complètement interdits pour éviter l'exfiltration de données.
OpenShift peut être installé dans ces environnements déconnectés.
C'est même documenté par Red Hat.
La documentation pouvant être intimidante au premier abord, je propose ici un résumé "clé en main" de la marche à suivre.

<!--more-->

Dans cet article, nous installerons un OpenShift 4.7 et le mettrons à jour en 4.8 (dernière version disponible lors de l'écriture de cet article).

Les étapes résumées ici s'appuient sur ces documentations :

- [Mirroring images for a disconnected installation](https://docs.openshift.com/container-platform/4.8/installing/installing-mirroring-installation-images.html)
- [Using Operator Lifecycle Manager on restricted networks](https://docs.openshift.com/container-platform/4.8/operators/admin/olm-restricted-networks.html)
- [Updating a restricted network cluster](https://docs.openshift.com/container-platform/4.8/updating/updating-restricted-network-cluster.html)
- [Installing and configuring the OpenShift Update Service](https://docs.openshift.com/container-platform/4.7/updating/installing-update-service.html)

Dans la suite de cet article, je pars du principe que la station de travail de l'administrateur (ou le serveur de rebond le cas échéant) est connecté à Internet.
Toutes les commandes sont exécutées depuis ce poste.

Pour synchroniser les images, nous aurons besoin d'une registry docker privée, accessible depuis la station de travail de l'administrateur et depuis l'environnement de production.
Dans mon cas, c'est une simple instance [docker-distribution](https://docs.docker.com/registry/deploying/) déployée en conteneur.

## Pré-requis

Installer les outils ligne de commande d'OpenShift: **oc** et **opm**, ici en version 4.7.

```sh
curl -s https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.7/openshift-client-linux.tar.gz |sudo tar -zxv -C /usr/local/bin/ oc kubectl
curl -s https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.7/opm-linux.tar.gz |sudo tar -zxv -C /usr/local/bin/ opm 
```

Installer les outils habituels pour travailler avec les conteneurs: **skopeo**, **buildah** et **podman**.

Installer **grpcurl**.

```sh
curl -sL https://github.com/fullstorydev/grpcurl/releases/download/v1.8.1/grpcurl_1.8.1_linux_x86_64.tar.gz | tar -zxv -C /usr/local/bin grpcurl
```

Télécharger votre **pull secret** Red Hat depuis **cloud.redhat.com** et enregistrez le dans un fichier **rh-pull-secret.json**.

Créer le pull secret permettant de s'authentifier sur votre registry docker privée.
Ma registry est **registry.itix.xyz** et je m'y authentifie avec l'utilisateur **admin** et le mot de passe **s3cr3t**.

```sh
cat > my-pull-secret.json <<EOF
{
  "auths": {
    "registry.itix.xyz": {
      "auth": "$(echo -n 'admin:s3cr3t' | base64 -w0)",
      "email": "nmasse@redhat.com"
    }
  }
}
EOF
```

Fusionner les deux pull secrets à l'aide de **jq**.

```sh
jq -cs '.[0] * .[1]' rh-pull-secret.json my-pull-secret.json > pull-secret.json
```

## Installation d'un OpenShift 4.7

Dans l'exemple ci-dessous, je vais installer un OpenShift 4.7.10.
La liste de toutes les releases est disponible sur [quay.io](https://quay.io/repository/openshift-release-dev/ocp-release?tag=latest&tab=tags).

Lancer la recopie des images de conteneur.

```sh
OCP_RELEASE=4.7.10
ARCHITECTURE=x86_64
LOCAL_REGISTRY=registry.itix.xyz
LOCAL_REPOSITORY=openshift-mirror/ocp4
LOCAL_SECRET_JSON=pull-secret.json

oc adm release mirror -a ${LOCAL_SECRET_JSON}  \
     --from=quay.io/openshift-release-dev/ocp-release:${OCP_RELEASE}-${ARCHITECTURE} \
     --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
     --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}-release:${OCP_RELEASE}-${ARCHITECTURE}```
```

Cette commande ira copier les images de la 4.7.10 vers **registry.itix.xyz/openshift-mirror/ocp4** (images des composants d'OpenShift) et vers **registry.itix.xyz/openshift-mirror/ocp4-release** (image "chapeau").

Elle affichera à l'écran, une fois terminé, une section **imageContentSources** qu'il faudra ajouter au fichier **install-config.yaml**.
Pensez à la copier/coller, nous en aurons besoin pour la suite.

Exemple de sortie:

```
Success
Update image:  registry.itix.xyz/openshift-mirror/ocp4-release:4.7.10-x86_64
Mirror prefix: registry.itix.xyz/openshift-mirror/ocp4
Mirror prefix: registry.itix.xyz/openshift-mirror/ocp4-release:4.7.10-x86_64

To use the new mirrored repository to install, add the following section to the install-config.yaml:

imageContentSources:
- mirrors:
  - registry.itix.xyz/openshift-mirror/ocp4
  - registry.itix.xyz/openshift-mirror/ocp4-release
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - registry.itix.xyz/openshift-mirror/ocp4
  - registry.itix.xyz/openshift-mirror/ocp4-release
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev


To use the new mirrored repository for upgrades, use the following to create an ImageContentSourcePolicy:

apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: example
spec:
  repositoryDigestMirrors:
  - mirrors:
    - registry.itix.xyz/openshift-mirror/ocp4
    - registry.itix.xyz/openshift-mirror/ocp4-release
    source: quay.io/openshift-release-dev/ocp-release
  - mirrors:
    - registry.itix.xyz/openshift-mirror/ocp4
    - registry.itix.xyz/openshift-mirror/ocp4-release
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```

Nous pouvons maintenant créer le binaire **openshift-install**, patché avec les bonnes références vers les images de la registry privée.

```sh
oc adm release extract -a ${LOCAL_SECRET_JSON} --command=openshift-install "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}"
```

Pensez à stocker le fichier openshift-install généré dans un répertoire dédié et correctement nommé, afin de ne pas utiliser par mégarde une vieille version plus tard.
En effet, ce fichier openshift-install n'est valide que pour une install de **cette release** dans **cet environnement**.

Créer le fichier install-config.yaml comme pour une installation connectée, en fonction de vos choix d'architecture et de votre environnement.
Ajouter la section **imageContentSources** comme indiqué ci-dessus.

{{< highlight yaml "hl_lines=26-34" >}}
apiVersion: v1
baseDomain: itix.xyz
compute:
- name: worker
  hyperthreading: Enabled
  replicas: 0
controlPlane:
  name: master
  hyperthreading: Enabled
  replicas: 3
metadata:
  name: secure
networking:
  clusterNetworks:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  serviceNetwork:
  - 172.30.0.0/16
  networkType: OpenShiftSDN
platform:
  none: {}
pullSecret:
  '{"auths":{"cloud.openshift.com":{"auth":"REDACTED","email":"nmasse@redhat.com"},"quay.io":{"auth":"REDACTED","email":"nmasse@redhat.com"},"registry.connect.redhat.com":{"auth":"REDACTED","email":"nmasse@redhat.com"},"registry.redhat.io":{"auth":"REDACTED","email":"nmasse@redhat.com"},"registry.itix.xyz":{"auth":"REDACTED","email":"nmasse@redhat.com"}}}'
sshKey: |
  ssh-ed25519 REDACTED nmasse@redhat.com
imageContentSources:
- mirrors:
  - registry.itix.xyz/openshift-mirror/ocp4
  - registry.itix.xyz/openshift-mirror/ocp4-release
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - registry.itix.xyz/openshift-mirror/ocp4
  - registry.itix.xyz/openshift-mirror/ocp4-release
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
{{< / highlight >}}

Puis lancer l'installation comme pour une installation connectée.

```sh
./openshift-install create manifests --dir=.
./openshift-install create ignition-configs --dir=.
./openshift-install wait-for bootstrap-complete --dir=.
./openshift-install wait-for install-complete --dir=.
```

Notez l'utilisation du "./" devant la commande **openshift-install** pour utiliser la version générée précédemment.

L'installation devrait normalement se terminer en 30 à 45 minutes.

## Synchronisation des opérateurs en mode déconnecté

Dans un environnement déconnecté, les opérateurs nécessitent une procédure spécifique pour fonctionner.
En effet, l'Operator Hub présent dans OpenShift récupère la liste des opérateurs disponibles depuis internet.
Les opérateurs sont téléchargés depuis internet et font appel à des images de conteneurs également téléchargées depuis internet.

La procédure qui suit à pour objectif de sélectionner les opérateurs à rendre disponible dans l'environnement déconnecté et à répliquer localement toutes leurs images de conteneur ainsi que leurs dépendances.

La première étape est dresser une liste de tous les opérateurs disponibles en standard.

```sh
OCP_MAJOR_RELEASE=4.7

# Podman va s'authentifier avec le pull secret utilisé ci-dessus
mkdir -p ${XDG_RUNTIME_DIR}/containers
cp $LOCAL_SECRET_JSON ${XDG_RUNTIME_DIR}/containers/auth.json

# On lance une copie de l'operator index
podman run -p 50051:50051 -d --rm --name rhoi registry.redhat.io/redhat/redhat-operator-index:v${OCP_MAJOR_RELEASE}

# On sort la liste de tous les operateurs connus
grpcurl -plaintext localhost:50051 api.Registry/ListPackages | sed -E 's/.*"name": "([^"]+)".*/\1/; t; d'

# On peut arrêter l'operator index
podman stop -l
```

Vous pouvez ensuite choisir dans cette liste les opérateurs que vous souhaitez répliquer localement.
Dans l'exemple ci-dessous, j'ai choisi d'en répliquer deux: l'opérateur OpenShift Pipelines et l'opérateur Cincinnati (je l'utilise dans la suite de l'article).

```sh
# On construit un index contenant uniquement les opérateurs désirés
opm index prune -f registry.redhat.io/redhat/redhat-operator-index:v${OCP_MAJOR_RELEASE} -p openshift-pipelines-operator-rh,cincinnati-operator -t ${LOCAL_REGISTRY}/openshift-mirror/redhat-operator-index:v${OCP_MAJOR_RELEASE}

# On le pousse dans notre registry locale
podman push ${LOCAL_REGISTRY}/openshift-mirror/redhat-operator-index:v${OCP_MAJOR_RELEASE}

# On lance l'extraction des digests
oc adm catalog mirror -a ${LOCAL_SECRET_JSON} --manifests-only --index-filter-by-os='.*' ${LOCAL_REGISTRY}/openshift-mirror/redhat-operator-index:v${OCP_MAJOR_RELEASE} ${LOCAL_REGISTRY}/openshift-mirror

# On lance la copie des images
oc image mirror --skip-multiple-scopes=true -a ${LOCAL_SECRET_JSON} --filter-by-os='.*' -f manifests-redhat-operator-index-*/mapping.txt
```

Une fois les images répliquées localement, il faut ensuite provisionner l'Operator Hub avec la liste des opérateurs disponibles localement.

```sh
# On désactive les sources par défaut
oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'

# Et on crée la content source policy
oc apply -f  manifests-redhat-operator-index-*/imageContentSourcePolicy.yaml

# Et enfin la catalog source
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: local-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: ${LOCAL_REGISTRY}/openshift-mirror/redhat-operator-index:v${OCP_MAJOR_RELEASE}
  displayName: Local Catalog
  publisher: ITIX
  updateStrategy:
    registryPoll: 
      interval: 30m
EOF
```

## Installation de l'opérateur Cincinnati

L'opérateur [Cincinnati](https://github.com/openshift/cincinnati), aussi appellé OpenShift Update Service permet à OpenShift de calculer un chemin de mise à jour supporté.
Par défaut OpenShift s'appuie sur l'OpenShift Update Service qui est sur internet.
Mais dans un environnement déconnecté, il est nécessaire de l'héberger localement pour bénéficier de cette fonctionnalité.
Il n'est toutefois pas nécessaire d'en exécuter une instance sur chaque cluster : une instance centrale peut suffire.

Déployer l'opérateur Cincinnati.

```sh
oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-update-service
  annotations:
    openshift.io/node-selector: ""
  labels:
    openshift.io/cluster-monitoring: "true"
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: update-service-operator-group
  namespace: openshift-update-service
spec:
  targetNamespaces:
  - openshift-update-service
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: update-service-subscription
  namespace: openshift-update-service
spec:
  channel: v1
  installPlanApproval: "Automatic"
  source: "local-catalog"
  sourceNamespace: "openshift-marketplace"
  name: "cincinnati-operator"
EOF
```

Créer un fichier **Dockerfile** avec le contenu suivant.

{{< highlightFile "Dockerfile" "docker" "" >}}
FROM registry.access.redhat.com/ubi8/ubi:8.1
RUN curl -L -o cincinnati-graph-data.tar.gz https://github.com/openshift/cincinnati-graph-data/archive/master.tar.gz
CMD exec /bin/bash -c "tar xvzf cincinnati-graph-data.tar.gz -C /var/lib/cincinnati/graph-data/ --strip-components=1"
{{< / highlightFile >}}

Construire l'image correspondante et la pousser dans la registry privée.

```sh
podman build -f ./Dockerfile -t ${LOCAL_REGISTRY}/openshift-mirror/graph-data:latest
podman push ${LOCAL_REGISTRY}/openshift-mirror/graph-data:latest
```

Cette image contient le graphe des chemins de mise à jour de toutes les versions d'OpenShift.

Dans l'étape suivante, nous allons récupérer le certificat de l'Autorité de Certification de la registry privée et l'ajouter aux autorités de confiance.
Dans mon cas, le certificat de ma registry privée est signé par Let's Encrypt mais chez vous cela peut être différent.

```sh
curl -Lo ca.crt https://letsencrypt.org/certs/isrgrootx1.pem
oc create configmap additional-trusted-ca -n openshift-config --from-file=updateservice-registry=ca.crt
oc patch image.config.openshift.io/cluster --type=merge -p '{"spec":{"additionalTrustedCA":{"name":"additional-trusted-ca"}}}'
```

Note: il est important de respecter le nom de la clé (**updateservice-registry**) dans la Config Map car c'est cette clé que cherche l'opérateur Cincinnati à l'installation.

Déployer Cincinnati.

```sh
oc apply -f - <<EOF
apiVersion: updateservice.operator.openshift.io/v1
kind: UpdateService
metadata:
  name: service
  namespace: openshift-update-service
spec:
  replicas: 1
  releases: ${LOCAL_REGISTRY}/openshift-mirror/ocp4-release
  graphDataImage: ${LOCAL_REGISTRY}/openshift-mirror/graph-data:latest
EOF
```

Une fois déployé, patcher la configuration du cluster pour utiliser cette instance locale.

```sh
POLICY_ENGINE_GRAPH_URI="$(oc -n openshift-update-service get -o jsonpath='{.status.policyEngineURI}/api/upgrades_info/v1/graph{"\n"}' updateservice service)"
oc patch clusterversion version -p "{\"spec\":{\"upstream\":\"${POLICY_ENGINE_GRAPH_URI}\"}}" --type merge
```

## Mise à jour en 4.8

Pour préparer la mise à jour, j'utilise le [Red Hat OpenShift Container Platform Update Graph](https://access.redhat.com/labs/ocpupgradegraph/update_path).

{{< attachedFigure src="update-graph-1.png" title="Saisir la version source, la version cible et le canal de mise à jour." >}}

Il m'a permis de découvrir que le channel **fast-4.8** me permet de passer de la 4.7.10 à la 4.8.5 avec une seule étape intermédiaire: la 4.7.24.

{{< attachedFigure src="update-graph-2.png" title="En utilisant le canal fast-4.8, je peux passer de la 4.7.10 à la 4.7.24 à la 4.8.5." >}}

L'outil génère aussi un graphe contenant toutes les versions disponibles et les chemins autorisés entre ces versions.

{{< attachedFigure src="update-graph-3.png" title="Le graphe de mise à jour résultant." >}}

Nous effectuerons donc une mise à jour en deux étapes: d'abord une mise à jour vers la 4.7.24, puis vers la 4.8.5.

Première étape: passer sur le canal **fast-4.8**, qui est celui que j'ai choisi.

```sh
oc patch clusterversion version --type merge -p '{"spec": {"channel": "fast-4.8"}}'
```

Ensuite, il faut télécharger et appliquer la clé publique permettant de valider les signatures des images de conteneur de la nouvelle version.

```sh
OCP_RELEASE=4.7.24
DIGEST="$(skopeo inspect docker://quay.io/openshift-release-dev/ocp-release:${OCP_RELEASE}-x86_64 | jq -r .Digest)"
DIGEST_ALGO="${DIGEST%%:*}"
DIGEST_ENCODED="${DIGEST#*:}"
SIGNATURE_BASE64="$(curl -s "https://mirror.openshift.com/pub/openshift-v4/signatures/openshift/release/${DIGEST_ALGO}=${DIGEST_ENCODED}/signature-1" | base64 -w0 && echo)"
oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: release-image-${OCP_RELEASE}
  namespace: openshift-config-managed
  labels:
    release.openshift.io/verification-signatures: ""
binaryData:
  ${DIGEST_ALGO}-${DIGEST_ENCODED}: ${SIGNATURE_BASE64}
EOF
```

Cette étape déclenche une reconfiguration des noeuds du cluster (noeud après noeud).

```sh
oc get nodes -w
```

Attendez que tous les noeuds aient été reconfigurés.

On peut ensuite lancer une recopie des images de conteneur de la nouvelle version (comme pour l'installation).

```sh
oc adm release mirror -a ${LOCAL_SECRET_JSON}  \
     --from=quay.io/openshift-release-dev/ocp-release:${OCP_RELEASE}-${ARCHITECTURE} \
     --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
     --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}-release:${OCP_RELEASE}-${ARCHITECTURE}
```

Et lancer la mise à jour en tant que telle.

```sh
oc adm upgrade --allow-explicit-upgrade --to-image ${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}-release@${DIGEST_ALGO}:${DIGEST_ENCODED}
```

Une fois le cluster mis à jour en 4.7.24, vous pouvez refaire la procédure de mise à jour vers la version 4.8.5.

```sh
OCP_RELEASE=4.8.5
...
```

## Conclusion

Dans cet article nous avons installé un OpenShift 4.7, avons synchronisé les opérateurs, déployé l'OpenShift Update Service et enfin mis à jour OpenShift vers la version 4.8.
Tout ça dans un environnement déconnecté d'internet !
