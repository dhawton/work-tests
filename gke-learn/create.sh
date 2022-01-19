#!/bin/bash

name=$1
version=$2
nodes=$3
ntype=$4

if [[ "$ZONE" == "" ]]; then
  ZONE="us-central1-c"
fi

if [[ "$ntype" == "" ]]; then
  echo "Syntax: create.sh name version nodes nodetype"
  exit 1
fi

if [[ "$version" == "latest" ]]; then
  version=$(gcloud container get-server-config --zone $ZONE --format json | jq -r '.validMasterVersions[0]')
fi

gcloud container clusters create "$name" --cluster-version "$version" --disk-size 100 \
  --num-nodes=$nodes --machine-type=$ntype --zone=$ZONE --network daniel-vpc \
  --labels=solo-io_owner=daniel_hawton_solo_io

KUBECONFIG=$HOME/.kube/config-files/${name}.yaml gcloud container clusters get-credentials ${name} \
  --zone=$ZONE
