##############################################################################
### utilitaires pour les deploiements
##

ADDONS=()
CONTAINERS=()
LINKS=()
kube.apply() {
	#cat;return
	case $DELETE in
	Y)	net.run "$MASTER" kubectl delete -f -;;
	*)	net.run "$MASTER" kubectl apply -f -;;
	esac
}
kube.cert() {
	local name="$1" issuer="$2" cn="${3:-""}" sn="${4:-"${1}-tls"}" dn="${5:-"\"$cn\""}" namespace="${6:-"$NAMESPACE"}"
	kube.apply <<ENDKUBE
{
    "apiVersion": "certmanager.k8s.io/v1alpha1",
    "kind": "Certificate",
    "metadata": {
        "name": "$name",
        "namespace": "$namespace"
    },
    "spec": {
        "commonName": "$cn",
        "dnsNames": [ $dn ],
        "issuerRef": {
            "kind": "Issuer",
            "name": "$issuer"
        },
        "organization": [
            "Example CA"
        ],
        "secretName": "$sn"
    }
}
ENDKUBE
}
kube.service() {
	local name="$1" ip="$2" labels="${3:-""}" links="${4:-""}" namespace="${5:-"$NAMESPACE"}"
	local iptext=""
	[ ! -z "$ip" ] && iptext="$(json.label clusterIP "$ip"),"
	kube.apply <<ENDKUBE
{
  "kind": "Service",
  "apiVersion": "v1",
  "metadata": {
    "name": "$name",
    "namespace": "$namespace",
    "labels": { $labels }
  },
  "spec": {
    "ports": [ $links ],
    "selector": { $labels },
    $iptext
    "type": "ClusterIP"
  }
}
ENDKUBE
}
kube.balancer() {
	local name="$1" labels="${2:-""}" links="${3:-""}" namespace="${4:-"$NAMESPACE"}" anno="" lbip="" ip="$5"
	if [ -n "$ip" ];then
		lbip="\"loadBalancerIP\": \"$ip\","
		anno="\"annotations\": { \"metallb.universe.tf/allow-shared-ip\": \"$ip\" },"
	fi
	kube.apply <<ENDKUBE
{
  "kind": "Service",
  "apiVersion": "v1",
  "metadata": {
    "name": "$name",
    $anno
    "namespace": "$namespace",
    "labels": { $labels }
  },
  "spec": {
    "ports": [ $links ],
    $lbip
    "selector": { $labels },
    "type": "LoadBalancer"
  }
}
ENDKUBE
}

kube.deploy() {
	local name="$1" labels="$2" containers="$3" volumes=${4:-""}  namespace=${5:-"$NAMESPACE"} 
	#cat <<ENDKUBE
	kube.apply <<ENDKUBE
{
  "kind": "Deployment",  "apiVersion": "extensions/v1beta1",
  "metadata": {
    "name": "$name",
    "namespace": "$namespace"
  },
  "spec": {
    "replicas": 1,
    "selector": { "matchLabels": { $labels } },
    "template": {
      "metadata": { "labels": { $labels } },
      "spec": {
        "volumes": [ $volumes ],
        "containers": [ $containers ]
      }
    }
  }
}
ENDKUBE
}
kube.ds() {
	local name="$1" labels="$2" containers="$3" volumes=${4:-""}  namespace=${5:-"$NAMESPACE"} 
	#cat <<ENDKUBE
	kube.apply <<ENDKUBE
{
  "kind": "DaemonSet",  "apiVersion": "extensions/v1beta1",
  "metadata": {
    "name": "$name",
    "namespace": "$namespace"
  },
  "spec": {
    "selector": { "matchLabels": { $labels } },
    "template": {
      "metadata": { "labels": { $labels } },
      "spec": {
        "volumes": [ $volumes ],
        "containers": [ $containers ]
      }
    }
  }
}
ENDKUBE
}
kube.ns() {
	local namespace=${1:-"$NAMESPACE"}
	kube.apply <<ENDKUBE
{
  "kind": "Namespace",
  "apiVersion": "v1",
  "metadata": {
    "name": "$namespace",
    "labels": {
      "name": "$namespace"
    }
  }
}
ENDKUBE
}
# https://sysdig.com/blog/ceph-persistent-volume-for-kubernetes-or-openshift/
kube.claim() {
	local name=$1 size=$2 namespace=${3:-"$NAMESPACE"}
	net.run "$MASTER" kubectl apply -f - <<ENDF
{
  "kind": "PersistentVolumeClaim", "apiVersion": "v1",
  "metadata": { "name": "$name", "namespace": "$namespace" },
  "spec": {
    "storageClassName": "rbd",
    "accessModes": [ "ReadWriteOnce" ],
    "resources": {"requests": { "storage": "$size" } }
  }
}
ENDF
}
kube.claim.many() {
	local name=$1 size=$2 namespace=${3:-"$NAMESPACE"}
	net.run "$MASTER" kubectl apply -f - <<ENDF
{
  "kind": "PersistentVolumeClaim", "apiVersion": "v1",
  "metadata": { "name": "$name", "namespace": "$namespace" },
  "spec": {
    "storageClassName": "cephfs",
    "accessModes": [ "ReadWriteMany" ],
    "resources": {"requests": { "storage": "$size" } }
  }
}
ENDF
}

