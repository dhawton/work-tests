#!/bin/bash

name=$1
if [[ "$name" == "" ]]; then
  echo "Syntax: $0 name"
  exit 1
fi

gcloud container clusters delete $name --zone=us-central1-c
rm $HOME/.kube/config-files/${name}.yaml &>/dev/null
