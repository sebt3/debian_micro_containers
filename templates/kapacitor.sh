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
#@DESC@  kapacitor
#@GROUP@ monitor
kapacitor.source.verify() { task.verify.permissive; }
kapacitor.source() {
	source.go github.com/influxdata/kapacitor
	cd $GOPATH/src/github.com/influxdata/kapacitor
	#out.cmd dep ensure -vendor-only
}


kapacitor.build.verify() { task.verify.permissive; }
kapacitor.build() {
	set.env
	export CGO_ENABLED=0 GOOS=linux
	cd $GOPATH/src/github.com/influxdata/kapacitor
	out.cmd go build ./cmd/kapacitor
	out.cmd go build ./cmd/kapacitord
}

kapacitor.install() {
	install.init
	mkdir -p "$DIR_DEST/usr/bin/"
	cp $GOPATH/src/github.com/influxdata/kapacitor/kapacitord $GOPATH/src/github.com/influxdata/kapacitor/kapacitor "$DIR_DEST/usr/bin/"
}

kapacitor.config() {
	mkdir -p "$DIR_DEST/etc/kapacitor"
	cat >"$DIR_DEST/start.d/kapacitor" <<ENDF
KAPACITOR_HOSTNAME=kapacitor
exec /usr/bin/kapacitord
ENDF
}

