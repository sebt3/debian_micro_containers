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
#@DESC@  rbd-provisioner
#@GROUP@ sys
rbd.source() {
	source.go github.com/kubernetes-incubator/external-storage/ceph/rbd/cmd/rbd-provisioner
}


rbd.packages.verify() { task.verify.permissive; }
rbd.packages() {
	prepare.dir "$TMPLT" # libicu60
	prepare.get.packages  ceph-base ceph-common libblkid1 libboost-iostreams1.62.0 libboost-program-options1.62.0 libboost-random1.62.0 libboost-regex1.62.0 libboost-system1.62.0 libboost-thread1.62.0 libdw1 libkeyutils1 libfcgi0ldbl libpopt0 libnspr4 libnss3 librados2 librbd1 libstdc++6 libudev1 libuuid1 zlib1g libradosstriper1 librgw2 libbabeltrace-ctf1 libbabeltrace1 tzdata curl openssl ca-certificates
}

rbd.build.verify() { task.verify.permissive; }
rbd.build() {
	set.env
	mkdir -p $GOPATH/bin/linux_$GOARCH/
	export CGO_ENABLED=0 GOOS=linux
	build.go github.com/kubernetes-incubator/external-storage/ceph/rbd/cmd/rbd-provisioner -a -ldflags \'-extldflags "-static"\' -o $GOPATH/bin/linux_$GOARCH/rbd-provisioner
}

rbd.install() {
	install.init
	install.packages
	install.su
	install.binaries "/bin/ls"
	install.sslcerts
	install.go
}

rbd.config() {
	cat >"$DIR_DEST/start.d/rbd" <<ENDF
exec /usr/bin/rbd-provisioner
ENDF
}
step.add.source  rbd.source	"Get the rbd sources from git"
step.add.build   rbd.packages	"Get packages dependencies for rbd"
step.add.build   rbd.build	"Build the rbd sources"
step.add.install rbd.install	"Install rbd"
step.add.install rbd.config	"Configure rbd"
