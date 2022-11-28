#!/bin/bash

set -ex

VERSION=${VERSION:-latest}
NAME=${NAME:-daniel-cluster}
TYPE=${TYPE:-e2-medium}
ZONE=${ZONE:-us-west1-c}
NUM_NODES=${NUM_NODES:-3}

versions=$(gcloud container get-server-config --zone=$ZONE --format=json)

if [[ $VERSION == "latest" ]]; then
    VERSION=$(echo $versions | jq -r '.channels[] | select (.channel == "REGULAR") | .validVersions[0]')
    echo "Selected version $VERSION"
elif [[ $VERSION == "default" ]]; then
    VERSION=$(echo $versions | jq -r '.channels[] | select (.channel == "REGULAR") | .defaultVersion')
    echo "Selected version $VERSION"
fi

subnetwork=${SUBNETWORK}
if [[ -z "$subnetwork" ]]; then
    subnetwork=$(echo $ZONE | awk -F- '{ print $1 "-" $2 }')
fi

gcloud beta container --project "solo-test-236622" clusters create "$NAME" \
    --zone "$ZONE" --no-enable-basic-auth --cluster-version "$VERSION" \
    --release-channel "regular" --machine-type "$TYPE" --image-type "UBUNTU_CONTAINERD" \
    --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true \
    --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
    --max-pods-per-node "110" --num-nodes "$NUM_NODES" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM --enable-ip-alias \
    --network "projects/solo-test-236622/global/networks/daniel-vpc" --subnetwork \
    "projects/solo-test-236622/regions/$subnetwork/subnetworks/daniel-vpc" \
    --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair \
    --max-surge-upgrade 1 --max-unavailable-upgrade 0 --enable-shielded-nodes --node-locations "us-west1-c" \
    --workload-pool=solo-test-236622.svc.id.goog \
    --node-labels purpose=product_development,team=engineering,created-by=daniel_hawton \
    --labels purpose=product_development,team=engineering,created-by=daniel_hawton 
