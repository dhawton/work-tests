#!/bin/bash

ip=$(glooctl proxy address | awk -F: '{print $1}')

while true; do
  curl -k https://$ip/httpbin/get &>/dev/null
  date
done