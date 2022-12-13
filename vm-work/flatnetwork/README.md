# VM Setup Scripts

## Ambient Setup

Assumes that istio is cloned to ~/dev/istio/istio and has binaries built.

```bash
ISTIODIR=~/dev/istio/istio ISTIOBINARY=~/dev/istio/istio/out/linux_amd64/istioctl ISTIOPROFILE=ambient ISTIOINSTALLOPTS="--set hub=dhawton --set tag=ambient" bash setup.sh
```