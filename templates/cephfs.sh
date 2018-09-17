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
#@DESC@  cephfs-provisioner
#@GROUP@ sys
cephfs.source() {
	source.go github.com/kubernetes-incubator/external-storage/ceph/cephfs
}


cephfs.packages.verify() { task.verify.permissive; }
cephfs.packages() {
	prepare.dir "$TMPLT" # libicu60
	prepare.get.packages python-rados libpython2.7-dev python2 python2.7 python2-minimal python2.7-minimal libpython2.7-minimal libpython2-stdlib libpython2.7-stdlib ceph-base ceph-common libcephfs1 python-cephfs libblkid1 libboost-iostreams1.62.0 libboost-program-options1.62.0 libboost-random1.62.0 libboost-regex1.62.0 libboost-system1.62.0 libboost-thread1.62.0 libdw1 libkeyutils1 libfcgi0ldbl libpopt0 libnspr4 libnss3 librados2 librbd1 libstdc++6 libudev1 libuuid1 zlib1g libradosstriper1 librgw2 libbabeltrace-ctf1 libbabeltrace1 tzdata curl openssl ca-certificates
}

cephfs.build.verify() { task.verify.permissive; }
cephfs.build() {
	set.env
	mkdir -p $GOPATH/bin/linux_$GOARCH/
	export CGO_ENABLED=0 GOOS=linux
	build.go github.com/kubernetes-incubator/external-storage/ceph/cephfs -a -ldflags \'-extldflags "-static"\' -o $GOPATH/bin/linux_$GOARCH/cephfs-provisioner
}

cephfs.install() {
	install.init
	install.packages
	install.su
	install.binaries "/bin/ls"
	install.binaries "/usr/bin/env"
	install.sslcerts
	install.go
	ln -sf python2.7 "$DIR_DEST/usr/bin/python"
	mkdir -p "$DIR_DEST/usr/local/bin"
	cp "$DIR_SOURCE/src/github.com/kubernetes-incubator/external-storage/ceph/cephfs/cephfs_provisioner/cephfs_provisioner.py" "$DIR_DEST/usr/local/bin/cephfs_provisioner"
	chmod -v o+x "$DIR_DEST/usr/local/bin/cephfs_provisioner"
	sed -i 's/, namespace_isolated=not self.ceph_namespace_isolation_disabled//'  "$DIR_DEST/usr/local/bin/cephfs_provisioner"
}

cephfs.config() {
	cat >"$DIR_DEST/start.d/cephfs" <<ENDF
exec /usr/bin/cephfs-provisioner  -logtostderr
ENDF
}
step.add.source  cephfs.source		"Get the cephfs sources from git"
step.add.build   cephfs.packages	"Get packages dependencies for cephfs"
step.add.build   cephfs.build		"Build the cephfs sources"
step.add.install cephfs.install		"Install cephfs"
step.add.install cephfs.config		"Configure cephfs"
