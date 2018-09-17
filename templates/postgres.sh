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
#@DESC@  postgres
#@GROUP@ base
pg.prepare.verify() { task.verify.permissive; }
pg.prepare() {
	rootfs.install "$ARCH" libgssapi-krb5-2 libsasl2-2 less
	prepare.dir "$TMPLT" 
	prepare.get.packages postgresql-10 postgresql-client-10 postgresql-common libpq5  libldap-2.4-2 tzdata postgresql-client-common
}

pg.install() {
	install.init
	install.packages
	install.su
	install.binaries "/bin/chown" "/bin/mkdir"  "/bin/less"
	rm -rf "$DIR_DEST/usr/share/postgresql/10/man"
	mkdir -p "$DIR_DEST/var/run/postgresql"
	ln -s "/bin/less" "$DIR_DEST/bin/pager"
	# /mnt/virtual/containers/arm64/postgres/usr/lib/postgresql/10/bin/postgres
}
pg.config() {
	echo "postgres:x:104:">>"$DIR_DEST/etc/group"
	echo "postgres:x:102:104:PostgreSQL administrator,,,:/var/lib/postgresql:/bin/bash">>"$DIR_DEST/etc/passwd"
	local f
	for f in createdb dropdb psql createuser dropuser;do 
		ln -sf "/usr/lib/postgresql/10/bin/$f"  "$DIR_DEST/usr/bin/$f"
	done
	cat >"$DIR_DEST/start.d/postgres" <<ENDF
mkdir -p /var/lib/postgresql/data
chown -R postgres:postgres /var/lib/postgresql/data /var/run/postgresql
if [ ! -d /var/lib/postgresql/data/pg_commit_ts ];then
	su - postgres -c "/usr/lib/postgresql/10/bin/initdb -D /var/lib/postgresql/data --auth-local peer --auth-host md5 --no-locale --encoding=UTF8"
fi
exec su - postgres -c "/usr/lib/postgresql/10/bin/postgres -h 0.0.0.0 -D /var/lib/postgresql/data"
ENDF
}

pg.deploy() {
	kube.claim "${CPREFIX}postgres" "${PG_CLAIM_SIZE:-"10Gi"}"
	VOLUMES=$(sed 's/^,//' <<<"$VOLUMES,$(json.volume.claim postgres-data "${CPREFIX}postgres")")
	MOUNTS=$(sed 's/^,//' <<<"$MOUNTS,$(json.mount postgres-data "/var/lib/postgresql")")
	CNAME=${CNAME:-"postgres"}
	LINKS+=("$(json.link 5432)")
	CONTAINERS+=("$(json.container "${CPREFIX}postgres" "192.168.10.200:5000/$CNAME:latest" '"postgres"' "$MOUNTS" "$(json.port 5432)")")
	deploy.default
}

#step.add.source
step.add.build   pg.prepare "Get packages for postgres"
step.add.install pg.install "Install postgres packages"
step.add.install pg.config  "Configure postgres"
step.add.deploy  pg.deploy  "Deploy postgres to kubernetes"

