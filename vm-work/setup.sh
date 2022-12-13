#!/bin/bash

VM_NAME=daniel-cluster-vm
VM_ZONE=us-west1-c
VM_APP=test
VM_NAMESPACE=test
WORK_DIR=$(mktemp -d)
SERVICE_ACCOUNT=test
CLUSTER_NETWORK=""
VM_NETWORK=""
CLUSTER="Kubernetes"
PROFILE=${PROFILE:-ambient}
istiodir=$ISTIODIR

if [[ -z "$istiodir" ]]; then
  # This is reliant upon istioctl being in $HOME/istio/bin/istioctl, a standard install path
  istiodir=$(dirname "$(dirname "$(which istioctl)")")
fi

if [[ ! -f "$istiodir/samples/multicluster/gen-eastwest-gateway.sh" ]]; then
  echo "Bad istiodir, $istiodir. Cannot find $istiodir/samples/multicluster/gen-eastwest-gateway.sh"
  echo "Please check and fix... or you can pass ISTIODIR= to the script"
  exit 1
fi

set -ex
cat <<EOF | istioctl install --set profile=$PROFILE -y -f -
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

$istiodir/samples/multicluster/gen-eastwest-gateway.sh --single-cluster | istioctl install -y -f -
kubectl apply -n istio-system -f $istiodir/samples/multicluster/expose-istiod.yaml

set +e
kubectl create namespace ${VM_NAMESPACE}
kubectl create serviceaccount -n ${VM_NAMESPACE} ${SERVICE_ACCOUNT}
set -e

echo "Waiting for loadbalancers to get ip addresses"

waitForIP() {
  svc=$1
  external_ip=""
  while [ -z $external_ip ]; do
    external_ip=$(kubectl get svc $svc -n istio-system --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
    [ -z $external_ip ] && sleep 5
  done
  echo "LoadBalancer $svc ready"
}

waitForIP istio-ingressgateway
waitForIP istio-eastwestgateway

cat <<EOF >$WORK_DIR/wlg.yaml
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

istioctl x workload entry configure -f $WORK_DIR/wlg.yaml -o "$WORK_DIR" --clusterID "$CLUSTER"

istiover=$(istioctl version --output=json | jq -r '.clientVersion.version')

if [[ -f "$istiodir/out/linux_amd64/release/istio-sidecar.deb" ]]; then
  cp "$istiodir/out/linux_amd64/release/istio-sidecar.deb" $WORK_DIR/istio-sidecar.deb
else
  wget https://storage.googleapis.com/istio-release/releases/$istiover/deb/istio-sidecar.deb -O $WORK_DIR/istio-sidecar.deb
fi

cat <<EOF >$WORK_DIR/setup.sh
sudo mkdir -p /etc/certs
set -ex
sudo cp \$HOME/vm/root-cert.pem /etc/certs/root-cert.pem
sudo mkdir -p /var/run/secrets/tokens
sudo cp \$HOME/vm/istio-token /var/run/secrets/tokens/istio-token
sudo dpkg -i \$HOME/vm/istio-sidecar.deb
sudo cp \$HOME/vm/cluster.env /var/lib/istio/envoy/cluster.env
sudo cp \$HOME/vm/mesh.yaml /etc/istio/config/mesh
sudo sh -c 'cat \$(eval echo ~\$SUDO_USER)/vm/hosts >> /etc/hosts'
sudo mkdir -p /etc/istio/proxy
sudo chown -R istio-proxy /var/lib/istio /etc/certs /etc/istio/proxy /etc/istio/config /var/run/secrets /etc/certs/root-cert.pem
sudo systemctl start istio
EOF

set +e
gcloud compute ssh $VM_NAME --zone=$VM_ZONE --command="mkdir ~/vm"
set -e
gcloud compute scp $WORK_DIR/* $VM_NAME:~/vm/ --recurse --zone=$VM_ZONE
gcloud compute ssh $VM_NAME --zone=$VM_ZONE --command="bash \$HOME/vm/setup.sh"

set +e
kubectl create namespace test
kubectl label namespace test istio-injection=enabled
set -e

kubectl apply -n test -f $istiodir/samples/helloworld/helloworld.yaml
kubectl rollout status -n test deploy/helloworld-v1
kubectl rollout status -n test deploy/helloworld-v2

gcloud compute ssh $VM_NAME --zone=$VM_ZONE --command="curl helloworld.test.svc:5000/hello"
gcloud compute ssh $VM_NAME --zone=$VM_ZONE --command="curl helloworld.test.svc:5000/hello"
gcloud compute ssh $VM_NAME --zone=$VM_ZONE --command="curl helloworld.test.svc:5000/hello"
gcloud compute ssh $VM_NAME --zone=$VM_ZONE --command="curl helloworld.test.svc:5000/hello"
gcloud compute ssh $VM_NAME --zone=$VM_ZONE --command="curl helloworld.test.svc:5000/hello"
