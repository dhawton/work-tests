#!/bin/bash

set -ex

VERSION=${VERSION:-latest}
NAME=${NAME:-daniel-cluster}
TYPE=${TYPE:-n2-standard-2}
ZONE=${ZONE:-us-central1-c}
NUM=${NUM:-2}

vmname="$NAME-vm$NUM"

#gcloud compute instances create "$vmname" --project=solo-test-236622 --zone=$ZONE --machine-type=$TYPE \
#  --network-interface=network-tier=PREMIUM,subnet=daniel-vpc --metadata=enable-oslogin=true --maintenance-policy=MIGRATE \
#  --provisioning-model=STANDARD --service-account=967359009029-compute@developer.gserviceaccount.com \
#  --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
#  --tags=http-server,https-server,daniel-vm \
#  --create-disk=auto-delete=yes,boot=yes,device-name=daniel-vm,image=projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20221011,mode=rw,size=100,type=projects/solo-test-236622/zones/$ZONE/diskTypes/pd-balanced \
#  --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any

echo "Waiting for VM to be ready..."
while true; do
  gcloud compute ssh $vmname --zone=$ZONE --command "echo 'hello'" && break
  sleep 5
done

gcloud compute ssh $vmname --zone=$ZONE --command="bash -s" <<EOF
sudo useradd -m -p $6$/.Upq3bnEu918/Rv$pZrikjRREcu002y7/m2WibDe0jrmcYi0jOaX3F6110kI5YDBtbPff3Jj0QYC7jiZH2ARskrfVUrafQ/HlmC9F1 -s /bin/bash daniel
sudo usermod -aG google-sudoers daniel
sudo mkdir ~daniel/.ssh
sudo bash -c 'curl https://github.com/dhawton.keys > ~daniel/.ssh/authorized_keys'
sudo chmod 700 ~daniel/.ssh
sudo chmod 600 ~daniel/.ssh/authorized_keys
sudo chown -R daniel:daniel ~daniel/.ssh
EOF
