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
#@DESC@  chartmuseum
#@GROUP@ apps
#cm.sources.verify() { task.verify.permissive; }
cm.source() {
	out.cmd go get -u github.com/helm/chartmuseum
	return 0
}
cm.deps() {
	cd "$DIR_SOURCE/src/github.com/helm/chartmuseum"
	export GO111MODULE=on
	out.cmd go mod download
	out.cmd go mod vendor
}

cm.build.verify() { task.verify.permissive; }
cm.build() {
	set.env
	cd $DIR_SOURCE/src/github.com/helm/chartmuseum
	mkdir -p "$DIR_BUILD/bin"
	local V=$(awk -F= '/^VERSION=/{print $2}' Makefile)
	local R=$(git rev-parse --short HEAD)
	export CGO_ENABLED=0 GO111MODULE=on
	out.cmd "go build -mod=vendor -v --ldflags='-w -X main.Version=$V -X main.Revision=$R' -o '$DIR_BUILD/bin/chartmuseum' cmd/chartmuseum/main.go"
}

cm.install() {
	install.init
	cp -Rapf "$DIR_BUILD/bin" "$DIR_DEST/bin"
}

cm.config() {
	cat >"$DIR_DEST/start.d/cm" <<ENDF
exec /bin/chartmuseum --port=80 --storage-local-rootdir=/storage --storage="local" 
ENDF
}


cm.deploy() {
	CNAME=${CNAME:-"chartmuseum"}
	CPREFIX=${CPREFIX:-"chartmuseum-"}
	link.add	www			80
	store.claim.many ${CPREFIX}data 	"/storage" "${CM_CLAIM_SIZE:-"10Gi"}"
	container.add	"${CPREFIX}$CNAME"	"${REPODOCKER}/$CNAME:latest"  '"cm"' #"$(json.res "100m" "100Mi")"
	deploy.public

#TODO: ajouter:
#         livenessProbe:
#           httpGet:
#             path: /health
#             port: http
#           failureThreshold: 3
#           initialDelaySeconds: 5
#           periodSeconds: 10
#           successThreshold: 1
#           timeoutSeconds: 1
#           
#         readinessProbe:
#           httpGet:
#             path: /health
#             port: http
#           failureThreshold: 3
#           initialDelaySeconds: 5
#           periodSeconds: 10
#           successThreshold: 1
#           timeoutSeconds: 1

}

cm.addhelm() {
	IP=$(net.run "$MASTER" kubectl get svc chartmuseum|awk '$1=="chartmuseum"{print $3}')
	out.lvl CMD helm repo add maison "http://$IP/"
	net.run "$MASTER" helm repo add maison "http://$IP/"
}

step.add.source  cm.source	"Get the chartmuseum sources"
step.add.source  cm.deps	"Get the chartmuseum dependencies"
step.add.build   cm.build	"Build the chartmuseum sources"
step.add.install cm.install	"Install chartmuseum"
step.add.install cm.config	"Configure chartmuseum"
step.add.deploy  cm.deploy  	"Deploy chartmuseum to kubernetes"
step.add.deploy  cm.addhelm  	"Add chartmuseum to helm"
