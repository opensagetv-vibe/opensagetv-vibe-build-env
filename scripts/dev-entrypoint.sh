#!/usr/bin/env bash
set -Eeuo pipefail

cmd="${1:-help}"
shift || true
core=/work/sagetv
fm=/project
xmltv=/workspace/xmltv-import
container=/workspace/container
manifest=/workspace/release-manifest
production_image="${OPENSAGETV_VIBE_SERVER_IMAGE:-ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11}"
debug_image="${OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE:-ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11-debug}"

validate_environment() {
  grep -q '^VERSION_ID="26.04"$' /etc/os-release
  test "${JAVA_HOME:-}" = /usr/lib/jvm/java-11-openjdk-amd64
  test "${SAGETV_FFMPEG_TAG:-}" = n9.0.1
  test "${SAGETV_FFMPEG_COMMIT:-}" = bf1b838f2ab88b4f8fd83443325c782ea0e0f7fa
  for key in linux64 win64; do
    test -d "/opt/sagetv/targets/$key/ct-ng"
    test -d "/opt/sagetv/targets/$key/ffbuild"
    test -s "/opt/sagetv/targets/$key/env.sh"
  done
  test -s /opt/sagetv/src/ffmpeg/configure
  test -d "$container/modern"
  command -v docker >/dev/null
  test -S /var/run/docker.sock
  docker info >/dev/null
}

ffmpeg_target() {
  local id="$1" key="$2" target="/opt/sagetv/targets/$2"
  rm -rf /opt/ct-ng /opt/ffbuild
  ln -s "$target/ct-ng" /opt/ct-ng
  ln -s "$target/ffbuild" /opt/ffbuild
  # shellcheck disable=SC1090
  source "$target/env.sh"
  export PATH="/opt/ct-ng/bin:$PATH" PKG_CONFIG_LIBDIR=/opt/ffbuild/lib/pkgconfig:/opt/ffbuild/share/pkgconfig
  cd "$fm"
  bash code/docker/build_target_unified.sh "$id"
}

run_mim_suite() {
  cd "$fm"
  mkdir -p output/test-results
  {
    bash code/mim/tests/run_init_tests.sh
    bash code/mim/tests/run_mim_tests.sh
    bash code/mim/tests/run_media_tests.sh
  } | tee output/test-results/non-android-suite.log
}

runtime_stage() {
  env \
    CORE_PACKAGE="$core/output/packages/sagetv-server-x86_64.tar.gz" \
    MIM_OUTPUT="$fm/output/linux-x64" \
    XMLTV_OUTPUT="$xmltv/output" \
    bash "$container/stage-artifacts.sh"
}

runtime_images() {
  env \
    SKIP_ARTIFACT_STAGE=true \
    CORE_SOURCE="$core" MIM_SOURCE="$fm" XMLTV_SOURCE="$xmltv" \
    OPENSAGETV_VIBE_SERVER_IMAGE="$production_image" \
    OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE="$debug_image" \
    bash "$container/build.sh"
}

runtime_test() {
  mkdir -p "$manifest/output/test-results"
  env \
    CORE_SOURCE="$core" \
    MIM_SOURCE="$fm" \
    XMLTV_SOURCE="$xmltv" \
    OPENDCT_STATUS_FILE="$manifest/output/test-results/opendct-live.status" \
    OPENSAGETV_VIBE_SERVER_IMAGE="$production_image" \
    OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE="$debug_image" \
    bash "$container/tests/runtime-validation.sh" | tee "$manifest/output/test-results/runtime-validation.log"
}

release_package() {
  env \
    CORE_SOURCE="$core" MIM_SOURCE="$fm" XMLTV_SOURCE="$xmltv" CONTAINER_SOURCE="$container" \
    OPENSAGETV_VIBE_SERVER_IMAGE="$production_image" \
    OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE="$debug_image" \
    bash "$manifest/scripts/package-release.sh"
}

declare -a report_rows=()
current_stage=""
report="$manifest/output/BUILD_REPORT.md"

add_result() {
  report_rows+=("$1|$2")
}

