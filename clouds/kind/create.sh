#!/bin/bash

set -ex

NAME=${NAME:-kind}

kind create cluster --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $NAME
nodes:
- role: control-plane
- role: worker
- role: worker
EOF