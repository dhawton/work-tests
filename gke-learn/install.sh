#!/bin/bash

helm repo add glooe https://storage.googleapis.com/gloo-ee-helm
helm repo update
helm install gloo glooe/gloo-ee --namespace gloo-system \
  --create-namespace --set-string license_key=$GLOO_EDGE_LICENSE_KEY --version v1.8.13

