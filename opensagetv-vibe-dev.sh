#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; projects="$(cd "$root/.." && pwd)"
android_project="${OPENSAGETV_VIBE_ANDROID_PROJECT_ROOT:-$projects/opensagetv-vibe-android-client}"
android_project="$(cd "$android_project" && pwd)"
sagemc_project="${OPENSAGETV_VIBE_SAGEMC_PROJECT_ROOT:-$projects/opensagetv-vibe-sagemc}"
sagemc_project="$(cd "$sagemc_project" && pwd)"
tmdb_project="${OPENSAGETV_VIBE_TMDB_PROJECT_ROOT:-$projects/opensagetv-vibe-tmdb}"
tmdb_project="$(cd "$tmdb_project" && pwd)"
image="${OPENSAGETV_VIBE_BUILD_IMAGE:-opensagetv-vibe-build-env:u26-j11}"
container="${OPENSAGETV_VIBE_DEV_CONTAINER:-opensagetv-vibe-dev}"
ffmpeg_commit="${OPENSAGETV_VIBE_FFMPEG_COMMIT:-bf1b838f2ab88b4f8fd83443325c782ea0e0f7fa}"
ffmpeg_context="${OPENSAGETV_VIBE_FFMPEG_SOURCE_CONTEXT:-https://github.com/FFmpeg/FFmpeg.git?tag=n9.0.1&checksum=$ffmpeg_commit}"
legacy_builder_image=opensagetv-vibe-ffmpeg-mim-builder:9.0.1-v5
cmd="${1:-help}"
shift || true
forwarded_environment=(
  OPENDCT_TEST_HOST OPENDCT_TEST_PORT OPENDCT_TEST_ENCODER
  OPENSAGETV_VIBE_RELEASE_ID OPENSAGETV_VIBE_BUILD_IMAGE OPENSAGETV_VIBE_SERVER_IMAGE
  OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE
  FORCE_RUNTIME_IMAGE_BUILD
  OPENSAGETV_VIBE_RESTART_CYCLES OPENSAGETV_VIBE_RESTART_TIMEOUT_SECONDS
  OPENSAGETV_VIBE_STOP_TIMEOUT_SECONDS OPENSAGETV_VIBE_METRIC_SETTLE_SECONDS
  OPENSAGETV_VIBE_MAX_FD_GROWTH OPENSAGETV_VIBE_MAX_THREAD_GROWTH
  OPENSAGETV_VIBE_MAX_RSS_GROWTH_KIB
)

workspace_id() {
  local path="${1//\\//}"
  # Treat a Windows path and the same path as seen through WSL as one checkout.
  if [[ "$path" =~ ^/mnt/([A-Za-z])(/.*)$ ]]; then
    printf '%s:%s\n' "${BASH_REMATCH[1],,}" "${BASH_REMATCH[2]}"
  else
    printf '%s\n' "${path%/}"
  fi
}
projects_id="$(workspace_id "$projects")"
android_project_id="$(workspace_id "$android_project")"
sagemc_project_id="$(workspace_id "$sagemc_project")"
tmdb_project_id="$(workspace_id "$tmdb_project")"

