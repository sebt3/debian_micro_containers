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
#@DESC@  mongodb
#@GROUP@ base
# TODO: make a mongo compass container https://docs.mongodb.com/compass/current/
mongo.prepare.verify() { task.verify.permissive; }
mongo.prepare() {
	prepare.dir "$TMPLT"
	#rootfs.install "$ARCH" libaio1 libjemalloc1 libreadline5
	prepare.get.packages mongodb-server-core mongodb-server mongodb-clients libboost-chrono1.62.0 libboost-program-options1.62.0 libboost-regex1.62.0 libboost-thread1.62.0 libsnappy1v5 libstemmer0d libyaml-cpp0.5v5 libgoogle-perftools4
}

mongo.install() {
	install.init
	install.packages
	#install.binaries "/usr/bin/test" "/bin/cat" "/bin/sed" "/bin/hostname" "/bin/chown" "/bin/mkdir" "/bin/chmod"
}
mongo.config() {
	#local DIRS=("$DIR_DEST/var/run/mysqld" "$DIR_DEST/var/log/mysql" "$DIR_DEST/var/lib/mysql")
	#mkdir -p "${DIRS[@]}" "$DIR_DEST/start.d"
	#chown -R 118:126  "${DIRS[@]}"
	#rm -f "$DIR_DEST/var/log/mysql/error.log"
	#ln -sf /dev/stderr "$DIR_DEST/var/log/mysql/error.log"
	#echo "mysql:x:118:126:MySQL Server,,,:/nonexistent:/bin/false">>"$DIR_DEST/etc/passwd"
	mkdir -p "$DIR_DEST/run/mongodb"
	sed -i 's/bind_ip = .*/bind_ip = 0.0.0.0/;/logpath/d' "$DIR_DEST/etc/mongodb.conf"
	cat >"$DIR_DEST/start.d/mongodb" <<ENDF
[ -f /etc/default/mongodb ] && . /etc/default/mongodb
CONF=/etc/mongodb.conf
SOCKETPATH=/run/mongodb
exec /usr/bin/mongod --unixSocketPrefix=\${SOCKETPATH} --config \${CONF} \$DAEMON_OPTS
ENDF
}

mongo.deploy() {
	CNAME=${CNAME:-"mongo"}
	CPREFIX=${CPREFIX:-"mongo-"}
	link.add	data			27017
	store.claim	"${CPREFIX}data"	"/var/lib/mongodb" "${MONGO_CLAIM_SIZE:-"10Gi"}"
	container.add	"${CPREFIX}mongodb"	"${REPODOCKER}/$CNAME:latest" '"mongodb"'
	deploy.default
}

#step.add.source
step.add.build   mongo.prepare "Prepare mongoDB packages"
step.add.install mongo.install "Install mongoDB packages"
step.add.install mongo.config  "Configure mongoDB"
step.add.deploy  mongo.deploy  "Deploy mongoDB to kubernetes"

