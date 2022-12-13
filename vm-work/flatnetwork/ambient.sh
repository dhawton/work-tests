#!/bin/bash

ISTIODIR=~/dev/istio/istio ISTIOPROFILE=ambient TYPE=cluster ISTIOINSTALLOPTS="--set hub=dhawton --set tag=ambient" ./setup.sh