image_build() {
  docker buildx build --load --progress=plain \
    --build-context "ffmpeg_src=$ffmpeg_context" \
    --build-context "logo_src=$projects/opensagetv-vibe-logo" \
    --build-arg "FFMPEG_COMMIT=$ffmpeg_commit" \
    -t "$image" "$root"
}
legacy_builder_remove() {
  if docker image inspect "$legacy_builder_image" >/dev/null 2>&1; then
    docker image rm "$legacy_builder_image" >/dev/null 2>&1 || true
  fi
}
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
  local desired_image current_image current_projects current_android current_sagemc current_tmdb running
  desired_image="$(docker image inspect "$image" --format '{{.Id}}')"
  if docker container inspect "$container" >/dev/null 2>&1; then
    current_image="$(docker inspect "$container" --format '{{.Image}}')"
    if [[ "$current_image" != "$desired_image" ]]; then
      echo "Recreating $container because the build image changed."
      container_remove
    else
      current_projects="$(docker inspect "$container" --format '{{index .Config.Labels "org.opensagetv.vibe.projects-root"}}')"
      if [[ "$current_projects" != "$projects_id" ]]; then
        echo "Recreating $container because the sibling workspace changed."
        container_remove
      else
        current_android="$(docker inspect "$container" --format '{{index .Config.Labels "org.opensagetv.vibe.android-project-root"}}')"
        if [[ "$current_android" != "$android_project_id" ]]; then
          echo "Recreating $container because the active Android checkout changed."
          container_remove
        else
          current_sagemc="$(docker inspect "$container" --format '{{index .Config.Labels "org.opensagetv.vibe.sagemc-project-root"}}')"
          if [[ "$current_sagemc" != "$sagemc_project_id" ]]; then
            echo "Recreating $container because the active SageMC checkout changed."
            container_remove
          else
            current_tmdb="$(docker inspect "$container" --format '{{index .Config.Labels "org.opensagetv.vibe.tmdb-project-root"}}')"
            if [[ "$current_tmdb" != "$tmdb_project_id" ]]; then
              echo "Recreating $container because the active TMDB checkout changed."
              container_remove
            fi
          fi
        fi
      fi
    fi
  fi
  if ! docker container inspect "$container" >/dev/null 2>&1; then
    docker create --name "$container" --init \
      --label org.opensagetv.vibe.role=unified-dev \
      --label "org.opensagetv.vibe.projects-root=$projects_id" \
      --label "org.opensagetv.vibe.android-project-root=$android_project_id" \
      --label "org.opensagetv.vibe.sagemc-project-root=$sagemc_project_id" \
      --label "org.opensagetv.vibe.tmdb-project-root=$tmdb_project_id" \
      --entrypoint sleep \
      -v opensagetv-vibe-gradle-cache:/work/.gradle \
      -v opensagetv-vibe-ccache:/work/.ccache \
      -v "$projects/opensagetv-vibe-core:/work/sagetv" \
      -v "$projects/opensagetv-vibe-ffmpeg-mim:/project" \
      -v "$projects/opensagetv-vibe-xmltv-import:/workspace/xmltv-import" \
      -v "$tmdb_project:/workspace/tmdb" \
      -v "$projects/opensagetv-vibe-container:/workspace/container" \
      -v "$projects/opensagetv-vibe-logo:/workspace/logo" \
      -v "$android_project:/workspace/android-client" \
      -v "$sagemc_project:/workspace/sagemc" \
      -v "$root:/workspace/release-manifest" \
      -v /var/run/docker.sock:/var/run/docker.sock \
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
    legacy_builder_remove
    ;;
  start) container_ensure; echo "$container is running" ;;
  stop)
    if docker container inspect "$container" >/dev/null 2>&1; then docker stop "$container" >/dev/null; fi
    ;;
  remove-dev) container_remove ;;
  shell) container_ensure; exec docker exec -it "$container" bash "$@" ;;
  all|core|ffmpeg-linux|ffmpeg-windows|ffmpeg-info|test-mim|xmltv|tmdb-test|tmdb-validate|tmdb-build|tmdb-all|tmdb-consumer-test|logo-info|logo-test|logo-validate|logo-build|logo-install|logo-all|android-info|android-test|android-validate|android-build|android-bundle|android-bundle-install|android-all|android-mcp|sagemc-test|sagemc-validate|sagemc-build|sagemc-all|runtime-stage|runtime-images|runtime-image-status|runtime-test|runtime-update-package|runtime-update-test|release|runtime-all|clean)
    container_ensure
    # Run the bind-mounted controller so orchestration changes do not require
    # rebuilding the dependency image.
    exec_environment=()
    for name in "${forwarded_environment[@]}"; do
      if [[ -n "${!name:-}" ]]; then
        exec_environment+=(--env "$name=${!name}")
      fi
    done
    interactive=()
    [[ "$cmd" != android-mcp ]] || interactive=(-i)
    exec docker exec "${interactive[@]}" "${exec_environment[@]}" "$container" \
      bash /workspace/release-manifest/scripts/dev-entrypoint.sh "$cmd" "$@"
    ;;
  *)
    echo "Usage: $0 {image|start|stop|remove-dev|all|core|ffmpeg-linux|ffmpeg-windows|ffmpeg-info|test-mim|xmltv|tmdb-test|tmdb-validate|tmdb-build|tmdb-all|tmdb-consumer-test|logo-info|logo-test|logo-validate|logo-build|logo-install|logo-all|android-info|android-test|android-validate|android-build|android-bundle|android-bundle-install|android-all|android-mcp|sagemc-test|sagemc-validate|sagemc-build|sagemc-all|runtime-stage|runtime-images|runtime-image-status|runtime-test|runtime-update-package|runtime-update-test|release|runtime-all|clean|shell}" >&2
    exit 2
    ;;
esac
