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
#@DESC@  jenkins
#@GROUP@ app

jenkins.source() {
	source.file jenkins.war http://mirrors.jenkins.io/war-stable/latest/jenkins.war
}

jenkins.install() {
	install.init
	install.container java8
	cp "$DIR_SOURCE/jenkins.war" "$DIR_DEST"
	mkdir -p "$DIR_DEST/var/jenkins"
}

jenkins.config() {
	cat >"$DIR_DEST/start.d/jenkins" <<ENDF
export JENKINS_HOME=/var/jenkins
exec /usr/lib/jvm/java-1.8.0-openjdk-$ARCH/bin/java -Djava.awt.headless=true -jar /jenkins.war --httpPort=80
ENDF
}
step.add.source	 jenkins.source		"Get Jenkins war file"
step.add.install jenkins.install	"Install jenkins"
step.add.install jenkins.config		"Configure jenkins"

jenkins.deploy() {
	CNAME=${CNAME:-"jenkins"}
	CPREFIX=${CPREFIX:-"jenkins-"}
	link.add 	www			80
	store.claim	${CPREFIX}data		"/var/jenkins" "${JENKINS_CLAIM_SIZE:-"10Gi"}"
	container.add	"${CPREFIX}jenkins" 	"${REPODOCKER}/$CNAME:latest" '"jenkins"'
	deploy.public
}

step.add.deploy  jenkins.deploy		"Deploy jenkins to kubernetes"

