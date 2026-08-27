#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; projects="$(cd "$root/.." && pwd)"
image="${OPENSAGETV_VIBE_BUILD_IMAGE:-opensagetv-vibe-build-env:u26-j11}"
container="${OPENSAGETV_VIBE_DEV_CONTAINER:-opensagetv-vibe-dev}"
cmd="${1:-help}"
shift || true

image_build() { docker build -t "$image" "$root"; }
image_ensure() {
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "Build image $image is missing; building it once."
    image_build
  fi
}
container_remove() {
  if docker container inspect "$container" >/dev/null 2>&1; then
    docker rm -f -v "$container" >/dev/null
  fi
}
container_ensure() {
  image_ensure
  local desired_image current_image running
  desired_image="$(docker image inspect "$image" --format '{{.Id}}')"
  if docker container inspect "$container" >/dev/null 2>&1; then
    current_image="$(docker inspect "$container" --format '{{.Image}}')"
    if [[ "$current_image" != "$desired_image" ]]; then
      echo "Recreating $container because the build image changed."
      container_remove
    fi
  fi
  if ! docker container inspect "$container" >/dev/null 2>&1; then
    docker create --name "$container" --init \
      --label org.opensagetv.vibe.role=unified-dev \
      --entrypoint sleep \
      -v opensagetv-vibe-gradle-cache:/work/.gradle \
      -v "$projects/opensagetv-vibe-core:/work/sagetv" \
      -v "$projects/opensagetv-vibe-ffmpeg-mim:/project" \
      -v "$projects/opensagetv-vibe-xmltv-import:/workspace/xmltv-import" \
      -v "$root:/workspace/release-manifest" \
      "$image" infinity >/dev/null
  fi
  running="$(docker inspect "$container" --format '{{.State.Running}}')"
  if [[ "$running" != true ]]; then docker start "$container" >/dev/null; fi
}

case "$cmd" in
  image)
    previous_image="$(docker image inspect "$image" --format '{{.Id}}' 2>/dev/null || true)"
    image_build
    desired_image="$(docker image inspect "$image" --format '{{.Id}}')"
    if docker container inspect "$container" >/dev/null 2>&1 &&
       [[ "$(docker inspect "$container" --format '{{.Image}}')" != "$desired_image" ]]; then
      container_remove
    fi
    if [[ -n "$previous_image" && "$previous_image" != "$desired_image" ]]; then
      docker image rm "$previous_image" >/dev/null 2>&1 || true
    fi
    ;;
  start) container_ensure; echo "$container is running" ;;
  stop)
    if docker container inspect "$container" >/dev/null 2>&1; then docker stop "$container" >/dev/null; fi
    ;;
  remove-dev) container_remove ;;
  shell) container_ensure; exec docker exec -it "$container" bash "$@" ;;
  all|core|ffmpeg-linux|ffmpeg-windows|test-mim|xmltv|clean)
    container_ensure
    # Run the bind-mounted controller so orchestration changes do not require
    # rebuilding the dependency image.
    exec docker exec "$container" bash /workspace/release-manifest/scripts/dev-entrypoint.sh "$cmd" "$@"
    ;;
  *)
    echo "Usage: $0 {image|start|stop|remove-dev|all|core|ffmpeg-linux|ffmpeg-windows|test-mim|xmltv|clean|shell}" >&2
    exit 2
    ;;
esac
