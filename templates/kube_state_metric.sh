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
#@DESC@  kube-state-metric
#@GROUP@ sys
#ksm.sources.verify() { task.verify.permissive; }
ksm.source() {
	source.go k8s.io/kube-state-metrics
}

ksm.build.verify() { task.verify.permissive; }
ksm.build() {
	set.env
	mkdir -p $GOPATH/bin/linux_$GOARCH/
	export CGO_ENABLED=0 GOOS=linux
	build.go k8s.io/kube-state-metrics -a -ldflags \'-extldflags "-static"\' -o $GOPATH/bin/linux_$GOARCH/kube-state-metric
}

ksm.install() {
	install.init
	install.binaries "/bin/ls"
	install.go
}

ksm.config() {
	cat >"$DIR_DEST/start.d/ksm" <<ENDF
exec /usr/bin/kube-state-metric --port=8080 --telemetry-port=8081
ENDF
}
step.add.source  ksm.source	"Get the kube-state-metric sources from google"
step.add.build   ksm.build	"Build the kube-state-metric sources"
step.add.install ksm.install	"Install kube-state-metric"
step.add.install ksm.config	"Configure kube-state-metric"
