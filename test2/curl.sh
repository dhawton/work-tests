#!/bin/bash
root_url="http://172.31.62.168"
curl -X POST "$(glooctl proxy url)/post" -H "Origin: $root_url" -i
curl -X POST "$(glooctl proxy url)/post" -H "Origin: http://example.com" -i
curl -X POST "$(glooctl proxy url)/post" -H -i