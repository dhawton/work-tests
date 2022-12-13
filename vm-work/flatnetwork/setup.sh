#!/bin/bash

set -ex

workdir=$(mktemp -d)
istiodir=${ISTIODIR:-"$HOME/istio"}
istioprofile=${ISTIOPROFILE:-"default"}
istiobinary=${ISTIOBINARY:-"$istiodir/out/linux_amd64/istioctl"}
type=${TYPE:-"cluster"}
vm=${VM:-"daniel-$type-vm"}
zone=${ZONE:-"us-central1-c"}
istioinstallopts=${ISTIOINSTALLOPTS:-""}

ISTIODIR=$istiodir ISTIOPROFILE=$istioprofile ISTIOBINARY=$istiobinary ISTIOINSTALLOPTS="$istioinstallopts" ./setup-cluster.sh $workdir
ISTIODIR=$istiodir ISTIOBINARY=$istiobinary VM_ZONE=$zone ./setup-vm.sh $workdir $vm