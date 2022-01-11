#!/bin/bash

clustername=daniel-eks
region=us-west-2
sshpubkey=$HOME/.ssh/id_rsa.pub
nodetype=t3a.large
nodes=2
kubeconfig=$HOME/.kube/config-files/eks-${clustername}.yaml
kubernetesversion=1.21

if [[ "$1" -ne "" ]]; then
  clustername=$1
fi

eksctl create cluster --name "$clustername" --region "$region" --version $kubernetesversion \
    --managed --node-type $nodetype --nodes $nodes --node-volume-size --kubeconfig $kubeconfig
