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
#@DESC@  postfix smtp server
#@GROUP@ app

BASE=buster
postfix.empty() {
	install.empty
}

postfix.install() {
	local r
	install.install libsasl2-modules postfix postfix-ldap sasl2-bin syslog-ng libgcrypt20
	r=$?
	return $r
}

postfix.conf.ldap() {
	json.file <<ENDF
version = 3
server_port = 389
timeout = 60
search_base = cn=Users,dc=home,dc=local
query_filter = (mail=%s)
result_attribute = cn
bind = yes
bind_dn = cn=vmail,cn=Users,dc=home,dc=local
bind_pw = mailSystem
server_host = ldap://samba/
start_tls = yes
ENDF
}

postfix.config() {
	rm -rf "$DIR_DEST/var/spool/postfix"
	mkdir "$DIR_DEST/etc/container" "$DIR_DEST/etc/postfix/ssl"
	cat >"$DIR_DEST/etc/container/people.ldap" <<ENDF
version = 3
server_port = 389
timeout = 60
search_base = cn=Users,dc=home,dc=local
query_filter = (mail=%s)
result_attribute = cn
bind = yes
bind_dn = cn=vmail,cn=Users,dc=home,dc=local
bind_pw = mailSystem
server_host = ldap://samba/
start_tls = yes
ENDF

	cat >"$DIR_DEST/etc/postfix/dynamicmaps.cf" <<ENDF
sqlite  postfix-sqlite.so       dict_sqlite_open
ldap    postfix-ldap.so dict_ldap_open
ENDF
	cat >"$DIR_DEST/etc/postfix/main.cf" <<ENDF
smtpd_banner = \$myhostname ESMTP \$mail_name (Ubuntu)
biff = no
append_dot_mydomain = no
readme_directory = no
smtpd_tls_cert_file=/etc/postfix/ssl/tls.crt
smtpd_tls_key_file=/etc/postfix/ssl/tls.key
smtpd_use_tls=yes
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache
smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination
myhostname = smtp.home.local
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
myorigin = /etc/mailname
mydestination = localhost, \$myhostname, \$mydomain
relayhost = 
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = ipv4
virtual_alias_maps = ldap:/etc/container/people.ldap
mailbox_transport = lmtp:dovecot.infra.local:24
mydomain = home.local
smtpd_sasl_type = dovecot
smtpd_sasl_path = inet:dovecot.infra.local:4000
smtpd_sasl_auth_enable = yes
local_transport = lmtp:dovecot.infra.local:24
ENDF

	cat >"$DIR_DEST/etc/postfix/master.cf" <<ENDF
smtp       inet  n       -       n       -       -       smtpd
pickup     unix  n       -       n       60      1       pickup
cleanup    unix  n       -       n       -       0       cleanup
qmgr       unix  n       -       n       300     1       qmgr
tlsmgr     unix  -       -       n       1000?   1       tlsmgr
rewrite    unix  -       -       n       -       -       trivial-rewrite
bounce     unix  -       -       n       -       0       bounce
defer      unix  -       -       n       -       0       bounce
trace      unix  -       -       n       -       0       bounce
verify     unix  -       -       n       -       1       verify
flush      unix  n       -       n       1000?   0       flush
proxymap   unix  -       -       n       -       -       proxymap
proxywrite unix  -       -       n       -       1       proxymap
smtp       unix  -       -       n       -       -       smtp
relay      unix  -       -       n       -       -       smtp
showq      unix  n       -       n       -       -       showq
error      unix  -       -       n       -       -       error
retry      unix  -       -       n       -       -       error
discard    unix  -       -       n       -       -       discard
local      unix  -       n       n       -       -       local
virtual    unix  -       n       n       -       -       virtual
lmtp       unix  -       -       n       -       -       lmtp
anvil      unix  -       -       n       -       1       anvil
scache     unix  -       -       n       -       1       scache
maildrop   unix  -       n       n       -       -       pipe flags=DRhu
  flags=DRhu user=vmail argv=/usr/bin/maildrop -d \${recipient}
uucp      unix  -       n       n       -       -       pipe
  flags=Fqhu user=uucp argv=uux -r -n -z -a\$sender - \$nexthop!rmail (\$recipient)
ifmail    unix  -       n       n       -       -       pipe
  flags=F user=ftn argv=/usr/lib/ifmail/ifmail -r \$nexthop (\$recipient)
bsmtp     unix  -       n       n       -       -       pipe
  flags=Fq. user=bsmtp argv=/usr/lib/bsmtp/bsmtp -t\$nexthop -f\$sender \$recipient
scalemail-backend unix  -       n       n       -       2       pipe
  flags=R user=scalemail argv=/usr/lib/scalemail/bin/scalemail-store \${nexthop} \${user} \${extension}
mailman   unix  -       n       n       -       -       pipe
  flags=FR user=list argv=/usr/lib/mailman/bin/postfix-to-mailman.py
  \${nexthop} \${user}
ENDF

	cat >"$DIR_DEST/start.d/postfix" <<ENDF
#postconf -F '*/*/chroot = n'
echo "home.local">/etc/mailname
postconf -e mydomain=home.local
postconf -e myhostname=smtp.home.local
#postconf -e 'mydestination=\$myhostname, mail.\$mydomain, \$mydomain, localhost'
#postconf -e smtpd_use_tls=yes
#postconf -e smtpd_tls_auth_only=no
#postconf -e 'mynetworks=127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128'
#postconf -e smtpd_relay_restrictions='permit_mynetworks,permit_tls_clientcerts,reject_unauth_destination'
#postconf -e smtpd_recipient_restrictions='permit_sasl_authenticated,reject_unauth_destination'

mkdir -p /var/spool/postfix
postfix set-permissions
service syslog-ng start
touch /var/log/mail.log
tail -f /var/log/mail.log &
exec /usr/sbin/postfix start-fg
ENDF
}

postfix.deploy() {
	CNAME=${CNAME:-"postfix"}
	CPREFIX=${CPREFIX:-"postfix-"}
	#IP=192.168.9.241
	# 110 143 4190 993 995
	#link.add 	lmtp			24
	link.add 	smtp			25
	store.map	"${CPREFIX}config"	"/etc/container" "$(json.label "people.ldap" "$(postfix.conf.ldap)")"
	store.cert	"postfix"		"ca-issuer" "imap.home.local" "/etc/postfix/ssl"
 	store.claim	"${CPREFIX}data"	"/var/spool" "${POSTFIX_CLAIM_SIZE:-"10Gi"}"
	container.add	"${CPREFIX}postfix"	"${REPODOCKER}/$CNAME:latest" '"postfix"'
	deploy.public
}

step.add.build   postfix.empty		"Cleanup the postfix layer"
step.add.install postfix.install	"Install postfix"
step.add.install postfix.config		"Configure postfix"
step.add.deploy  postfix.deploy  	"Deploy Dovecot to kubernetes"

