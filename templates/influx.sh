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
#@DESC@  influxDB
#@GROUP@ monitor
influx.source() {
	source.go github.com/influxdata/influxdb
}


influx.packages.verify() { task.verify.permissive; }
influx.packages() {
	cd $GOPATH/src/github.com/influxdata/influxdb
	[ -d tests ] && git mv tests _tests
	dep ensure
}

influx.build.verify() { task.verify.permissive; }
influx.build() {
	set.env
	export CGO_ENABLED=0 GOOS=linux
	cd $GOPATH/src/github.com/influxdata/influxdb
	go clean ./...
	go install ./...
}

influx.install() {
	install.init
	install.sslcerts
	install.go
}

influx.config() {
	mkdir -p "$DIR_DEST/etc/influxdb"
	cat >"$DIR_DEST/start.d/influx" <<ENDF
exec /usr/bin/influxd
ENDF
}

influx.deploy() {
	kube.claim "${CPREFIX}influxdb" "${INFLUX_CLAIM_SIZE:-"100Gi"}"
	VOLUMES=$(sed 's/^,//' <<<"$VOLUMES,$(json.volume.config "config" "influx"),$(json.volume.claim influx-data "${CPREFIX}influxdb")")
	MOUNTS=$(sed 's/^,//' <<<"$MOUNTS,$(json.mount config "/etc/influxdb"),$(json.mount influx-data "/var/lib/influxdb")")
	CNAME=${CNAME:-"influx"}
	LINKS+=("$(json.link.name api 8086)")
	LINKS+=("$(json.link.name admin 8083)")
	IP=10.100.10.100
	local content="$( json.file <<END
[meta]
  dir = "/var/lib/influxdb/meta"
  retention-autocreate = true
  logging-enabled = true
[data]
  dir = "/var/lib/influxdb/data"
  engine = "tsm1"
  wal-dir = "/var/lib/influxdb/wal"
  cache-max-memory-size = "300m"
  cache-snapshot-memory-size = "25m"
[coordinator]
[retention]
  enabled = true
[shard-precreation]
[monitor]
  store-enabled = false
  store-database = "_internal"
[http]
  enabled = true
  bind-address = ":8086"
  auth-enabled = false
  realm = "InfluxDB"
  log-enabled = false
  access-log-path  = "/var/log/influxdb/access.log"
  https-enabled = false
[logging]
  format = "auto"
  level = "info"
  suppress-logo = true
[subscriber]
  enabled = true
[[graphite]]
  enabled = false
  database = "graphite"
[[collectd]]
  enabled = false
[[opentsdb]]
  enabled = false
[[udp]]
  enabled = false
[continuous_queries]
  enabled = true
  log-enabled = false
  query-stats-enabled = true
  run-interval = "60s"
END
)"
	kube.configmap "influx" "$(json.label "influxdb.conf" "$content")" "$(json.label "run" "$CNAME")"
	CONTAINERS+=("$(json.container "${CPREFIX}influx" "192.168.10.200:5000/$CNAME:latest" '"influx"' "$MOUNTS" "$(json.port 8086),$(json.port 8083)")")
	deploy.default
}


step.add.source  influx.source		"Get the influxDB sources from git"
step.add.build   influx.packages	"Get go dependencies for influxDB"
step.add.build   influx.build		"Build the influxDB sources"
step.add.install influx.install		"Install influxDB"
step.add.install influx.config		"Configure influxDB"
step.add.deploy  influx.deploy  	"Deploy influxDB to kubernetes"
