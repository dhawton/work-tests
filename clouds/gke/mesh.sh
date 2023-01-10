#!/bin/bash

clusters=(daniel-mgmt daniel-cluster1 daniel-cluster2)
ZONE=${ZONE:-us-west1-c}
TYPE=${TYPE:-e2-standard-4}

for cluster in "${clusters[@]}"; do
	if [[ "$1" == "down" ]]; then
		yes | gcloud container clusters delete $cluster --zone=$ZONE
	elif [[ "$1" == "up" ]]; then
		NAME=$cluster TYPE=$type ZONE=$ZONE $HOME/dev/work-tests/clouds/gke/create.sh
	else
		echo "Unknown command: $1"
		exit 1
	fi
done
