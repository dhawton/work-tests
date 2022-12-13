#!/bin/bash

ISTIODIR=~/dev/istio/istio ISTIOPROFILE=demo TYPE=nonambient ISTIOINSTALLOPTS="--set hub=dhawton --set tag=ambient" ./setup.sh