#!/bin/bash
# BSD 3-Clause License
# 
# Copyright (c) 2018, Sébastien Huss
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
##############################################################################
#@DESC@  cert-manager
#@GROUP@ sys
# https://github.com/jetstack/cert-manager
cert.source() {
	source.go github.com/jetstack/cert-manager/cmd/acmesolver
	source.go github.com/jetstack/cert-manager/cmd/webhook
	source.go github.com/jetstack/cert-manager/cmd/controller
}


cert.build() {
	set.env
	mkdir -p $GOPATH/bin/linux_$GOARCH/
	export CGO_ENABLED=0 GOOS=linux
	build.go github.com/jetstack/cert-manager/cmd/$1 -a -ldflags \'-extldflags "-static"\' -o $GOPATH/bin/linux_$GOARCH/$1
}
cert.build.acme.verify() { task.verify.permissive; }
cert.build.acme() {
	cert.build acmesolver
}
cert.build.webh.verify() { task.verify.permissive; }
cert.build.webh() {
	cert.build webhook
}
cert.build.ctrl.verify() { task.verify.permissive; }
cert.build.ctrl() {
	cert.build controller
}

cert.install() {
	install.init
	install.sslcerts
	install.go
}

cert.config() {
	cat >"$DIR_DEST/start.d/controller" <<ENDF
exec /usr/bin/controller --cluster-resource-namespace=\$POD_NAMESPACE --leader-election-namespace=\$POD_NAMESPACE
ENDF
}

cert.deploy() {
	kube.apply <<ENDKUBE
---
apiVersion: v1
kind: Namespace
metadata:
  name: "cert-manager"
  labels:
    name: "cert-manager"
    certmanager.k8s.io/disable-validation: "true"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-manager
  namespace: "cert-manager"
  labels:
    app: cert-manager
    release: cert-manager
    heritage: Tiller
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: certificates.certmanager.k8s.io
  annotations:
    "helm.sh/hook": crd-install
  labels:
    app: cert-manager
    release: cert-manager
    heritage: Tiller
spec:
  group: certmanager.k8s.io
  version: v1alpha1
  scope: Namespaced
  names:
    kind: Certificate
    plural: certificates
    shortNames:
      - cert
      - certs
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: challenges.certmanager.k8s.io
  annotations:
    "helm.sh/hook": crd-install
  labels:
    app: cert-manager
    release: cert-manager
    heritage: Tiller
spec:
  group: certmanager.k8s.io
  version: v1alpha1
  names:
    kind: Challenge
    plural: challenges
  scope: Namespaced
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: clusterissuers.certmanager.k8s.io
  annotations:
    "helm.sh/hook": crd-install
  labels:
    app: cert-manager
    release: cert-manager
    heritage: Tiller
spec:
  group: certmanager.k8s.io
  version: v1alpha1
  names:
    kind: ClusterIssuer
    plural: clusterissuers
  scope: Cluster
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: issuers.certmanager.k8s.io
  annotations:
    "helm.sh/hook": crd-install
  labels:
    app: cert-manager
    release: cert-manager
    heritage: Tiller
spec:
  group: certmanager.k8s.io
  version: v1alpha1
  names:
    kind: Issuer
    plural: issuers
  scope: Namespaced
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: orders.certmanager.k8s.io
  annotations:
    "helm.sh/hook": crd-install
  labels:
    app: cert-manager
    release: cert-manager
    heritage: Tiller
spec:
  group: certmanager.k8s.io
  version: v1alpha1
  names:
    kind: Order
    plural: orders
  scope: Namespaced
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: cert-manager
  labels:
    app: cert-manager
    release: cert-manager
    heritage: Tiller
rules:
  - apiGroups: ["certmanager.k8s.io"]
    resources: ["certificates", "issuers", "clusterissuers", "orders", "challenges"]
    verbs: ["*"]
  - apiGroups: [""]
    resources: ["configmaps", "secrets", "events", "services", "pods"]
    verbs: ["*"]
  - apiGroups: ["extensions"]
    resources: ["ingresses"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: cert-manager
  labels:
    app: cert-manager
    release: cert-manager
    heritage: Tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cert-manager
subjects:
  - name: cert-manager
    namespace: "cert-manager"
    kind: ServiceAccount
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cert-manager-view
  labels:
    app: cert-manager
    release: cert-manager
    heritage: Tiller
    rbac.authorization.k8s.io/aggregate-to-view: "true"
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
rules:
  - apiGroups: ["certmanager.k8s.io"]
    resources: ["certificates", "issuers"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cert-manager-edit
  labels:
    app: cert-manager
    release: cert-manager
    heritage: Tiller
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
rules:
  - apiGroups: ["certmanager.k8s.io"]
    resources: ["certificates", "issuers"]
    verbs: ["create", "delete", "deletecollection", "patch", "update"]
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: cert-manager
  namespace: "cert-manager"
  labels:
    app: cert-manager
    release: cert-manager
    heritage: Tiller
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cert-manager
      release: cert-manager
  template:
    metadata:
      labels:
        app: cert-manager
        release: cert-manager
      annotations:
    spec:
      serviceAccountName: cert-manager
      containers:
        - name: cert-manager
          image: "${REPODOCKER}/cert-manager:latest"
          imagePullPolicy: IfNotPresent
          args:
          - controller
          env:
          - name: POD_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
ENDKUBE
}

# https://cert-manager.readthedocs.io/en/latest/tutorials/ca/creating-ca-issuer.html
cert.build.acme.verify() { task.verify.permissive; }
cert.create() {
	net.run "$MASTER" openssl genrsa -out ca.key 2048
	net.run "$MASTER" openssl req -x509 -new -nodes -key ca.key -subj "/CN=home.local" -days 3650 -reqexts v3_req -extensions v3_ca -out ca.crt
	net.run "$MASTER" kubectl create secret tls ca-key-pair --cert=ca.crt --key=ca.key --namespace=default
	kube.apply << ENDF
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
metadata:
  name: ca-issuer
  namespace: default
spec:
  ca:
    secretName: ca-key-pair
ENDF
}

step.add.source  cert.source	"Get the cert-manager sources from git"
step.add.build   cert.build.acme "Build the cert-manager acmesolver sources"
step.add.build   cert.build.ctrl "Build the cert-manager controller sources"
step.add.build   cert.build.webh "Build the cert-manager webhook sources"
step.add.install cert.install	"Install cert-manager"
step.add.install cert.config	"Configure cert"
step.add.deploy  cert.deploy	"Deploy cert-manager to kubernetes"
step.add.deploy  cert.create	"Create the default issuer"