kube.configmap() {
	local name="$1" data="$2" namespace=${4:-"$NAMESPACE"} labels=$3
	kube.apply <<ENDKUBE
{
  "kind": "ConfigMap",  "apiVersion": "v1",
  "metadata": {
    "name": "$name",
    "namespace": "$namespace",
    "labels": { $labels }
  },
  "data": { $data }
}
ENDKUBE
}

kube.exec() {
	net.run "$MASTER" kubectl exec "$@"
}
kube.get.rs() {
	net.run "$MASTER" kubectl describe deploy $1|awk '$1=="NewReplicaSet:"{print $2}'
}
kube.get.pod() {
	net.run "$MASTER" kubectl get pod|awk -v R=$(kube.get.rs $1) '$1~R{print $1}'
}

json.file() {
	sed 's/\\/\\\\/g'|sed 's/"/\\"/g'|sed -e :a -e '/$/N; s/\n/\\n/; ta'
}

json.label() {
	local n=$1 v=$2
	echo "\"$n\": \"$v\""
}
json.pair() {
	local n1=$1 v1=$2 n2=$3 v2=$4
	echo "{ $(json.label "$n1" "$v1"), $(json.label "$n2" "$v2") }"
}

json.pair.n() {
	local n1=$1 v1=$2 n2=$3 v2=$4
	echo "{ $(json.label "$n1" "$v1"), \"$n2\": $v2 }"
}
json.change() {
	echo "$1 [$2]"
}

json.container() {
	local name=$1 image=$2 args=${3:-""} mounts=${4:-"$MOUNTS"} ports=${5:-"$PORTS"} env=${6:-"$ENVS"} cmd=${7:-""} policy=${8:-"Always"}
	local lcmd="" largs=""
	[ ! -z "$cmd" ] && lcmd=", \"command\": [\"$cmd\"]"
	[ ! -z "$args" ] && largs=", \"args\": [ $args ]"
	echo "{ $(json.label name "$name"), $(json.label image "$image") $lcmd $largs, \"ports\": [ $ports ], \"env\": [ $env ], \"volumeMounts\": [ $mounts ],  $(json.label imagePullPolicy "$policy") }"
}
json.syscontainer() {
	local name=$1 image=$2 args=${3:-""} mounts=${4:-"$MOUNTS"} ports=${5:-"$PORTS"} env=${6:-"$ENVS"} cmd=${7:-""} policy=${8:-"Always"}
	local lcmd="" largs=""
	[ ! -z "$cmd" ] && lcmd=", \"command\": [\"$cmd\"]"
	[ ! -z "$args" ] && largs=", \"args\": [ $args ]"
	echo "{ $(json.label name "$name"), $(json.label image "$image") $lcmd $largs, \"ports\": [ $ports ], \"env\": [ $env ], \"securityContext\": {\"privileged\": true}, \"volumeMounts\": [ $mounts ],  $(json.label imagePullPolicy "$policy") }"
}
container.add() {
	CONTAINERS+=("$(json.container "$@")")
}
container.add.sys() {
	CONTAINERS+=("$(json.syscontainer "$@")")
}

