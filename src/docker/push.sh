#!/usr/bin/env bash
# NoC-PoC: push image to Docker Hub.
#
# Usage: ./push.sh [tag]        # default tag: latest (pushes both <tag> and latest if tag given)
#
# Required env (NEVER hardcode, NEVER commit — see .env.example):
#   DOCKERHUB_USER   - Docker Hub username
#   DOCKERHUB_TOKEN  - Access token (hub.docker.com > Account Settings > Security)
set -euo pipefail

: "${DOCKERHUB_USER:?ERROR: export DOCKERHUB_USER first (see .env.example)}"
: "${DOCKERHUB_TOKEN:?ERROR: export DOCKERHUB_TOKEN first (see .env.example)}"

IMAGE="${DOCKER_IMAGE:-${DOCKERHUB_USER}/noc-poc-chipyard}"
TAG="${1:-latest}"

# login via stdin — token never appears in argv/process list
echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USER}" --password-stdin

trap 'docker logout >/dev/null 2>&1 || true' EXIT

docker push "${IMAGE}:${TAG}"
if [[ "$TAG" != "latest" ]] && docker image inspect "${IMAGE}:latest" >/dev/null 2>&1; then
  docker push "${IMAGE}:latest"
fi

echo ">> Pushed ${IMAGE}:${TAG}"
echo ">> Pin digest vào docs/00 mục 6:"
docker buildx imagetools inspect "${IMAGE}:${TAG}" 2>/dev/null | grep -m1 Digest \
  || docker image inspect "${IMAGE}:${TAG}" --format 'Digest: {{index .RepoDigests 0}}'
