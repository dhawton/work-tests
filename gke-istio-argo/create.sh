#!/bin/bash

set -ex

dir="$( cd "$( dirname "$0" )" && pwd )"

VERSION=${VERSION:-latest}
export VERSION
NAME=${NAME:-daniel-cluster}
export NAME
TYPE=${TYPE:-e2-medium}
export TYPE
ZONE=${ZONE:-us-west1-c}
export ZONE
NUM_NODES=${NUM_NODES:-3}
export NUM_NODES

SKIP_INSTALL=${SKIP_INSTALL:-""}
DO_WATCH=${DO_WATCH:-""}
SKIP_CREATE=${SKIP_CREATE:-""}

if [[ -z "$SKIP_CREATE" ]]; then
    $dir/../clouds/gke/create.sh
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

set +ex
echo -n "Waiting on bootstrap to be ready... "
while true; do
    status=$(_k get application -n argocd app-of-apps -o jsonpath='{.status.sync.status}')
    if [[ -z "$status" || "$status" != "Synced" ]]; then
        sleep 1
    else
        break
    fi
done

echo -n "Waiting on istiod to be ready..."
while true; do
    status=$(_k get application -n argocd istiod-1-16-0 -o jsonpath='{.status.sync.status}')
    if [[ -z "$status" || "$status" != "Synced" ]]; then
        sleep 1
    else
        break
    fi
done

echo "Environment has been setup."
echo " Initial admin password is: $(_k -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
echo "Next steps:"
echo " - Sync istio ingress gateway application manually"
echo " - Install your apps"

