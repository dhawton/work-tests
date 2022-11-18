#!/bin/bash

set -ex

VERSION=${VERSION:-latest}
NAME=${NAME:-daniel-cluster}
TYPE=${TYPE:-e2-medium}
ZONE=${ZONE:-us-west1-c}
NUM_NODES=${NUM_NODES:-3}
SKIP_INSTALL=${SKIP_INSTALL:-""}
DO_WATCH=${DO_WATCH:-""}
SKIP_CREATE=${SKIP_CREATE:-""}

versions=$(gcloud container get-server-config --zone=$ZONE --format=json)

if [[ $VERSION == "latest" ]]; then
    VERSION=$(echo $versions | jq -r '.channels[] | select (.channel == "REGULAR") | .validVersions[0]')
    echo "Selected version $VERSION"
elif [[ $VERSION == "default" ]]; then
    VERSION=$(echo $versions | jq -r '.channels[] | select (.channel == "REGULAR") | .defaultVersion')
    echo "Selected version $VERSION"
fi

subnetwork=${SUBNETWORK}
if [[ -z "$subnetwork" ]]; then
    subnetwork=$(echo $ZONE | awk -F- '{ print $1 "-" $2 }')
fi

if [[ -z "$SKIP_CREATE" ]]; then
    gcloud beta container --project "solo-test-236622" clusters create "$NAME" \
        --zone "$ZONE" --no-enable-basic-auth --cluster-version "$VERSION" \
        --release-channel "regular" --machine-type "$TYPE" --image-type "UBUNTU_CONTAINERD" \
        --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true \
        --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
        --max-pods-per-node "110" --num-nodes "$NUM_NODES" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM --enable-ip-alias \
        --network "projects/solo-test-236622/global/networks/daniel-vpc" --subnetwork \
        "projects/solo-test-236622/regions/$subnetwork/subnetworks/daniel-vpc" \
        --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks \
        --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair \
        --max-surge-upgrade 1 --max-unavailable-upgrade 0 --enable-shielded-nodes --node-locations "us-west1-c" \
        --workload-pool=solo-test-236622.svc.id.goog \
        --node-labels purpose=product_development,team=engineering,created-by=daniel_hawton
fi

if [[ ! -z "$SKIP_INSTALL" ]]; then
    echo "Done."
    exit 0
fi

context=$(kubectl config current-context)

function _k() {
    kubectl --context $context "$@"
}

_k create namespace argocd || true
_k apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for argocd server to be ready before we deploy our application
_k rollout status -n argocd deployment/argocd-server

if [[ -z "$CLOUDFLARE_TOKEN" ]]; then
    CLOUDFLARE_TOKEN=$(cat ~/.cloudflare-token)
    if [[ -z "$CLOUDFLARE_TOKEN" ]]; then
        echo "WARNING: No cloudflare token found, you'll need to edit the cloudflare-api-token secret manually"
    fi
fi

_k create ns cert-manager || true
_k apply -n argocd -f argo/app-of-apps.yaml
_k apply -n cert-manager -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
type: Opaque
stringData:
  api-token: "$CLOUDFLARE_TOKEN"
EOF

if [[ ! -z "$DO_WATCH" ]]; then
    #kubectl --context gke_solo-test-236622_us-west1-c_daniel-cluster -n argocd get applications app-of-apps -o jsonpath='{.status.sync}' | jq -r .
    watch -n 1 -d "kubectl --context $context get -n argocd applications app-of-apps -o jsonpath='{.status.sync}' | jq -r ."
else
    echo "Done. Run the following to watch the deployment:"
    echo "  kubectl --context $context -n argocd get applications app-of-apps -o jsonpath='{.status.sync.status}' -w"
fi
