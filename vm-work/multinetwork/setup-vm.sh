#!/bin/bash

WORK_DIR=$1
VM_NAME=$2
VM_ZONE=${VM_ZONE:-"us-west1-c"}
istiodir=${ISTIODIR:-"$HOME/istio"}
istiobinary=${ISTIOBINARY:-"$HOME/istio/bin/istioctl"}

if [[ -z "$WORK_DIR" || ! -d "$WORK_DIR" || -z "$VM_NAME" ]]; then
    echo "Usage: $0 WORK_DIR VM_NAME"
    exit 1
fi

istiover=$($istiobinary version --output=json | jq -r '.clientVersion.version')

if [[ -f "$istiodir/out/linux_amd64/release/istio-sidecar.deb" ]]; then
  cp "$istiodir/out/linux_amd64/release/istio-sidecar.deb" $WORK_DIR/istio-sidecar.deb
else
  wget https://storage.googleapis.com/istio-release/releases/$istiover/deb/istio-sidecar.deb -O $WORK_DIR/istio-sidecar.deb
fi

cat <<EOF >$WORK_DIR/setup.sh
set -ex
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
