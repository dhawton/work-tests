#!/bin/bash

set -ex

TMPDIR=$(mktemp -d)
GLOO_MESH_VERSION=${GLOO_MESH_VERSION:-2.1.1}

export ISTIO_IMAGE_REPO=istio
export ISTIO_VERSION=${ISTIO_VERSION:-1.15.3}
export REVISION=${REVISION:-1-15}
export MGMT=${MGMT:-mgmt}
export CLUSTER1=${CLUSTER1:-cluster1}
export CLUSTER2=${CLUSTER2:-cluster2}
export REPO=${REPO}
export ISTIO_IMAGE="$ISTIO_VERSION-solo"

if [[ -z "$REPO" && "$REVISION" == "1-15" ]]; then
    REPO=$SOLO_115
elif [[ -z "$REPO" && "$REVISION" == "1-14" ]]; then
    REPO=$SOLO_114
fi

if [[ -z "$REPO" ]]; then
    echo "REPO was null and we were not able to determine an appropriate value."
    exit 1
fi

if [[ -z "$GLOO_MESH_LICENSE_KEY" ]]; then
    echo "No license key detected."
    exit 1
fi

pushd $TMPDIR

#curl -sL https://run.solo.io/meshctl/install | sh -

function m() {
    $HOME/.local/bin/meshctl $@
}

m install --kubecontext "$MGMT" --set mgmtClusterName="$MGMT" --license $GLOO_MESH_LICENSE_KEY --set global.cluster=$MGMT

echo "Waiting for deployment"
kubectl --context "$MGMT" rollout status -n gloo-mesh deployment/gloo-mesh-mgmt-server
kubectl --context "$MGMT" rollout status -n gloo-mesh deployment/gloo-mesh-redis
kubectl --context "$MGMT" rollout status -n gloo-mesh deployment/gloo-mesh-ui

curl -0L https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/gloo-mesh/getting-started/2.1/gs-multi.yaml > gs-multi.yaml
envsubst < gs-multi.yaml > gs-multi-values.yaml

function cluster_register() {
    context=$1
    m cluster register --kubecontext "$MGMT" --remote-context "$context" $context --version $GLOO_MESH_VERSION --gloo-mesh-agent-chart-values gs-multi-values.yaml

    echo "Waiting for gloo-mesh-agent"
    while true; do
        # Wait for gloo-mesh-agent pod to be ready
        if kubectl get pod -n gloo-mesh --context "$context" | grep -q gloo-mesh-agent | grep -q Running; then
            break
        fi
        kubectl get pod -n gloo-mesh --context "$context"
        echo ""
        sleep 5
    done

    while true; do
        # wait for istiod to be ready
        if kubectl get pod -n istio-system --context "$context" | grep -q istiod | grep -q Running; then
            break
        fi
        kubectl get pod -n istio-system --context "$context"
        echo ""
        sleep 5
    done
}

cluster_register $CLUSTER1
cluster_register $CLUSTER2

meshctl check --kubecontext $MGMT