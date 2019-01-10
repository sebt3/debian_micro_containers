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
#@DESC@  telegraf
#@GROUP@ monitor
telegraf.source() {
	source.go github.com/influxdata/telegraf
}


telegraf.build.verify() { task.verify.permissive; }
telegraf.build() {
	set.env
	export CGO_ENABLED=0 GOOS=linux
	cd $GOPATH/src/github.com/influxdata/telegraf
	#make
	out.cmd dep ensure -vendor-only
	out.cmd go build ./cmd/telegraf
}

telegraf.install() {
	install.init
	mkdir -p "$DIR_DEST/usr/bin/" "$DIR_DEST/etc/telegraf/telegraf.d" "$DIR_DEST/var/log/telegraf"
	cp $GOPATH/src/github.com/influxdata/telegraf/telegraf "$DIR_DEST/usr/bin/"
}

telegraf.config() {
	cat >"$DIR_DEST/start.d/telegraf" <<ENDF
exec /usr/bin/telegraf -config /etc/telegraf/telegraf.conf -config-directory /etc/telegraf/telegraf.d
ENDF
}
file.ds() {
	# TODO: ajouter docker et kubernetes
	# https://github.com/influxdata/tick-charts/blob/master/telegraf-ds/templates/configmap.yaml
	json.file <<END
[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "200ms"
  flush_interval = "10s"
  flush_jitter = "200ms"
  quiet = true
  logfile = ""
  hostname = "\$HOSTNAME"
  omit_hostname = false
[[outputs.influxdb]]
  urls = ["http://10.100.10.100:8086"]
  database = "telegraf"
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false
[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "overlay", "aufs", "squashfs"]
[[inputs.diskio]]
  devices = ["nvme0n1", "mmcblk1p7"]
[[inputs.mem]]
[[inputs.processes]]
[[inputs.system]]
[[inputs.netstat]]
[[inputs.temp]]
[[inputs.net]]
[[inputs.netstat]]
[[inputs.kubernetes]]
  url = "https://\$HOSTIP:10250"
  bearer_token = "/var/run/secrets/kubernetes.io/serviceaccount/token"
  insecure_skip_verify = true
END
}

telegraf.deployds() {
	CNAME=${CNAME:-"telegraf"}
	CPREFIX=${CPREFIX:-"telegraf-ds-"}
	store.map	"${CPREFIX}config" "/etc/telegraf" "$(json.label "telegraf.conf" "$(file.ds)")"
	store.file	utmp "/var/run/utmp" "/var/run/utmp"
	store.dir	root "/rootfs" "/"
	store.dir	proc "/rootfs/proc" "/proc"
	store.dir	sys "/rootfs/sys" "/sys"
	env.add		"HOST_MOUNT_PREFIX" "/rootfs"
	env.add		"HOST_PROC" "/rootfs/proc"
	env.add		"HOST_SYS" "/rootfs/sys"
	env.from	"HOSTNAME" "spec.nodeName"
	env.from	"HOSTIP" "status.hostIP"
	CONTS="$(json.syscontainer "${CPREFIX}telegraf" "${REPODOCKER}/$CNAME:latest" '"telegraf"'  "$(json.res "100m" "50Mi")" )"
	LABELS="$(json.label "run" "$CNAME")"
	kube.ds "$CNAME" "$LABELS" "$CONTS" "$VOLUMES"
}

file.deploy() {
	json.file <<END
[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "200ms"
  flush_interval = "10s"
  flush_jitter = "200ms"
  quiet = true
  logfile = ""
  hostname = "\$HOSTNAME"
  omit_hostname = false
[[outputs.influxdb]]
  urls = ["http://10.100.10.100:8086"]
  database = "services"
[[inputs.influxdb]]
  urls = ["http://influx:8086/debug/vars"]
  timeout = "5s"
[[inputs.internal]]
  collect_memstats = true
[[inputs.kapacitor]]
  urls = ["http://kapacitor:9092/kapacitor/v1/debug/vars"]
  timeout = "5s"
[[inputs.prometheus]]
  kubernetes_services = ["http://kube-state-metrics.kube-system:8080/metrics","http://heapster.kube-system/metrics"]
END
}
telegraf.deploy() {
	CNAME=${CNAME:-"telegraf"}
	CPREFIX=${CPREFIX:-"telegraf-"}
	store.map	"${CPREFIX}config" "/etc/telegraf" "$(json.label "telegraf.conf" "$(file.deploy)")"
	env.add		"HOSTNAME" "telegraf-service"
	CONTS="$(json.container "${CPREFIX}telegraf" "${REPODOCKER}/$CNAME:latest" '"telegraf"' "$(json.res "100m" "50Mi")")"
	LABELS="$(json.label "run" "$CNAME")"
	kube.deploy "$CNAME" "$LABELS" "$CONTS" "$VOLUMES"
}


step.add.source  telegraf.source	"Get the telegraf sources from git"
step.add.build   telegraf.build	"Build the telegraf sources"
step.add.install telegraf.install	"Install telegraf"
step.add.install telegraf.config	"Configure telegraf"
step.add.deploy  telegraf.deployds  	"Deploy telegraf daemonSet to kubernetes"
step.add.deploy  telegraf.deploy  	"Deploy telegraf to kubernetes"
