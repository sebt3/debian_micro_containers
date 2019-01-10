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
#@DESC@  dovecot email server
#@GROUP@ app

# maildirmake.dovecot /etc/skel/mail
# maildirmake.dovecot /etc/skel/mail/.Drafts
# maildirmake.dovecot /etc/skel/mail/.Sent
# maildirmake.dovecot /etc/skel/mail/.Trash
# maildirmake.dovecot /etc/skel/mail/.Templates



BASE=buster
dovecot.empty() {
	install.empty
}

dovecot.install() {
	local r
	install.install dovecot-core dovecot-gssapi dovecot-imapd dovecot-ldap dovecot-lmtpd dovecot-mysql dovecot-pgsql dovecot-pop3d dovecot-antispam dovecot-sieve dovecot-managesieved dovecot-lucene dovecot-solr winbind krb5-user krb5-config samba-common-bin samba-common
	r=$?
	return $r
}

dovecot.config() {
	mkdir -p "$DIR_DEST/etc/container" "$DIR_DEST/etc/dovecot/ssl"
	ln -sf "/etc/container/krb5.conf" "$DIR_DEST/etc/krb5.conf"
	ln -sf "/etc/container/smb.conf" "$DIR_DEST/etc/samba/smb.conf"
	cat > "$DIR_DEST/etc/container/krb5.conf" <<ENDF
[libdefaults]
default_realm = HOME.LOCAL

[realms]
HOME.LOCAL = {
  kdc = samba
  admin_server = samba
}

[domain_realm]
  .home.local = HOME.LOCAL
  home.local = HOME.LOCAL
 .kerberos.server = HOME.LOCAL
ENDF
	cat > "$DIR_DEST/etc/container/smb.conf" <<ENDF
[global]
  workgroup = HOME
  realm = HOME.LOCAL
  security = ADS
  local master = no
  domain master = no
  preferred master = no
  dns proxy = no
  idmap uid = 10000-20000
  idmap gid = 10000-20000
  password server = samba
  encrypt passwords = yes
  kerberos method = system keytab
  winbind enum users = yes
  winbind enum groups = yes
  winbind use default domain = yes
  winbind offline logon = false
  winbind separator = +
ENDF
	cat >"$DIR_DEST/etc/container/dovecot-ldap.conf" <<ENDF
hosts				= samba:389
ldap_version			= 3
auth_bind			= yes
dn				= cn=vmail,cn=Users,dc=home,dc=local
dnpass				= mailSystem
base				= cn=Users,dc=home,dc=local
pass_filter			= (cn=%n)
user_filter			= (cn=%n)
user_attrs			= cn=home=/home/vmail/%$
ENDF
	cat >"$DIR_DEST/etc/dovecot/conf.d/10-mail.conf" <<ENDF
namespace inbox {
  inbox = yes
  list = yes
  subscriptions = yes
}

mail_privileged_group = mail
protocol !indexer-worker {
}
ENDF
	cat >"$DIR_DEST/etc/dovecot/conf.d/10-master.conf" <<ENDF
service imap-login {
  inet_listener imap {
    port = 143
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
}
service pop3-login {
  inet_listener pop3 {
    port = 110
  }
  inet_listener pop3s {
    port = 995
    ssl = yes
  }
}
service submission-login {
  inet_listener submission {
    port = 587
  }
}
service lmtp {
  unix_listener lmtp {
    #mode = 0666
  }
  inet_listener lmtp {
    address = 0.0.0.0
    port = 24
  }
}
service imap {
}
service pop3 {
}
service submission {
}
service auth {
  unix_listener auth-userdb {
  }
  inet_listener {
    port = 4000
  }
}
service auth-worker {
}
service dict {
  unix_listener dict {
  }
}
ENDF
	cat >"$DIR_DEST/etc/dovecot/conf.d/10-auth.conf" <<ENDF
auth_use_winbind		= yes
auth_winbind_helper_path	= /usr/bin/ntlm_auth
#auth_mechanisms			= plain login gss-spnego ntlm
auth_mechanisms			= plain login cram-md5
auth_username_format		= %Lu
disable_plaintext_auth		= yes
passdb {
  driver			= ldap
  args				= /etc/container/dovecot-ldap.conf
}
userdb {
   driver=static
   args = uid=501 gid=501 home=/home/vmail/%Ln mail=maildir:/home/vmail/%Ln/mail allow_all_users=yes
}
ENDF
	cat >"$DIR_DEST/etc/dovecot/conf.d/10-ssl.conf" <<ENDF
ssl = yes
ssl_cert = </etc/dovecot/ssl/tls.crt
ssl_key = </etc/dovecot/ssl/tls.key
ENDF
	cat >"$DIR_DEST/etc/dovecot/conf.d/15-mailboxes.conf" <<ENDF
namespace inbox {
  mailbox Drafts {
    special_use = \Drafts
    auto = subscribe
  }
  mailbox Junk {
    special_use = \Junk
    auto = subscribe
  }
  mailbox Trash {
    special_use = \Trash
    auto = subscribe
  }
  mailbox Sent {
    special_use = \Sent
    auto = subscribe
  }
  mailbox "Sent Messages" {
    special_use = \Sent
  }
}
ENDF
	cat >"$DIR_DEST/etc/dovecot/conf.d/20-lmtp.conf" <<ENDF
protocol lmtp {
  postmaster_address = postmaster@home.local
  mail_plugins = sieve
}

plugin {
  sieve_before = /home/vmail/sieve/spam-global.sieve
  sieve = /home/vmail/%Lu/dovecot.sieve
  sieve_dir = /home/vmail/%Lu/sieve
}
ENDF
	cat >"$DIR_DEST/etc/dovecot/dovecot.conf" <<ENDF
!include_try /usr/share/dovecot/protocols.d/*.protocol
dict {
}
!include conf.d/*.conf
!include_try local.conf
log_path = /var/log/mail.log
ENDF
	cat >"$DIR_DEST/start.d/dovecot" <<ENDF
hostname imap.home.local
mkdir -p /home/vmail/sieve
if [ ! -e /home/vmail/sieve/spam-global.sieve ];then
	echo 'require "fileinto";'>/home/vmail/sieve/spam-global.sieve
	echo 'if header :contains "X-Spam-Flag" "YES" {'>>/home/vmail/sieve/spam-global.sieve
	echo '  fileinto "Spam";'>>/home/vmail/sieve/spam-global.sieve
	echo '}'>>/home/vmail/sieve/spam-global.sieve
fi
chown -R 501:501 /home/vmail
touch /var/log/mail.log
tail -f /var/log/mail.log &
exec /usr/sbin/dovecot -F
ENDF
}

dovecot.conf.kb5() {
	json.file <<ENDF
[libdefaults]
default_realm = HOME.LOCAL

[realms]
HOME.LOCAL = {
  kdc = samba
  admin_server = samba
}

[domain_realm]
  .home.local = HOME.LOCAL
  home.local = HOME.LOCAL
 .kerberos.server = HOME.LOCAL
ENDF
}
dovecot.conf.smb() {
	json.file <<ENDF
[global]
  workgroup = HOME
  realm = HOME.LOCAL
  security = ADS
  local master = no
  domain master = no
  preferred master = no
  dns proxy = no
  idmap uid = 10000-20000
  idmap gid = 10000-20000
  password server = samba
  encrypt passwords = yes
  kerberos method = system keytab
  winbind enum users = yes
  winbind enum groups = yes
  winbind use default domain = yes
  winbind offline logon = false
  winbind separator = +
ENDF
}
dovecot.conf.ldap() {
	json.file <<ENDF
hosts = samba:389
ldap_version = 3
auth_bind = yes
dn = cn=vmail,cn=Users,dc=home,dc=local
dnpass = mailSystem
base = cn=Users,dc=home,dc=local
pass_filter = (cn=%n)
user_filter = (cn=%n)
user_attrs = cn=home=/home/vmail/%$
ENDF
}

dovecot.deploy() {
	CNAME=${CNAME:-"dovecot"}
	CPREFIX=${CPREFIX:-"dovecot-"}
	link.add 	lmtp			24
	link.add 	pop			110
	link.add 	imap			143
	link.add 	imaps			993
	link.add 	pops			995
	link.add 	auth			4000
	link.add 	sieve			4190
	store.claim	"${CPREFIX}data"	"/home/vmail" "${DOVECOT_CLAIM_SIZE:-"50Gi"}"
	store.map	"${CPREFIX}config"	"/etc/container" "$(json.label "krb5.conf" "$(dovecot.conf.kb5)"),$(json.label "smb.conf" "$(dovecot.conf.smb)"),$(json.label "dovecot-ldap.conf" "$(dovecot.conf.ldap)")"
	store.cert	"dovecot"		"ca-issuer" "imap.home.local" "/etc/dovecot/ssl"
	container.add.sys "${CPREFIX}dovecot"	"${REPODOCKER}/$CNAME:latest" '"dovecot"' "$(json.res "050m" "30Mi")"
	deploy.public
}

step.add.build   dovecot.empty		"Cleanup the dovecot layer"
step.add.install dovecot.install	"Install dovecot"
step.add.install dovecot.config		"Configure dovecot"
step.add.deploy  dovecot.deploy  	"Deploy Dovecot to kubernetes"



