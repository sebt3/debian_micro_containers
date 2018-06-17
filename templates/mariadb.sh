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
#@DESC@  mariadb
#@GROUP@ base
maria.prepare.verify() { task.verify.permissive; }
maria.prepare() {
	prepare.dir "$TMPLT"
	rootfs.install "$ARCH" libaio1 libjemalloc1 libreadline5
	prepare.get.packages mariadb-client-10.1 mariadb-client-core-10.1 mariadb-common mariadb-server-10.1 mariadb-server-core-10.1 libmariadbclient18
}

maria.install() {
	install.init
	install.packages
	install.binaries "/usr/bin/test" "/bin/cat" "/bin/sed" "/bin/hostname" "/bin/chown" "/bin/mkdir" "/bin/chmod"
}
maria.config() {
	local DIRS=("$DIR_DEST/var/run/mysqld" "$DIR_DEST/var/log/mysql" "$DIR_DEST/var/lib/mysql")
	mkdir -p "${DIRS[@]}" "$DIR_DEST/start.d"
	chown -R 118:126  "${DIRS[@]}"
	rm -f "$DIR_DEST/var/log/mysql/error.log"
	ln -sf /dev/stderr "$DIR_DEST/var/log/mysql/error.log"
	echo "mysql:x:118:126:MySQL Server,,,:/nonexistent:/bin/false">>"$DIR_DEST/etc/passwd"
	cat >"$DIR_DEST/start.d/mariadb" <<ENDF
if [ ! -f /var/lib/mysql/ibdata1 ]; then
	bash /usr/bin/mysql_install_db --user=mysql --force
fi
exec /usr/sbin/mysqld -u mysql --bind-address=0.0.0.0
ENDF
}

maria.deploy() {
	CNAME=${CNAME:-"mariadb"}
	IP=10.110.0.110
	MOUNTS=$(sed 's/^,//' <<<"$MOUNTS,$(json.mount mysql-data "/var/lib/mysql")")
	VOLUMES=$(sed 's/^,//' <<<"$VOLUMES,$(json.volume.host mysql-data /opt/mysql)")
	LINKS+=("$(json.link 3306)")
	CONTAINERS+=("$(json.container "${CPREFIX}mariadb" "localhost:5000/$CNAME:latest" '"mariadb"' "$MOUNTS" "$(json.port 3306)")")
	deploy.default
}

#step.add.source
step.add.build   maria.prepare "Prepare packages"
step.add.install maria.install "Install packages"
step.add.install maria.config  "Configure"
step.add.deploy  maria.deploy  "Deploy to kubernetes"

maria() {
	kube.exec "$(kube.get.pod maria)" -t -i mysql
}
