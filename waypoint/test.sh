#!/bin/bash

set -x

COMMITS=(
    ffe9b5e0d16e758cd8fd9a0cc2e3b19872d4f576
    ae89e193b5e56f34207663b152c4ddd862a1048c
    eb89625385aa75ec0f19b97ec28f5d081cca4d23
    7f0f6996bb6618bfa1a3aa3825e1a711a96b133a
    bd72b58e86fd4f2434c4e1376d34f95dd0c6b0f0
    e12112c07e4771ac66a4f2597c585fedd24a94aa
    e18d05b0ec6e26c4b766bed0ca3b8d4fbe86608d
    ec1d9170f7fe1b222eebbf99cadebc03f7171a4b
)

for commit in "${COMMITS[@]}"; do
    bash test-commit.sh $commit
    if [[ $? -eq 0 ]]; then
        echo "Commit $commit is good."
        exit 0
    fi
done