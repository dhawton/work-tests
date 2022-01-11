#!/bin/bash
last=$(cat .ver)
last=$((last+1))
docker build . -t harbor.hawton.haus/lab/edge-auth-service:v$last
docker push harbor.hawton.haus/lab/edge-auth-service:v$last
kubectl set image deployment/sample-auth sample-auth=harbor.hawton.haus/lab/edge-auth-service:v$last
echo $last > .ver