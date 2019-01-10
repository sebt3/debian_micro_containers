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
	rootfs.update
	rootfs.upgrade
	rootfs.install "$ARCH" libaio1 libjemalloc1 libreadline5 iproute2
	prepare.get.packages mariadb-client-10.1 mariadb-client-core-10.1 mariadb-common mariadb-server-10.1 mariadb-server-core-10.1 libmariadbclient18 galera-3 galera-arbitrator-3 libboost-program-options1.62.0
}

maria.install() {
	install.init
	install.packages
	install.binaries "/usr/bin/test" "/bin/cat" "/bin/sed" "/bin/hostname" "/bin/chown" "/bin/mkdir" "/bin/chmod" "/lib/aarch64-linux-gnu/libc.so.6" "/etc/ld.so.cache" "/etc/host.conf" "/usr/bin/nslookup" "/usr/bin/mawk" "/usr/bin/dirname" "/bin/ip" "/usr/bin/tail" "/bin/date" "/usr/bin/cut" "/usr/bin/which" "/bin/grep"
}
maria.config() {
	local DIRS=("$DIR_DEST/var/run/mysqld" "$DIR_DEST/var/log/mysql" "$DIR_DEST/var/lib/mysql") token=$(uuidgen |sed 's/-.*//g')
	mkdir -p "${DIRS[@]}" "$DIR_DEST/start.d" "$DIR_DEST/etc/mysql/conf.d"
	chown -R 118:126  "${DIRS[@]}"
	#mknod -m 644 "$DIR_DEST/dev/urandom" c 1 9
	ln -s mawk "$DIR_DEST/usr/bin/awk"
	rm -f "$DIR_DEST/var/log/mysql/error.log"
	ln -sf /dev/stderr "$DIR_DEST/var/log/mysql/error.log"
	echo "mysql:x:118:126:MySQL Server,,,:/nonexistent:/bin/false">>"$DIR_DEST/etc/passwd"
	cat >"$DIR_DEST/etc/mysql/my.cnf"<<ENDF
[client-server]
!includedir /etc/mysql/conf.d/
!includedir /etc/mysql/mariadb.conf.d/
ENDF
	cat >"$DIR_DEST/etc/mysql/mariadb.conf.d/80-galera.cnf"<<ENDF
[mysqld]
#mysql settings
binlog_format=ROW
default-storage-engine=innodb
innodb_autoinc_lock_mode=2
query_cache_size=0
query_cache_type=0
innodb_flush_log_at_trx_commit=0
innodb_buffer_pool_size=256M
bind-address=0.0.0.0

#Galera settings
wsrep_provider=/usr/lib/libgalera_smm.so
#SSL for Galera
#wsrep_provider_options="socket.ssl_key=/etc/mysql/ssl/server-key.pem;socket.ssl_cert=/etc/mysql/ssl/server-cert.pem;socket.ssl_ca=/etc/mysql/ssl/ca-cert.pem"
wsrep_cluster_name="galera-cluster"
#nwsrep_cluster_address="gcomm://mariadb-repl"
wsrep_sst_method=mysqldump
wsrep_on=ON
wsrep_sst_auth=repuser:$token
ENDF
	cat >"$DIR_DEST/init.sql"<<ENDF
create user 'repuser'@'localhost' identified by '$token';
GRANT ALL ON *.* TO 'repuser'@'%' identified by '$token';
FLUSH PRIVILEGES ;
ENDF
	cat >"$DIR_DEST/start.d/mariadb" <<ENDF
if ! [[ \$(cat /etc/hostname) =~ -([0-9]+)$ ]];then 
	echo "ERROR: Not part of a replicaSet; quitting"
	exit 10
fi
ID=\${BASH_REMATCH[1]}
#DOM=\$(hostname -d)
ADD=""
if [ ! -f /var/lib/mysql/ibdata1 ]; then
	bash /usr/bin/mysql_install_db --user=mysql --force
	[ \$ID -eq 0 ] && ADD="--wsrep-new-cluster"
	echo "==================== FINISHED install_db ====================="
fi
CLU=\$(nslookup mariadb-repl|mawk 'BEGIN{P=0;R=""}/^Name:/{P=1}P==1&&/^Address:/{R=R","\$2}END{sub(/,/,"gcomm://",R);print R}')
if [ -z "\$CLU" ];then
	CLU="gcomm://\$(hostname)"
	[ \$ID -eq 0 ] && ADD="--wsrep-new-cluster"
	[ \$ID -ne 0 ] && echo "=== This is going to fail... probably ==="
fi
echo "===== CLU=\$CLU ===="
echo -e "[mysqld]\nwsrep_cluster_address=\"\$CLU\"">/etc/mysql/mariadb.conf.d/81-galera.cnf

exec /usr/sbin/mysqld -u mysql --bind-address=0.0.0.0 --init-file=/init.sql \$ADD
ENDF
}



maria.deploy() {
	CNAME=${CNAME:-"mariadb"}
	CPREFIX=${CPREFIX:-"mariadb-"}
	#link.add 	data			3306
	#store.claim	"${CPREFIX}data"	"/var/lib/mysql" "${MARIA_CLAIM_SIZE:-"10Gi"}"
	#container.add	"${CPREFIX}mariadb"	"${REPODOCKER}/$CNAME:latest" '"mariadb"'
	#deploy.default
	kube.apply <<ENDF
apiVersion: apps/v1beta1
kind: StatefulSet
metadata:
  name: mariadb
  namespace: $NAMESPACE
spec:
  serviceName: "mariadb"
  replicas: 3
  template:
    metadata:
      labels:
        app: mariadb
    spec:
      terminationGracePeriodSeconds: 10
      containers:
      - name: mariadb
        image: ${REPODOCKER}/$CNAME:latest
        imagePullPolicy: Always
        args: ["mariadb"]
        ports:
        - containerPort: 3306
          name: mariadb
        volumeMounts:
        - name: mariadb
          mountPath: /var/lib/mysql
        readinessProbe:
          exec:
            command: ["mysql", "-e", "SELECT 1"]
          initialDelaySeconds: 15
          timeoutSeconds: 1
  volumeClaimTemplates:
  - metadata:
      name: mariadb
      namespace: $NAMESPACE
      annotations:
        volume.beta.kubernetes.io/storage-class: rbd
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: ${MARIA_CLAIM_SIZE:-"10Gi"}
---
apiVersion: v1
kind: Service
metadata:
  name: mariadb-repl
  namespace: $NAMESPACE
  labels:
    app: mariadb
spec:
  ports:
  - port: 3306
    name: mariadb
  clusterIP: None
  selector:
    app: mariadb
  publishNotReadyAddresses: true
---
apiVersion: v1
kind: Service
metadata:
  name: mariadb
  namespace: $NAMESPACE
  labels:
    app: mariadb
spec:
  ports:
  - port: 3306
    name: mariadb
  selector:
    app: mariadb
ENDF
}

#step.add.source
step.add.build   maria.prepare "Prepare mariaDB packages"
step.add.install maria.install "Install mariaDB packages"
step.add.install maria.config  "Configure mariaDB"
step.add.deploy  maria.deploy  "Deploy mariaDB to kubernetes"

maria() {
	kube.exec "$(kube.get.pod maria)" -t -i mysql
}
