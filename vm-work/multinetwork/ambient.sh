#!/bin/bash

ISTIODIR=~/dev/istio/istio ISTIOPROFILE=ambient TYPE=ambient ISTIOINSTALLOPTS="--set hub=dhawton --set tag=ambient" ./setup.sh