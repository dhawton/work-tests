#!/bin/bash

ip=$(glooctl proxy address | awk -F: '{ print $1 }')
secretname=$1

if [[ $secretname == "" ]]; then
  secretname="vs-test"
fi

openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout tls.key -out tls.crt -subj "/CN=$ip"
kubectl create secret tls $secretname --key tls.key --cert tls.cert -n gloo-system