json.port() {
	echo "{ \"containerPort\": $1, $(json.label protocol "${2:-"TCP"}") }"
}
json.link() {
	local port=$1
	local target=${2:-"$1"} proto=${3:-"TCP"}
	echo "{ \"port\": $port, \"targetPort\": $target, $(json.label "protocol" "$proto") }"
}
json.link.name() {
	local name=$1
	local port=$2
	local target=${3:-"$2"} proto=${4:-"TCP"}
	echo "{ \"name\": \"$name\",  \"port\": $port, \"targetPort\": $target, $(json.label "protocol" "$proto") }"
}
link.add() {
	PORTS=$(sed 's/^,//' <<<"$PORTS,$(json.port ${3:-"$2"} $4)")
	LINKS+=("$(json.link.name "$@")")
}
link.add.udp() {
	LINK_USE_BOTH=1
	PORTS=$(sed 's/^,//' <<<"$PORTS,$(json.port ${3:-"$2"} UDP)")
	LINKSUDP+=("$(json.link.name "$1" "$2" "${3:-"$2"}" UDP)")
}
link.add.both() {
	LINK_USE_BOTH=1
	PORTS=$(sed 's/^,//' <<<"$PORTS,$(json.port ${3:-"$2"}),$(json.port ${3:-"$2"} UDP)")
	LINKS+=("$(json.link.name "$1" "$2" "${3:-"$2"}")")
	LINKSUDP+=("$(json.link.name "$1" "$2" "${3:-"$2"}" UDP)")
}

env.add() {
	ENVS=$(sed 's/^,//' <<<"$ENVS,$(json.pair name "$1" value "$2")")
}
env.from() {
	ENVS=$(sed 's/^,//' <<<"$ENVS,$(json.pair.n name "$1" valueFrom "{ \"fieldRef\": { $(json.label "fieldPath" "$2") } }")")
}

#####
### Storage
json.mount() {
	json.pair name "$1" mountPath "$2"
}
json.mount.ro() {
	echo "{ \"name\": \"$1\", \"mountPath\": \"$2\", \"readOnly\": true }"
}
json.volume.secret() {
	json.pair.n "name" "$1" "secret" "$(json.pair.n "secretName" "${2:-"$1"}" "defaultMode" 420)"
}
json.volume.config() {
	json.pair.n "name" "$1" "configMap" "$(json.pair.n "name" "${2:-"$1"}" "defaultMode" 420)"
}
json.volume.host() {
	json.pair.n "name" "$1" "hostPath" "$(json.pair "path" "$2" "type" "Directory")"
}
json.volume.hostFile() {
	json.pair.n "name" "$1" "hostPath" "{ $(json.label "path" "$2") }"
}
json.volume.claim() {
	json.pair.n "name" "$1" "persistentVolumeClaim" "{ $(json.label "claimName" "$2") }"
}
json.volume.empty() {
	json.pair.n "name" "$1" "emptyDir" "{}"
}

mount.add() {
	MOUNTS=$(sed 's/^,//' <<<"$MOUNTS,$(json.mount "$1" "$2")")
}
mount.add.ro() {
	MOUNTS=$(sed 's/^,//' <<<"$MOUNTS,$(json.mount.ro "$1" "$2")")

}

store.cert() {
	local name="$1" issuer="$2" cn="${3:-""}" mp="${4:-""}" sn="${5:-"${1}-tls"}" dn="${6:-"\"$cn\""}" namespace="${7:-"$NAMESPACE"}"
	echo kube.cert "$name" "$issuer" "$cn" "$sn" "$dn" "$namespace"
	kube.cert "$name" "$issuer" "$cn" "$sn" "$dn" "$namespace"
	mount.add "$sn" "$mp"
	VOLUMES=$(sed 's/^,//' <<<"$VOLUMES,$(json.volume.secret "$sn")")
}
store.volatile() {
	local alias=$1 mp=$2
	mount.add "$alias" "$mp"
	VOLUMES=$(sed 's/^,//' <<<"$VOLUMES,$(json.volume.empty "$alias")")
}
store.map() {
	local alias=$1 mp=$2 data=$3
	kube.configmap "$alias" "$data" "$(json.label "run" "$CNAME")"
	mount.add "$alias" "$mp"
	VOLUMES=$(sed 's/^,//' <<<"$VOLUMES,$(json.volume.config "$alias")")
}
store.claim.many() {
	local alias=$1 mp=$2 size=${3:-"1Gi"} claim="${4:-"${CPREFIX}${CNAME}"}"
	kube.claim.many "$claim" "$size"
	mount.add "$alias" "$mp"
	VOLUMES=$(sed 's/^,//' <<<"$VOLUMES,$(json.volume.claim "$alias" "$claim")")
}
store.claim() {
	local alias=$1 mp=$2 size=${3:-"1Gi"} claim="${4:-"${CPREFIX}${CNAME}"}"
	kube.claim "$claim" "$size"
	mount.add "$alias" "$mp"
	VOLUMES=$(sed 's/^,//' <<<"$VOLUMES,$(json.volume.claim "$alias" "$claim")")
}
store.dir() {
	local alias=$1 mp=$2 dir=$3
	mount.add.ro  "$alias" "$mp"
	VOLUMES=$(sed 's/^,//' <<<"$VOLUMES,$(json.volume.host "$alias" "$dir")")
}
store.dir.rw() {
	local alias=$1 mp=$2 dir=$3
	mount.add "$alias" "$mp"
	VOLUMES=$(sed 's/^,//' <<<"$VOLUMES,$(json.volume.host "$alias" "$dir")")
}
store.file() {
	local alias=$1 mp=$2 file=$3
	mount.add.ro  "$alias" "$mp"
	VOLUMES=$(sed 's/^,//' <<<"$VOLUMES,$(json.volume.hostFile "$alias" "$file")")
}

