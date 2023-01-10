#!/bin/bash

if [[ -z "$1" ]]; then
    echo "Usage: $0 <commit>"
    exit 1
fi

COMMIT=$1

set -x

cat <<EOF >/home/daniel/dev/istio/istio/istio.deps
[
  {
    "_comment": "",
    "name": "PROXY_REPO_SHA",
    "repoName": "proxy",
    "file": "",
    "lastStableSHA": "7f75f933249f61cf642f7b6c7e4ec83504dd1fcd"
  },
  {
    "_comment": "",
    "name": "ZTUNNEL_REPO_SHA",
    "repoName": "ztunnel",
    "file": "",
    "lastStableSHA": "$COMMIT"
  }
]
EOF

kind delete cluster --name auto
NAME=auto /home/daniel/dev/work-tests/clouds/kind/create.sh
sleep 5
pushd /home/daniel/dev/istio/istio
tag="ambient-$(date +%s)"
HUB=dhawton TAG=$tag make push
GOOS=linux GOARCH=amd64 LDFLAGS='-extldflags -static -s -w' common/scripts/gobuild.sh out/linux_amd64/ ./istioctl/cmd/istioctl ./pilot/cmd/pilot-discovery ./pkg/test/echo/cmd/client ./pkg/test/echo/cmd/server ./samples/extauthz/cmd/extauthz ./operator/cmd/operator ./cni/cmd/istio-cni ./cni/cmd/istio-cni-taint ./cni/cmd/install-cni ./tools/istio-iptables ./tools/bug-report
sleep 5
/home/daniel/dev/istio/istio/out/linux_amd64/istioctl install --set profile=ambient --set hub=dhawton --set tag=$tag --set values.global.imagePullPolicy=Always -y

if [[ $? -ne 0 ]]; then
    popd
    echo "Failed to install"
    exit 1
fi

echo "Success!"
popd