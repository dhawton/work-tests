#!/bin/bash

. .shared.sh

cluster="cluster-1"
function k() {
    kubectl --context $cluster $@
}

echo "Working on $cluster"
# Create the deployment
k delete ns bookinfo
echo "Creating bookinfo namespace"
k create ns bookinfo
echo "Labeling ns with istio-injection=enabled"
k label ns bookinfo istio-injection=enabled

echo "Creating deployment"
k -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.11.5/samples/bookinfo/platform/kube/bookinfo.yaml
k -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.11.5/samples/bookinfo/networking/bookinfo-gateway.yaml
k -n bookinfo delete deployment reviews-v3 -n bookinfo

# Wait for pods
echo "Waiting for pods to be ready"
wait_for_pod_ready $cluster bookinfo

cluster="cluster-2"

echo ""
echo "Working on $cluster"

k delete ns bookinfo
echo "Creating bookinfo namespace"
k create ns bookinfo
echo "Labeling ns with istio-injection=enabled"
k label ns bookinfo istio-injection=enabled

echo "Creating deployment"
k -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.11.5/samples/bookinfo/platform/kube/bookinfo.yaml
k -n bookinfo delete deployment reviews-v1 reviews-v2 -n bookinfo

echo "Waiting for pods to be ready"
wait_for_pod_ready $cluster bookinfo

echo ""
echo "Done"

echo "Load product page for cluster 1"
CLUSTER_1_INGRESS_ADDRESS=$(kubectl --context cluster-1 get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo http://$CLUSTER_1_INGRESS_ADDRESS/productpage