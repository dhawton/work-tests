#!/bin/bash

set -ex

VERSION=${VERSION:-latest}
NAME=${NAME:-daniel-cluster}
TYPE=${TYPE:-n2-standard-2}
ZONE=${ZONE:-us-central1-c}
VM_IMAGE=${VM_IMAGE:-ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20221011}

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
  --max-pods-per-node "110" --num-nodes "2" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM --enable-ip-alias \
  --network "projects/solo-test-236622/global/networks/daniel-vpc" --subnetwork "projects/solo-test-236622/regions/$subnetwork/subnetworks/daniel-vpc" \
  --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks \
  --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair \
  --max-surge-upgrade 1 --max-unavailable-upgrade 0 --enable-shielded-nodes --node-locations $ZONE --workload-pool=solo-test-236622.svc.id.goog

gcloud compute instances create "$NAME-vm" --project=solo-test-236622 --zone=$ZONE --machine-type=$TYPE \
  --network-interface=network-tier=PREMIUM,subnet=daniel-vpc --metadata=enable-oslogin=true --maintenance-policy=MIGRATE \
  --provisioning-model=STANDARD --service-account=967359009029-compute@developer.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
  --tags=http-server,https-server,daniel-vm \
  --create-disk=auto-delete=yes,boot=yes,device-name=daniel-vm,image=projects/$VM_IMAGE,mode=rw,size=100,type=projects/solo-test-236622/zones/$ZONE/diskTypes/pd-balanced \
  --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any

echo "Waiting for VM to be ready..."
while true; do
  gcloud compute ssh $NAME-vm --zone=$ZONE --command "echo 'hello'" && break
  sleep 5
done

gcloud compute ssh $NAME-vm --zone=$ZONE --command="bash -s" <<EOF
sudo useradd -m -p $6$/.Upq3bnEu918/Rv$pZrikjRREcu002y7/m2WibDe0jrmcYi0jOaX3F6110kI5YDBtbPff3Jj0QYC7jiZH2ARskrfVUrafQ/HlmC9F1 -s /bin/bash daniel
sudo usermod -aG google-sudoers daniel
sudo mkdir ~daniel/.ssh
sudo bash -c 'curl https://github.com/dhawton.keys > ~daniel/.ssh/authorized_keys'
sudo chmod 700 ~daniel/.ssh
sudo chmod 600 ~daniel/.ssh/authorized_keys
sudo chown -R daniel:daniel ~daniel/.ssh
EOF