#####
### Standard Deployement
deploy.default() {
	LABELS="$(json.label "run" "$CNAME")"
	for ((i=0;i<${#CONTAINERS[@]};i++));do
		CONTS=$(sed 's/^,//'<<<"$CONTS,${CONTAINERS[$i]}")
	done
	for ((i=0;i<${#LINKS[@]};i++));do
		LS=$(sed 's/^,//'<<<"$LS,${LINKS[$i]}")
	done
	[ -z "$NO_SERVICE" ] && kube.service "$CNAME" "$IP" "$LABELS" "$LS"
	kube.deploy "$CNAME" "$LABELS" "$CONTS" "$VOLUMES" $NAMESPACE
}

deploy.public() {
	LABELS="$(json.label "run" "$CNAME")"
	for ((i=0;i<${#CONTAINERS[@]};i++));do
		CONTS=$(sed 's/^,//'<<<"$CONTS,${CONTAINERS[$i]}")
	done
	for ((i=0;i<${#LINKS[@]};i++));do
		LS=$(sed 's/^,//'<<<"$LS,${LINKS[$i]}")
	done
	if [ ${LINK_USE_BOTH:-0} -eq 1 ] && [ -n "$1" ];then
		for ((i=0;i<${#LINKSUDP[@]};i++));do
			LS2=$(sed 's/^,//'<<<"$LS2,${LINKSUDP[$i]}")
		done
		kube.balancer "udp$CNAME" "$LABELS" "$LS2" "$NAMESPACE" "$1"
		kube.balancer "$CNAME" "$LABELS" "$LS" "$NAMESPACE" "$1"
	else
	[ -z "$NO_SERVICE" ] && kube.balancer "$CNAME" "$LABELS" "$LS"
	fi
	kube.deploy "$CNAME" "$LABELS" "$CONTS" "$VOLUMES" $NAMESPACE
}
