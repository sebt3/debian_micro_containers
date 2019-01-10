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
#@DESC@  descheduler
#@GROUP@ monitor
descheduler.source.verify() { task.verify.permissive; }
descheduler.source() {
	source.git descheduler "https://github.com/kubernetes-incubator/descheduler.git"
}


descheduler.build.verify() { task.verify.permissive; }
descheduler.build() {
	build.copy.source descheduler
	build.make descheduler
}

descheduler.install() {
	install.init
	mkdir -p "$DIR_DEST/bin/"
	cp "$DIR_BUILD/descheduler/_output/bin/descheduler" "$DIR_DEST/bin/"
}

descheduler.config() {
	mkdir -p "$DIR_DEST/config"
	cat >"$DIR_DEST/start.d/descheduler" <<ENDF
exec /bin/descheduler --policy-config-file /config/policy.yaml -v 5 --logtostderr
ENDF
}

file.descheduler.conf() {
	json.file <<END
apiVersion: "descheduler/v1alpha1"
kind: "DeschedulerPolicy"
strategies:
  "LowNodeUtilization":
     enabled: true
     params:
       nodeResourceUtilizationThresholds:
         thresholds:
           "cpu" : 12
           "memory": 12
           "pods": 6
         targetThresholds:
           "cpu" : 20
           "memory": 20
           "pods": 20
  "RemoveDuplicates":
    enabled: true
  "RemovePodsViolatingInterPodAntiAffinity":
    enabled: true
  "RemovePodsViolatingNodeAffinity":
    enabled: true
    params:
      nodeAffinityType:
      - "requiredDuringSchedulingIgnoredDuringExecution"
END
}

descheduler.deploy() {
	CNAME=${CNAME:-"descheduler"}
	CPREFIX=${CPREFIX:-"descheduler-"}
	kube.configmap	"${CPREFIX}config" "$(json.label "policy.yaml" "$(file.descheduler.conf)")" "" "kube-system"
	#container.add	"${CPREFIX}descheduler"	"${REPODOCKER}/$CNAME:latest" '"descheduler"'
	#deploy.default
	kube.apply <<ENDF
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: descheduler-cluster-role
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "watch", "list"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list", "delete"]
- apiGroups: [""]
  resources: ["pods/eviction"]
  verbs: ["create"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: descheduler-sa
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: descheduler-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: descheduler-cluster-role
subjects:
- kind: ServiceAccount
  name: descheduler-sa
  namespace: kube-system
---
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: descheduler
  namespace: kube-system
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    metadata:
      name: descheduler
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: "true"
    spec:
      template:
        metadata:
          name: descheduler-pod
          annotations:
            scheduler.alpha.kubernetes.io/critical-pod: ""
        spec:
            containers:
            - name: descheduler
              image: ${REPODOCKER}/$CNAME:latest
              args:
              - "descheduler"
              volumeMounts:
              - mountPath: /config
                name: policy-volume
            restartPolicy: "OnFailure"
            serviceAccountName: descheduler-sa
            volumes:
            - name: policy-volume
              configMap:
                name: ${CPREFIX}config
ENDF
}


step.add.source  descheduler.source	"Get the descheduler sources from git"
step.add.build   descheduler.build	"Build the descheduler sources"
step.add.install descheduler.install	"Install descheduler"
step.add.install descheduler.config	"Configure descheduler"
step.add.deploy  descheduler.deploy  	"Deploy deschedulerDB to kubernetes"
