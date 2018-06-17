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
#@DESC@  nginx
#@GROUP@ core
nginx.prepare.verify() { task.verify.permissive; }
nginx.prepare() {
	prepare.dir "$TMPLT"
	prepare.get.packages libnginx-mod-http-upstream-fair libnginx-mod-http-xslt-filter libnginx-mod-http-image-filter libnginx-mod-http-subs-filter libnginx-mod-http-geoip libnginx-mod-http-echo libnginx-mod-http-dav-ext libnginx-mod-http-auth-pam libnginx-mod-mail libnginx-mod-stream nginx-common nginx-full
}

nginx.install() {
	install.init
	install.packages
}
nginx.config() {
	rm -f "$DIR_DEST/etc/nginx/sites-enabled/default"
	rm -f "$DIR_DEST/var/log/nginx/error.log"
	ln -sf /dev/stderr "$DIR_DEST/var/log/nginx/error.log"
	cat >"$DIR_DEST/start.d/nginx" <<ENDF
exec /usr/sbin/nginx -g 'daemon off; master_process on;'
ENDF
}
step.add.build   nginx.prepare		"Prepare the nginx install"
step.add.install nginx.install		"Install nginx"
step.add.install nginx.config		"Configure nginx"

