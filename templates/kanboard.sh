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
#@DESC@  kanboard
#@GROUP@ app

BASE=buster
kanboard.empty() {
	install.empty
}

kanboard.sources.verify() { task.verify.permissive; }
kanboard.sources() {
	source.tar kanboard.tar.gz https://github.com/kanboard/kanboard/archive/v1.2.6.tar.gz
}

kanboard.php() {
	install.update
	install.install apache2 libapache2-mod-php7.2 php7.2-cli php7.2-mbstring php7.2-sqlite3 php7.2-opcache php7.2-json php7.2-mysql php7.2-pgsql php7.2-ldap php7.2-gd php7.2-xml
}

kanboard.install() {
	mkdir -p "$DIR_DEST/var/htdocs"
	cp -Rapf "$DIR_SOURCE/kanboard/"* "$DIR_DEST/var/htdocs"
	cp "$DIR_SOURCE/kanboard/.htaccess" "$DIR_DEST/var/htdocs"
}

kanboard.config() {
# TODO voir https://docs.kanboard.org/en/latest/admin_guide/config_file.html
	cat >"$DIR_DEST/var/htdocs/config.php"<<ENDF
<?php
define('LOG_DRIVER', 'stdout');
define('PLUGIN_INSTALLER', false);
define('DB_DRIVER', 'postgres');
define('DB_HOSTNAME', 'postgres');
define('DB_USERNAME', 'kanboard');
define('DB_PASSWORD', 'kanboard');
define('DB_NAME', 'kanboard');
define('ENABLE_URL_REWRITE', true);

ENDF
}
kanboard.apaconf() {
	cat >"$DIR_DEST/etc/apache2/sites-available/kanboard.conf" <<ENDC
<VirtualHost *:80>
        ServerName localhost
        ServerAdmin webmaster@localhost
        DocumentRoot "/var/htdocs"
        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined
        <Directory "/var/htdocs">
                AllowOverride All
                Require all granted
        </Directory>
</VirtualHost>
ENDC
	rm -f "$DIR_DEST/etc/apache2/sites-enabled/*"
	ln -s ../sites-available/kanboard.conf "$DIR_DEST/etc/apache2/sites-enabled/kanboard.conf"
	install.cmd a2dissite 000-default.conf
	install.cmd a2enmod rewrite
	ln -sf /proc/self/fd/1 "$DIR_DEST/var/log/apache2/error.log"
	cat >"$DIR_DEST/start.d/kanboard" <<ENDF
chown -R www-data:www-data /var/htdocs/data
. /etc/apache2/envvars
exec /usr/sbin/apache2  -DFOREGROUND
ENDF
	
}

kanboard.deploy() {
	CNAME=${CNAME:-"kanboard"}
	CPREFIX=${CPREFIX:-"kanboard-"}
	link.add	www			80
	store.claim.many ${CPREFIX}data 	"/var/htdocs/data" "${KANBOARD_CLAIM_SIZE:-"10Gi"}"
	container.add	"${CPREFIX}$CNAME"	"${REPODOCKER}/$CNAME:latest"  '"kanboard"'
	deploy.public
}

step.add.source  kanboard.sources	"Get kanboard sources"
step.add.build   kanboard.empty		"Prerpare the kanboard layer"
step.add.install kanboard.php		"Install php & apache2 for kanboard"
step.add.install kanboard.install	"Install kanboard"
step.add.install kanboard.config	"Configure kanboard"
step.add.install kanboard.apaconf	"Configure apache"
step.add.deploy  kanboard.deploy	"Deploy kanboard to kubernetes"


if false;then

su - postgres <<END
/usr/lib/postgresql/10/bin/createuser kanboard
/usr/lib/postgresql/10/bin/createdb kanboard
echo "alter user kanboard with encrypted password 'kanboard';"|/usr/lib/postgresql/10/bin/psql
echo "grant all privileges on database kanboard to kanboard;"|/usr/lib/postgresql/10/bin/psql
echo "host all all 0.0.0.0/0 md5">>/var/lib/postgresql/data/pg_hba.conf
echo "host all all ::/0 md5">>/var/lib/postgresql/data/pg_hba.conf
echo "SELECT pg_reload_conf();"|/usr/lib/postgresql/10/bin/psql
END
fi