kapacitor.deploy() {
	kube.claim "${CPREFIX}kapacitor" "${MARIA_CLAIM_SIZE:-"10Gi"}"
	VOLUMES=$(sed 's/^,//' <<<"$VOLUMES,$(json.volume.config "config" "kapacitor"),$(json.volume.claim kapacitor-data "${CPREFIX}kapacitor")")
	MOUNTS=$(sed 's/^,//' <<<"$MOUNTS,$(json.mount config "/etc/kapacitor"),$(json.mount kapacitor-data "/var/lib/kapacitor")")
	CNAME=${CNAME:-"kapacitor"}
	LINKS+=("$(json.link 9092)")
	CONTAINERS+=("$(json.container "${CPREFIX}kapacitor" "192.168.10.200:5000/$CNAME:latest" '"kapacitor"' "$MOUNTS" "$(json.port 9092)")")
	local content="$( json.file <<END
hostname = "kapacitor"
data_dir = "/var/lib/kapacitor"

[http]
  bind-address = ":9092"
  log-enabled = true
  write-tracing = false
  pprof-enabled = false
  https-enabled = false
  https-certificate = "/etc/ssl/kapacitor.pem"

[config-override]
  enabled = true

[logging]
  file = "STDOUT"
  level = "INFO"

[load]
  enabled = true
  dir = "/etc/kapacitor/load"

[replay]
  dir = "/var/lib/kapacitor/replay"

[task]
  dir = "/var/lib/kapacitor/tasks"
  snapshot-interval = "60s"

[storage]
  boltdb = "/var/lib/kapacitor/kapacitor.db"

[deadman]
  global = false
  threshold = 0.0
  interval = "10s"
  id = "node 'NODE_NAME' in task '{{ .TaskName }}'"
  message = "{{ .ID }} is {{ if eq .Level \"OK\" }}alive{{ else }}dead{{ end }}: {{ index .Fields \"collected\" | printf \"%0.3f\" }} points/INTERVAL."

[[influxdb]]
  enabled = true
  default = true
  name = "influxdb"
  urls = ["http://influx:8086"]
  username = ""
  password = ""
  timeout = 0
  #   ssl-ca = "/etc/kapacitor/ca.pem"
  #   ssl-cert = "/etc/kapacitor/cert.pem"
  #   ssl-key = "/etc/kapacitor/key.pem"
  insecure-skip-verify = false
  startup-timeout = "5m"
  disable-subscriptions = false
  subscription-mode = "cluster"
  subscription-protocol = "http"
  subscriptions-sync-interval = "1m0s"
  udp-buffer = 1000
  udp-read-buffer = 0

  [influxdb.subscriptions]
  [influxdb.excluded-subscriptions]

[kubernetes]
  enabled = true
  in-cluster = true
  resource = "pod"

[smtp]
  enabled = false
  host = "localhost"
  port = 25
  username = ""
  password = ""
  # From address for outgoing mail
  from = ""
  # List of default To addresses.
  # to = ["oncall@example.com"]

  # Skip TLS certificate verify when connecting to SMTP server
  no-verify = false
  # Close idle connections after timeout
  idle-timeout = "30s"

  # If true the all alerts will be sent via Email
  # without explicitly marking them in the TICKscript.
  global = false
  # Only applies if global is true.
  # Sets all alerts in state-changes-only mode,
  # meaning alerts will only be sent if the alert state changes.
  state-changes-only = false

[snmptrap]
  enabled = false

[opsgenie]
  enabled = false

[victorops]
  enabled = false

[pagerduty]
  enabled = false

[pushover]
  enabled = false

[slack]
  enabled = false

[telegram]
  enabled = false

[hipchat]
  enabled = false

[alerta]
  enabled = false

[sensu]
  enabled = false

[reporting]
  enabled = false

[stats]
  enabled = true
  stats-interval = "10s"
  database = "_kapacitor"
  retention-policy= "autogen"

[talk]
  enabled = false

[[swarm]]
  enabled = false

[collectd]
  enabled = false

[opentsdb]
  enabled = false

[[scraper]]
  enabled = false
  name = "myscraper"
  # Specify the id of a discoverer service specified below
  discoverer-id = ""
  # Specify the type of discoverer service being used.
  discoverer-service = ""
  db = "prometheus_raw"
  rp = "autogen"
  type = "prometheus"
  scheme = "http"
  metrics-path = "/metrics"
  scrape-interval = "1m0s"
  scrape-timeout = "10s"
  username = ""
  password = ""
  bearer-token = ""
  ssl-ca = ""
  ssl-cert = ""
  ssl-key = ""
  ssl-server-name = ""
  insecure-skip-verify = false

[[azure]]
  enabled = false
  id = "myazure"
  port = 80
  subscription-id = ""
  tenant-id = ""
  client-id = ""
  client-secret = ""
  refresh-interval = "5m0s"

[[consul]]
  enabled = false
  id = "myconsul"
  address = "127.0.0.1:8500"
  token = ""
  datacenter = ""
  tag-separator = ","
  scheme = "http"
  username = ""
  password = ""
  ssl-ca = ""
  ssl-cert = ""
  ssl-key = ""
  ssl-server-name = ""
  insecure-skip-verify = false

[[dns]]
  enabled = false
  id = "mydns"
  refresh-interval = "30s"
  type = "SRV"
  port = 80

[[ec2]]
  enabled = false
  id = "myec2"
  region = "us-east-1"
  access-key = ""
  secret-key = ""
  profile = ""
  refresh-interval = "1m0s"
  port = 80

[[file-discovery]]
  enabled = false
  id = "myfile"
  refresh-interval = "5m0s"
  files = []

[[gce]]
  enabled = false
  id = "mygce"
  project = ""
  zone = ""
  filter = ""
  refresh-interval = "1m0s"
  port = 80
  tag-separator = ","

[[marathon]]
  enabled = false
  id = "mymarathon"
  timeout = "30s"
  refresh-interval = "30s"
  bearer-token = ""
  ssl-ca = ""
  ssl-cert = ""
  ssl-key = ""
  ssl-server-name = ""
  insecure-skip-verify = false

[[nerve]]
  enabled = false
  id = "mynerve"
  timeout = "10s"

[[serverset]]
  enabled = false
  id = "myserverset"
  timeout = "10s"

[[static-discovery]]
  enabled = false
  id = "mystatic"
  targets = ["localhost:9100"]
  [static.labels]
    region = "us-east-1"

[[triton]]
  enabled = false
  id = "mytriton"
  account = ""
  dns-suffix = ""
  endpoint = ""
  port = 9163
  refresh-interval = "1m0s"
  version = 1
  ssl-ca = ""
  ssl-cert = ""
  ssl-key = ""
  ssl-server-name = ""
  insecure-skip-verify = false
END
)"
	kube.configmap "kapacitor" "$(json.label "kapacitor.conf" "$content")" "$(json.label "run" "$CNAME")"
	deploy.default
}


step.add.source  kapacitor.source	"Get the kapacitor sources from git"
step.add.build   kapacitor.build	"Build the kapacitor sources"
step.add.install kapacitor.install	"Install kapacitor"
step.add.install kapacitor.config	"Configure kapacitor"
step.add.deploy  kapacitor.deploy  	"Deploy kapacitorDB to kubernetes"
