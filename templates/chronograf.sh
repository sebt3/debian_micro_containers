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
#@DESC@  chronograf
#@GROUP@ monitor
chronograf.source.verify() { task.verify.permissive; }
chronograf.source() {
	source.go github.com/kevinburke/go-bindata/...
	source.go github.com/influxdata/chronograf
	cd $GOPATH/src/github.com/influxdata/chronograf
	git checkout 1.6.2
}


chronograf.build.verify() { task.verify.permissive; }
chronograf.build() {
	set.env
	export CGO_ENABLED=0 GOOS=linux
	cd $GOPATH/src/github.com/influxdata/chronograf
	make
}

chronograf.install() {
	install.init
	mkdir -p "$DIR_DEST/usr/bin/"
	cp $GOPATH/src/github.com/influxdata/chronograf/chronoctl $GOPATH/src/github.com/influxdata/chronograf/chronograf "$DIR_DEST/usr/bin/"
}

chronograf.config() {
	mkdir -p "$DIR_DEST/etc/chronograf"
	cat >"$DIR_DEST/start.d/chronograf" <<ENDF
PORT=80
INFLUXDB_URL=http://influx:8086
KAPACITOR_URL=http://kapacitor:9092
BOLT_PATH=/var/run/chronograf/chronograf.db
export PORT INFLUXDB_URL KAPACITOR_URL BOLT_PATH
exec /usr/bin/chronograf -r
ENDF
}

chronograf.deploy() {
	CNAME=${CNAME:-"chronograf"}
	link.add www 80
	store.claim chronograf-data "/var/run/chronograf" "${CPREFIX}${CNAME}" "10Gi"
	container.add "${CPREFIX}${CNAME}" "${REPODOCKER}/$CNAME:latest" '"chronograf"'
	deploy.public
}


step.add.source  chronograf.source	"Get the chronograf sources from git"
step.add.build   chronograf.build	"Build the chronograf sources"
step.add.install chronograf.install	"Install chronograf"
step.add.install chronograf.config	"Configure chronograf"
step.add.deploy  chronograf.deploy  	"Deploy chronografDB to kubernetes"
