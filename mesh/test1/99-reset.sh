#!/bin/bash

# Hardcoded = bad, but.. :shrug:
ips=("172.31.62.168" "172.31.62.20" "172.31.62.172")
names=("mgmt-cluster" "cluster-1" "cluster-2")

for i in "${!ips[@]}"; do
  echo "$i Uninstalling k3s on ${ips[$i]}"
  kossh uninstall ${ips[$i]}
  echo "$i Installing k3s on ${ips[$i]}"
  kossh ${ips[$i]} ${names[$i]}
  echo "$i Done"
done