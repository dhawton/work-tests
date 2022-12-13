#!/bin/bash

set -ex
kubectl create namespace sample
kubectl label namespace sample istio-injection=enabled
kubectl apply -n sample -f ~/istio/samples/helloworld/helloworld.yaml
kubectl rollout status deployment/helloworld-v1 -n sample
kubectl rollout status deployment/helloworld-v2 -n sample