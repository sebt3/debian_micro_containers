##############################################################################
### utilitaires pour les deploiements
##

ADDONS=()
CONTAINERS=()
LINKS=()
kube.apply() {
	case $DELETE in
	Y)	net.run "$MASTER" kubectl delete -f -;;
	*)	net.run "$MASTER" kubectl apply -f -;;
	esac
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
	local name="$1" labels="${2:-""}" links="${3:-""}" namespace="${4:-"$NAMESPACE"}"
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
    "type": "LoadBalancer"
  }
}
ENDKUBE
}

kube.deploy() {
	local name="$1" labels="$2" containers="$3" volumes=${4:-""}  namespace=${5:-"$NAMESPACE"} 
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

json.label() {
	local n=$1 v=$2
	echo "\"$n\": \"$v\""
}
json.pair() {
	local n1=$1 v1=$2 n2=$3 v2=$4
	echo "{ $(json.label "$n1" "$v1"), $(json.label "$n2" "$v2") }"
}
json.env() {
	json.pair name "$1" value "$2"
}
json.env.from() {
	json.pair.n name "$1" valueFrom "{ \"fieldRef\": { $(json.label "fieldPath" "$2") } }"
}

json.port() {
	echo "{ \"containerPort\": $1, $(json.label protocol "${2:-"TCP"}") }"
}
json.container() {
	local name=$1 image=$2 args=${3:-""} mounts=${4:-""} ports=${5:-""} env=${6:-""} cmd=${7:-""} policy=${8:-"Always"}
	local lcmd="" largs=""
	[ ! -z "$cmd" ] && lcmd=", \"command\": [\"$cmd\"]"
	[ ! -z "$args" ] && largs=", \"args\": [ $args ]"
	echo "{ $(json.label name "$name"), $(json.label image "$image") $lcmd $largs, \"ports\": [ $ports ], \"env\": [ $env ], \"volumeMounts\": [ $mounts ],  $(json.label imagePullPolicy "$policy") }"
}
json.syscontainer() {
	local name=$1 image=$2 args=${3:-""} mounts=${4:-""} ports=${5:-""} env=${6:-""} cmd=${7:-""} policy=${8:-"Always"}
	local lcmd="" largs=""
	[ ! -z "$cmd" ] && lcmd=", \"command\": [\"$cmd\"]"
	[ ! -z "$args" ] && largs=", \"args\": [ $args ]"
	echo "{ $(json.label name "$name"), $(json.label image "$image") $lcmd $largs, \"ports\": [ $ports ], \"env\": [ $env ], \"securityContext\": {\"privileged\": true}, \"volumeMounts\": [ $mounts ],  $(json.label imagePullPolicy "$policy") }"
}
json.pair.n() {
	local n1=$1 v1=$2 n2=$3 v2=$4
	echo "{ $(json.label "$n1" "$v1"), \"$n2\": $v2 }"
}
json.mount() {
	json.pair name "$1" mountPath "$2"
}
json.mount.ro() {
	echo "{ \"name\": \"$1\", \"mountPath\": \"$2\", \"readOnly\": true }"
}
json.volume.config() {
	json.pair.n "name" "$1" "configMap" "$(json.pair.n "name" "$2" "defaultMode" 420)"
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
json.change() {
	echo "$1 [$2]"
}


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
	[ -z "$NO_SERVICE" ] && kube.balancer "$CNAME" "$LABELS" "$LS"
	kube.deploy "$CNAME" "$LABELS" "$CONTS" "$VOLUMES" $NAMESPACE
}
