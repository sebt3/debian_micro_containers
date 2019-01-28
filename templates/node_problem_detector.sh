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
#@DESC@  node-problem-detector
#@GROUP@ sys
#npd.sources.verify() { task.verify.permissive; }
npd.source() {
	out.cmd go get -u k8s.io/node-problem-detector
	return 0
}
npd.deps() {
	cd "$DIR_SOURCE/src/k8s.io/node-problem-detector"
	out.cmd go get ./...
	return 0
}

npd.build.verify() { task.verify.permissive; }
npd.build() {
	set.env
	cd $DIR_SOURCE/src/k8s.io/node-problem-detector
	mkdir -p "$DIR_BUILD/bin"
	export CGO_ENABLED=1 GOOS=linux
	export GOGCCFLAGS="-fPIC -m64 -pthread"
	echo build bin/node-problem-detector
	go build -o "$DIR_BUILD/bin/node-problem-detector" -ldflags ' -X k8s.io/node-problem-detector/pkg/version.version=UNKNOWN' -tags journald cmd/node_problem_detector.go
	echo build bin/log-counter
	go build -o "$DIR_BUILD/bin/log-counter" -ldflags '-X k8s.io/node-problem-detector/pkg/version.version=UNKNOWN' -tags journald cmd/logcounter/log_counter.go
}

npd.install() {
	install.init
	install.sslcerts
	mkdir -p "$DIR_DEST/config"
	cp -Rapf "$DIR_BUILD/bin" "$DIR_DEST/bin"
}

npd.config() {
	cat >"$DIR_DEST/start.d/npd" <<ENDF
exec /bin/node-problem-detector --logtostderr --system-log-monitors=/config/kernel-monitor.json,/config/docker-monitor.json
ENDF
}

file.kernel() {
	json.file <<END
    {
        "plugin": "kmsg",
        "logPath": "/dev/kmsg",
        "lookback": "5m",
        "bufferSize": 10,
        "source": "kernel-monitor",
        "conditions": [
            {
                "type": "KernelDeadlock",
                "reason": "KernelHasNoDeadlock",
                "message": "kernel has no deadlock"
            },
            {
                "type": "ReadonlyFilesystem",
                "reason": "FilesystemIsReadOnly",
                "message": "Filesystem is read-only"
            }
        ],
        "rules": [
            {
                "type": "temporary",
                "reason": "OOMKilling",
                "pattern": "Kill process \\\\d+ (.+) score \\\\d+ or sacrifice child\\\\nKilled process \\\\d+ (.+) total-vm:\\\\d+kB, anon-rss:\\\\d+kB, file-rss:\\\\d+kB.*"
            },
            {
                "type": "temporary",
                "reason": "TaskHung",
                "pattern": "task \\\\S+:\\\\w+ blocked for more than \\\\w+ seconds\\\\."
            },
            {
                "type": "temporary",
                "reason": "UnregisterNetDevice",
                "pattern": "unregister_netdevice: waiting for \\\\w+ to become free. Usage count = \\\\d+"
            },
            {
                "type": "temporary",
                "reason": "KernelOops",
                "pattern": "BUG: unable to handle kernel NULL pointer dereference at .*"
            },
            {
                "type": "temporary",
                "reason": "KernelOops",
                "pattern": "divide error: 0000 \\\\[#\\\\d+\\\\] SMP"
            },
            {
                "type": "permanent",
                "condition": "KernelDeadlock",
                "reason": "AUFSUmountHung",
                "pattern": "task umount\\\\.aufs:\\\\w+ blocked for more than \\\\w+ seconds\\\\."
            },
            {
                "type": "permanent",
                "condition": "KernelDeadlock",
                "reason": "DockerHung",
                "pattern": "task docker:\\\\w+ blocked for more than \\\\w+ seconds\\\\."
            },
            {
                "type": "permanent",
                "condition": "ReadonlyFilesystem",
                "reason": "FilesystemIsReadOnly",
                "pattern": "Remounting filesystem read-only"
            }
        ]
    }
END
}
file.docker() {
	json.file <<END
    {
        "plugin": "journald",
        "pluginConfig": {
            "source": "dockerd"
        },
        "logPath": "/var/log/journal",
        "lookback": "5m",
        "bufferSize": 10,
        "source": "docker-monitor",
        "conditions": [],
        "rules": [
            {
                "type": "temporary",
                "reason": "CorruptDockerImage",
                "pattern": "Error trying v2 registry: failed to register layer: rename /var/lib/docker/image/(.+) /var/lib/docker/image/(.+): directory not empty.*"
            }
        ]
    }
END
}

npd.deploy() {
	CNAME=${CNAME:-"npd"}
	CPREFIX=${CPREFIX:-"npd-"}
	NAMESPACE=kube-system
	store.map	"${CPREFIX}config" "/config" "$(json.label "kernel-monitor.json" "$(file.kernel)"),$(json.label "docker-monitor.json" "$(file.docker)")"
	kube.apply << ENDF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: node-problem-detector
  namespace: kube-system
  labels:
    app.kubernetes.io/name: node-problem-detector
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: node-problem-detector
  labels:
    app.kubernetes.io/name: node-problem-detector
rules:
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - nodes/status
  verbs:
  - patch
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
  - patch
  - update
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: node-problem-detector
  labels:
    app.kubernetes.io/name: node-problem-detector
subjects:
- kind: ServiceAccount
  name: node-problem-detector
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: node-problem-detector
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-problem-detector
  namespace: kube-system
  labels:
    app.kubernetes.io/name: node-problem-detector
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: node-problem-detector
  template:
    metadata:
      labels:
        app.kubernetes.io/name: node-problem-detector
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      serviceAccountName: node-problem-detector
      containers:
        - name: node-problem-detector
          image:  "${REPODOCKER}/node_problem_detector:latest"
          imagePullPolicy: "Always"
          args:
            - "npd"
          securityContext:
            privileged: true
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          volumeMounts:
            - name: log
              mountPath: /var/log
            - name: localtime
              mountPath: /etc/localtime
              readOnly: true
            - name: config
              mountPath: /config
              readOnly: true
      volumes:
        - name: log
          hostPath:
            path: /var/log/
        - name: localtime
          hostPath:
            path: /etc/localtime
            type: "FileOrCreate"
        - name: config
          configMap:
            name: ${CPREFIX}config
ENDF

	#env.from        "NODE_NAME" "spec.nodeName"
	#store.dir	log "/var/log" "/var/log"
	#store.file	kmsg "/dev/kmsg" "/dev/kmsg"
	#store.file	localtime "/etc/localtime" "/etc/localtime"
	#CONTS="$(json.syscontainer "${CPREFIX}npd" "${REPODOCKER}/$CNAME:latest" '"npd"' "$(json.res "10m" "80Mi")")"
	#LABELS="$(json.label "run" "$CNAME")"
	#kube.ds "$CNAME" "$LABELS" "$CONTS" "$VOLUMES"
}


step.add.source  npd.source	"Get the node-problem-detector sources"
step.add.source  npd.deps	"Get the node-problem-detector dependencies"
step.add.build   npd.build	"Build the node-problem-detector sources"
step.add.install npd.install	"Install node-problem-detector"
step.add.install npd.config	"Configure node-problem-detector"
step.add.deploy  npd.deploy  	"Deploy node-problem-detector to kubernetes"