write_report() {
  local status="$1" rc="${2:-0}" release_path="not assembled" opendct="not run"
  [[ ! -s "$manifest/output/RELEASE_PATH" ]] || release_path="$(cat "$manifest/output/RELEASE_PATH")"
  [[ ! -s "$manifest/output/test-results/opendct-live.status" ]] || opendct="$(cat "$manifest/output/test-results/opendct-live.status")"
  {
    echo '# OpenSageTV Vibe unified build report'
    echo
    echo "$status"
    echo
    echo "- Base: Ubuntu 26.04 (linux/amd64)"
    echo "- Kernel: $(uname -srmo)"
    echo "- GCC: $(gcc --version | head -1)"
    echo "- G++: $(g++ --version | head -1)"
    echo "- Java: $(java -version 2>&1 | head -1)"
    echo "- Docker client: $(docker --version)"
    echo "- Build environment: ${OPENSAGETV_VIBE_BUILD_ENV_VERSION:-unknown}"
    echo "- FFmpeg: ${SAGETV_FFMPEG_TAG:-unknown} (${SAGETV_FFMPEG_COMMIT:-unknown})"
    echo "- Production image: $production_image"
    echo "- Debug image: $debug_image"
    echo "- Release directory: $release_path"
    echo "- OpenDCT live channel scan: $opendct"
    [[ "$rc" == 0 ]] || echo "- Exit code: $rc"
    echo
    echo '| Component | Result |'
    echo '|---|---|'
    local row label result
    for row in "${report_rows[@]}"; do
      label="${row%%|*}"; result="${row#*|}"
      echo "| $label | $result |"
    done
  } > "$report"
}

handle_error() {
  local rc="$1"
  trap - ERR
  [[ -z "$current_stage" ]] || add_result "$current_stage" FAIL
  write_report 'BUILD FAILED' "$rc"
  echo "BUILD FAILED during: ${current_stage:-unknown stage}" >&2
  exit "$rc"
}

run_stage() {
  current_stage="$1"
  shift
  echo "===== $current_stage ====="
  "$@"
  add_result "$current_stage" PASS
  current_stage=""
}

run_runtime_all() {
  runtime_stage
  runtime_images
  runtime_test
  release_package
}

case "$cmd" in
  core) cd "$core"; exec bash tests/linux-modern/all.sh "$@" ;;
  ffmpeg-linux) ffmpeg_target linux-x64 linux64 ;;
  ffmpeg-windows) ffmpeg_target windows-x64 win64 ;;
  ffmpeg-info)
    validate_environment
    echo "build_environment=${OPENSAGETV_VIBE_BUILD_ENV_VERSION:-unknown}"
    echo "ffmpeg_toolchain=${OPENSAGETV_VIBE_FFMPEG_TOOLCHAIN:-unknown}"
    echo "ffmpeg_tag=${SAGETV_FFMPEG_TAG:-unknown}"
    echo "ffmpeg_commit=${SAGETV_FFMPEG_COMMIT:-unknown}"
    for key in linux64 win64; do
      test -d "/opt/sagetv/targets/$key/ct-ng"
      test -d "/opt/sagetv/targets/$key/ffbuild"
      echo "$key=PASS"
    done
    docker info --format 'docker_server={{.ServerVersion}}'
    echo 'runtime_container_source=PASS'
    ;;
  test-mim) run_mim_suite ;;
  xmltv) cd "$xmltv"; exec bash scripts/build.sh ;;
  runtime-stage) runtime_stage ;;
  runtime-images) runtime_images ;;
  runtime-test) runtime_test ;;
  release) release_package ;;
  runtime-all) run_runtime_all ;;
  clean)
    cd "$core"; bash tests/linux-modern/clean.sh
    rm -rf "$fm/output" "$manifest/output" "$xmltv/build" "$xmltv/output" "$container/artifacts"
    echo 'Build outputs cleaned; reusable container, cache, and release images retained'
    ;;
  all)
    mkdir -p "$manifest/output/test-results"
    rm -f "$report" "$manifest/output/CORE_BUILD_REPORT.md" "$manifest/output/RELEASE_PATH"
    trap 'handle_error $?' ERR
    run_stage 'Unified environment validation' validate_environment
    run_stage 'SageTV Core clean build, native tests, and package' bash -c "cd '$core' && bash tests/linux-modern/all.sh"
    run_stage 'FFmpeg/MIM Linux x64 build' ffmpeg_target linux-x64 linux64
    run_stage 'FFmpeg/MIM Windows x64 build' ffmpeg_target windows-x64 win64
    run_stage 'MIM lifecycle and media-integrity tests' run_mim_suite
    run_stage 'XMLTV compile, regression tests, and package' bash -c "cd '$xmltv' && bash scripts/build.sh"
    run_stage 'Runtime artifact staging and integrity' runtime_stage
    run_stage 'Production and debug runtime image builds' runtime_images
    run_stage 'Clean runtime, restart soak, discovery, XMLTV, OpenDCT, and cleanup validation' runtime_test
    run_stage 'Manifest, checksums, SPDX SBOMs, release bundle, and offline exports' release_package
    cp "$core/output/BUILD_REPORT.md" "$manifest/output/CORE_BUILD_REPORT.md"
    write_report 'BUILD PASSED'
    trap - ERR
    echo 'BUILD PASSED'
    ;;
  shell) exec bash "$@" ;;
  help|*)
    echo 'Commands: all core ffmpeg-linux ffmpeg-windows ffmpeg-info test-mim xmltv runtime-stage runtime-images runtime-test release runtime-all clean shell'
    ;;
esac
