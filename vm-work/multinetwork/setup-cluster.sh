#!/bin/bash

set -ex

WORK_DIR=$1

if [[ -z "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
    echo "Usage: $0 WORK_DIR"
    exit 1
fi

VM_APP="mysql"
VM_NAMESPACE="test"
SERVICE_ACCOUNT="mysql-vm-sa"
CLUSTER_NETWORK="kube-network"
VM_NETWORK="vm-network"
CLUSTER="cluster1"
istiodir=${ISTIODIR:-"$HOME/istio"}
istiobinary=${ISTIOBINARY:-"$HOME/istio/bin/istioctl"}
istioprofile=${ISTIOPROFILE:-"default"}

pushd $WORK_DIR
cat <<EOF >vm-cluster.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: "${CLUSTER}"
      network: "${CLUSTER_NETWORK}"
EOF

$istiobinary install -f vm-cluster.yaml --set values.pilot.env.PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION=true --set values.pilot.env.PILOT_ENABLE_WORKLOAD_ENTRY_HEALTHCHECKS=true -y --set profile=$istioprofile $ISTIOINSTALLOPTS
$istiodir/samples/multicluster/gen-eastwest-gateway.sh --mesh mesh1 --cluster "$CLUSTER" --network "$CLUSTER_NETWORK" | $istiobinary install -y -f -

kubectl apply -n istio-system -f $istiodir/samples/multicluster/expose-istiod.yaml -f $istiodir/samples/multicluster/expose-services.yaml

kubectl create namespace $VM_NAMESPACE || true
kubectl create serviceaccount $SERVICE_ACCOUNT -n $VM_NAMESPACE || true

cat <<EOF >workloadgroup.yaml
apiVersion: networking.istio.io/v1alpha3
kind: WorkloadGroup
metadata:
  name: "${VM_APP}"
  namespace: "${VM_NAMESPACE}"
spec:
  metadata:
    labels:
      app: "${VM_APP}"
  template:
    serviceAccount: "${SERVICE_ACCOUNT}"
    network: "${VM_NETWORK}"
EOF

kubectl --namespace "${VM_NAMESPACE}" apply -f workloadgroup.yaml

sleep 10

set +e
while true; do
  $istiobinary x workload entry configure -f workloadgroup.yaml -o "${WORK_DIR}" --clusterID "${CLUSTER}" --autoregister

  cat hosts | grep istiod
  if [[ $? -eq 0 ]]; then
    echo "istiod ready"
    break
  fi
  echo "Waiting for workloadgroup to be ready"
  sleep 5
done