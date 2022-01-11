#!/bin/bash

# Load shared functions
. .shared.sh

MGMT_CONTEXT=mgmt-cluster
REMOTE_CONTEXTS=("cluster-1" "cluster-2")

for ctx in "${REMOTE_CONTEXTS[@]}"; do
  install_istio $ctx
done

echo "Installing Gloo Mesh Enterprise"
meshctl install enterprise --kubecontext=$MGMT_CONTEXT --license $GLOO_MESH_LICENSE_KEY
check_fail $? "Failed to install Gloo Mesh Enterprise"

wait_for_pod_ready $MGMT_CONTEXT gloo-mesh

echo "Checking to ensure management plane is correctly installed (can take a minute)"
meshctl check server --kubecontext $MGMT_CONTEXT
check_fail $? "Management plane is not correctly installed"

for ctx in "${REMOTE_CONTEXTS[@]}"; do
  register_remote_cluster $MGMT_CONTEXT $ctx
  verify_registered $MGMT_CONTEXT $ctx
done

create_virtual_mesh $MGMT_CONTEXT "${REMOTE_CONTEXTS[@]}"