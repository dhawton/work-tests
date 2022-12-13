#!/bin/bash

set -ex

NAME=${NAME:-daniel-cluster}
ZONE=${ZONE:-us-central1-c}

ip=$(gcloud compute instances describe $NAME-vm --zone=$ZONE --format json | jq -r '.networkInterfaces[0].accessConfigs[0].natIP')
ssh-keygen -R $ip || true

gcloud container clusters delete $NAME --zone=$ZONE --quiet
gcloud compute instances delete $NAME-vm --zone=$ZONE --quiet
