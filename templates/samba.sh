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
	install.update
	install.install samba samba-dsdb-modules samba-vfs-modules winbind dnsutils net-tools krb5-user krb5-config libpam-winbind libnss-winbind smbclient
}

samba.config() {
	cat >"$DIR_DEST/start.d/samba" <<ENDF
H=\${SMBHOST:-"ad"}
getip() {
	ifconfig eth0|awk '/inet/{print \$2}'
}
OLD=\$(getip)
EXT=\${SMBIP:-"192.168.9.240"}
REALM=\${SAMBA_REALM:-'home.local'}
cleanlist() {
	samba-tool dns query "\$EXT" "\$REALM" @ ALL -U administrator -P|awk -vOK="\$EXT" -vR="\$REALM" -vH="\$H" -vF="" '\$1~/Name=.*/{F=""}\$1=="Name=,"{F=R}\$1=="Name="H","{F=H}F!=""&&\$1=="A:"&&\$2!=OK{print F" "\$2}'
}
cleanup() {
	cleanlist|while read n ip;do
		echo "Removing \$ip from \$n"
		samba-tool dns delete "\$EXT" "\$REALM" "\$n" A "\$ip" -U administrator -P
	done
}
deleteme() {
	i=0
	while :;do
	sleep 60
	cleanup
	done
}
updateme() {
	sleep 10
	OLD=\$(getip)
	EXT=\${SMBIP:-"192.168.9.240"}
	REALM=\${SAMBA_REALM:-'home.local'}
	echo "Updating IP adress in the DNS"
	samba-tool dns update "\$OLD" "\$REALM" "\$H" A "\$OLD" "\$EXT" -U administrator -P
	samba-tool dns update "\$OLD" "\$REALM" "\$REALM" A "\$OLD" "\$EXT" -U administrator -P
	deleteme
}
upper() {
	tr '[:lower:]' '[:upper:]'
}
hostname \$H
export HOSTNAME=\$H
if [ ! -f /var/lib/samba/config/smb.conf ] || [ ! -f /var/lib/samba/private/krb5.conf ];then
	echo "Setting up Samba"
	mkdir -p /var/lib/samba/config /var/lib/samba/private /var/lib/samba/run /var/lib/samba/cache
	SAMBA_PASSWORD=\${SAMBA_PASSWORD:-'Passw0rd'}
	SAMBA_REALM=\${SAMBA_REALM:-'home.local'}
	SAMBA_DOMAIN=\${SAMBA_DOMAIN:-"\${SAMBA_REALM%%.*}"}
	/usr/bin/samba-tool domain provision --use-rfc2307 "--domain=\$SAMBA_DOMAIN" "--realm=\$SAMBA_REALM" --server-role=dc "--adminpass=\$SAMBA_PASSWORD" --dns-backend=SAMBA_INTERNAL --host-ip \${SMBIP:-"192.168.9.240"}
	cat >/etc/samba/smb.conf <<ENDCFG
[global]
        #dns forwarder = \$(awk '/nameserver/{print \$2}'</etc/resolv.conf)
        dns forwarder = 8.8.8.8
        netbios name = \$(upper <<<"\$H")
        realm = \$(upper <<<"\$SAMBA_REALM")
        server role = active directory domain controller
        workgroup = \$(upper <<<"\$SAMBA_DOMAIN")
        idmap_ldb:use rfc2307 = yes
        rpc server dynamic port range = 49152-49159
        log file = /dev/stdout
        multicast dns register = no
        ldap server require strong auth = no
        cluster addresses = \${SMBIP:-"192.168.9.240"}
	tls enabled  = yes
	tls keyfile  = tls/tls.key
	tls certfile = tls/tls.crt
	tls cafile   = tls/ca.crt

[netlogon]
        path = /var/lib/samba/sysvol/\$SAMBA_REALM/scripts
        read only = No

[sysvol]
        path = /var/lib/samba/sysvol
        read only = No
ENDCFG
	if [ -d /var/run/samba ];then
		mv /var/run/samba/* /var/lib/samba/run
		rm -rf /var/run/samba
		ln -sf /var/lib/samba/run /var/run/samba
	fi
	
	updateme &
else
	deleteme &
fi
cp /var/lib/samba/private/krb5.conf /etc
exec /usr/sbin/samba --foreground --no-process-group
ENDF
	ln -sf /var/lib/samba/run "$DIR_DEST/var/run/samba"
	ln -sf /var/lib/samba/cache "$DIR_DEST/var/cache/samba"
	ln -sf /var/lib/samba/config/smb.conf "$DIR_DEST/etc/samba/smb.conf"
	rm -f "$DIR_DEST/etc/samba/smb.conf" "$DIR_DEST/var/lib/samba/private/msg.sock/*"
	rm -rf "$DIR_DEST/var/run/samba" "$DIR_DEST/var/cache/samba"
}

samba.deploy() {
	CNAME=${CNAME:-"samba"}
	CPREFIX=${CPREFIX:-"samba-"}
	IP=192.168.9.240
	link.add.both 	dns			53
	link.add.both 	kerberos		88
	link.add 	epm			135
	link.add.udp 	ns			137
	link.add.udp 	dg			138
	link.add 	netbios			139
	link.add.both 	ldap			389
	link.add 	smb			445
	link.add.both 	kpass			464
	link.add 	ldaps			636
	link.add 	catalog			3268
	link.add 	catalogs		3269
	link.add 	rpc2			49152
	link.add 	rpc3			49153
	link.add 	rpc4			49154
	link.add 	rpc5			49155
	link.add 	rpc6			49156
	link.add 	rpc7			49157
	link.add 	rpc8			49158
	link.add 	rpc9			49159
	env.add		SMBIP			$IP
	env.add		SBMHOST			ad
	store.claim	"${CPREFIX}data"	"/var/lib/samba" "${SAMBA_CLAIM_SIZE:-"50Gi"}"
	#store.cert	"samba"			"ca-issuer" "ad.home.local" "/var/lib/samba/private"
	container.add.sys "${CPREFIX}samba"	"${REPODOCKER}/$CNAME:latest" '"samba"' "$(json.res "300m" "300Mi")"
	deploy.public "$IP"
}

step.add.build   samba.empty		"Cleanup the Samba layer"
step.add.install samba.install		"Install samba"
step.add.install samba.config		"Configure samba"
step.add.deploy  samba.deploy  		"Deploy Samba DC to kubernetes"

### Reverse DNS
# samba-tool dns zonecreate "$EXT" 9.192.168.in-addr.arpa -U administrator -P

#### Ajout d'utilisateur
# samba-tool domain passwordsettings set --complexity=off
# samba-tool domain passwordsettings set --history-length=0
# samba-tool domain passwordsettings set --min-pwd-age=0
# samba-tool domain passwordsettings set --max-pwd-age=0
# samba-tool domain passwordsettings set --min-pwd-length=0
# samba-tool user create seb password --mail-address=seb@home.local
# samba-tool user create vmail mailSystem


#### Ajout d'entrée dans le DNS
# samba-tool dns add "$EXT" "$REALM" task A 192.168.9.224 -U administrator -P
# samba-tool dns add "$EXT" "$REALM" doliseb A 192.168.9.221 -U administrator -P
# samba-tool dns add "$EXT" "$REALM" dolimanue A 192.168.9.222 -U administrator -P
# samba-tool dns add "$EXT" "$REALM" imap A 192.168.9.225 -U administrator -P
# samba-tool dns add "$EXT" "$REALM" smtp A 192.168.9.226 -U administrator -P
# samba-tool dns add "$EXT" "$REALM" mail A 192.168.9.227 -U administrator -P
# samba-tool dns add "$EXT" "$REALM" autodiscover CNAME mail.home.local -U administrator -P
# samba-tool dns add "$EXT" "$REALM" autoconfig CNAME mail.home.local -U administrator -P
# samba-tool dns add "$EXT" "$REALM" "$REALM" MX "smtp.home.local 10" -U administrator -P


#### route static sous windows (dans un cmd en temps qu'admin)
# route -p add 192.168.9.240 mask 255.255.255.255 192.168.9.214
