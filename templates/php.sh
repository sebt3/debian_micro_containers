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
#@DESC@  php
#@GROUP@ core
php.prepare.verify() { task.verify.permissive; }
php.prepare() {
	rootfs.install "$ARCH" libapparmor1 libargon2-0 libedit2 libsodium23 libicu60
	prepare.dir "$TMPLT"
	prepare.get.packages php7.2-cli php7.2-common php7.2-fpm php7.2-json php7.2-mysql php7.2-readline php7.2-opcache
}

php.install() {
	install.init
	install.packages
}
php.config() {
	local i b
	mkdir -p "$DIR_DEST/run/php" "$DIR_DEST/tmp" "$DIR_DEST/var/lib/php/sessions" "$DIR_DEST/start.d"
	chown www-data:www-data "$DIR_DEST/var/lib/php/sessions" "$DIR_DEST/run/php" "$DIR_DEST/tmp"
	for i in "$DIR_DEST/usr/share/"php*/*/*ini;do
		b=$(basename $i)
		case "$b" in 
		mysqlnd.ini|opcache.ini|pdo.ini)
			cp $i "$DIR_DEST/etc/php/7.2/fpm/conf.d/10-$b";;
		*)	cp $i "$DIR_DEST/etc/php/7.2/fpm/conf.d/20-$b";;
		esac
		
	done
	cat >"$DIR_DEST/start.d/php" <<ENDF
exec /usr/sbin/php-fpm7.2 --nodaemonize --fpm-config /etc/php/7.2/fpm/php-fpm.conf
ENDF
}
step.add.build   php.prepare		"Prepare the php install"
step.add.install php.install		"Install php"
step.add.install php.config		"Configure php"
