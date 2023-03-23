#!/bin/bash

# build and deploy the yapp Docker image

TAG=${TAG-$(git describe --tags --dirty)}

echo "building Docker image with tag $TAG"
docker build \
       --platform=linux/amd64 . \
       -t yapp \
       -t ghcr.io/fhcrc/yapp:latest \
       -t ghcr.io/fhcrc/yapp:$TAG

if [[ $1 = "push" ]]; then
    docker push ghcr.io/fhcrc/yapp:latest
    docker push ghcr.io/fhcrc/yapp:$TAG
fi
