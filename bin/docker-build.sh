#!/bin/bash

# build and deploy the yapp Docker image

TAG=${TAG-$(git log -1 --pretty=format:%h)}

echo "building Docker image with tag $TAG"
docker build \
       --platform=linux/amd64 . \
       -t yapp
       # -t "docker.labmed.uw.edu/uwlabmed/userbase:${TAG:?}" \
       # -t "docker.labmed.uw.edu/uwlabmed/userbase:latest" \
       # --build-arg VERSION="$TAG"

