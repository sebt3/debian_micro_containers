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
#@DESC@  samba AD DC
#@GROUP@ app

BASE=buster
samba.empty() {
	install.empty
}

samba.install() {
	local r
	install.install samba samba-dsdb-modules samba-vfs-modules libcephfs1 glusterfs-common
	r=$?
	rm -f "$DIR_DEST/etc/samba/smb.conf"
	ln -sf /var/lib/samba/config/smb.conf "$DIR_DEST/etc/samba/smb.conf"
	return $r
}

samba.config() {
	cat >"$DIR_DEST/start.d/samba" <<ENDF
if [ ! -f /var/lib/samba/config/smb.conf ] || [ ! -f /var/lib/samba/private/krb5.conf ];then
	echo "Setting up Samba"
	mkdir -p /var/lib/samba/config /var/lib/samba/private
	SAMBA_PASSWORD=\${SAMBA_PASSWORD:-'Passw0rd'}
	SAMBA_REALM=\${SAMBA_REALM:-'home.local'}
	SAMBA_DOMAIN=\${SAMBA_DOMAIN:-"\${SAMBA_REALM%%.*}"}
	/usr/bin/samba-tool domain provision --use-rfc2307 "--domain=\$SAMBA_DOMAIN" "--realm=\$SAMBA_REALM" --server-role=dc "--adminpass=\$SAMBA_PASSWORD" --dns-backend=SAMBA_INTERNAL
fi
cp /var/lib/samba/private/krb5.conf /etc
exec /usr/sbin/samba --foreground --no-process-group
ENDF
}

samba.deploy() {
	CNAME=${CNAME:-"samba"}
	CPREFIX=${CPREFIX:-"samba-"}
	link.add 	dns			53
	link.add 	kerberos		88
	link.add 	epm			135
	link.add 	netbios			139
	link.add 	ldap			389
	link.add 	smb			445
	link.add 	kpass			464
	link.add 	ldaps			636
	link.add 	catalog			3268
	link.add 	catalogs		3269
	store.claim	"${CPREFIX}data"	"/var/lib/samba" "${SAMBA_CLAIM_SIZE:-"50Gi"}"
	container.add.sys "${CPREFIX}samba"	"${REPODOCKER}/$CNAME:latest" '"samba"'
	deploy.public
}

step.add.build   samba.empty		"Cleanup the Samba layer"
step.add.install samba.install		"Install samba"
step.add.install samba.config		"Configure samba"
step.add.deploy  samba.deploy  		"Deploy Samba DC to kubernetes"

