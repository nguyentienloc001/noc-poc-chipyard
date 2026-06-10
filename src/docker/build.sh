#!/usr/bin/env bash
# NoC-PoC: build the root-of-trust docker image.
#
# Usage:
#   ./build.sh                    # native arch of this machine
#   ./build.sh --arch amd64       # cross-build single arch (buildx + qemu)
#   ./build.sh --arch arm64
#   ./build.sh --arch multi       # amd64+arm64 manifest — BUILDS AND PUSHES
#                                 # (buildx cannot --load multi-arch locally)
#
# Env (optional, see .env.example):
#   DOCKERHUB_USER  - hub namespace; default tag becomes <user>/noc-poc-chipyard
#   DOCKER_IMAGE    - full image name override
set -euo pipefail

cd "$(dirname "$0")"

ARCH="native"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch) ARCH="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

IMAGE="${DOCKER_IMAGE:-${DOCKERHUB_USER:-local}/noc-poc-chipyard}"
GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
TAG="$(date +%Y%m%d)-${GIT_SHA}"

echo ">> Image: ${IMAGE}  Tags: ${TAG}, latest  Arch: ${ARCH}"

case "$ARCH" in
  native)
    docker build -t "${IMAGE}:${TAG}" -t "${IMAGE}:latest" .
    ;;
  amd64|arm64)
    docker buildx build --platform "linux/${ARCH}" \
      -t "${IMAGE}:${TAG}" -t "${IMAGE}:latest" --load .
    ;;
  multi)
    # multi-arch images must be pushed (cannot be loaded into local daemon)
    [[ -n "${DOCKERHUB_USER:-}" ]] || { echo "ERROR: DOCKERHUB_USER required for multi-arch push"; exit 1; }
    docker buildx build --platform linux/amd64,linux/arm64 \
      -t "${IMAGE}:${TAG}" -t "${IMAGE}:latest" --push .
    ;;
  *)
    echo "ERROR: --arch must be amd64|arm64|multi (or omit for native)"; exit 1 ;;
esac

echo ">> Done. Audit tools: docker run --rm ${IMAGE}:${TAG} /home/dev/versions.sh"
echo ">> Push single-arch: ./push.sh ${TAG}"
