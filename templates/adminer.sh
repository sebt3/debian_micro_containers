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
#@DESC@  adminer
#@GROUP@ app
adminer.sources.verify() { task.verify.permissive; }
adminer.sources() {
	source.git adminer https://github.com/vrana/adminer.git
}

adminer.build() {
	cd "$DIR_SOURCE/adminer"
	./compile.php editor mysql en 2>&1|grep -v "No such file or directory"
	./compile.php mysql en 2>&1|grep -v "No such file or directory"
}


adminer.install() {
	install.init
	install.container php
	install.container nginx
	local i
	mkdir -p "$DIR_DEST/var/www-data/editor"
	cp "$DIR_SOURCE/adminer/adminer-mysql-en.php" "$DIR_DEST/var/www-data/index.php"
	cp "$DIR_SOURCE/adminer/editor-mysql-en.php" "$DIR_DEST/var/www-data/editor/index.php"
	for i in / /editor/; do
		cp "$DIR_SOURCE/adminer/designs/rmsoft/adminer.css" "$DIR_DEST/var/www-data${i}adminer.css"
	done
}
adminer.config() {
	cat >"$DIR_DEST/etc/nginx/sites-available/php" <<ENDCFG
server {
        listen 80 default_server;
        listen [::]:80 default_server;
        root /var/www-data;
        index index.php index.html index.htm;
        server_name _;
        location / {
		try_files \$uri \$uri/ =404;
	}
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/run/php/php7.2-fpm.sock;
	}
	location ~ /\.ht {
		deny all;
	}
}
ENDCFG
	ln -sf ../sites-available/php "$DIR_DEST/etc/nginx/sites-enabled/php"
}


adminer.deploy() {
	CNAME=${CNAME:-"adminer"}
	CPREFIX=${CPREFIX:-"adminer-"}
	IP=10.110.0.121
	MOUNTS="$(json.mount php-socket "/run/php"),$(json.mount nginx-log "/var/log/nginx")"
	VOLUMES="$(json.volume.empty php-socket),$(json.volume.empty nginx-log)"
	LINKS+=("$(json.link 80)")
	#fluent
	CONTAINERS+=("$(json.container "${CPREFIX}nginx" "localhost:5000/$CNAME:latest" '"nginx"' "$MOUNTS" "$(json.port 80)")")
	CONTAINERS+=("$(json.container "${CPREFIX}php" "localhost:5000/$CNAME:latest"  '"php"' "$MOUNTS")")
	deploy.default
}

step.add.source  adminer.sources	"Get adminer sources"
step.add.build   adminer.build		"Build adminer"
step.add.install adminer.install	"Install adminer"
step.add.install adminer.config		"Configure nginx for adminer"
step.add.deploy  adminer.deploy		"Deploy adminer to kubernetes"

