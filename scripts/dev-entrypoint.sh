#!/usr/bin/env bash
set -Eeuo pipefail

cmd="${1:-help}"
shift || true
core=/work/sagetv
fm=/project
ffmpeg_plugin=/workspace/ffmpeg-plugin
core_mcp=/workspace/core-mcp-plugin
xmltv=/workspace/xmltv-import
tmdb=/workspace/tmdb
container=/workspace/container
logo=/workspace/logo
android=/workspace/android-client
sagemc=/workspace/sagemc
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
  test -x /opt/java/jdk17/bin/java
  test -x /opt/java/jdk8/bin/java
  test -x /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager
  test -x /opt/android-sdk/platform-tools/adb
  test -s "${BUNDLETOOL_JAR:?BUNDLETOOL_JAR is not configured}"
  test "$(/opt/java/jdk17/bin/java -jar "$BUNDLETOOL_JAR" version)" = 1.18.3
  for package in \
    build-tools/29.0.2 build-tools/36.0.0 \
    platforms/android-29 platforms/android-36 ndk/21.0.6113669; do
    test -d "/opt/android-sdk/$package"
  done
  test -x /opt/opensagetv-vibe/android-python/bin/python3
  test -x /opt/opensagetv-vibe/logo-python/bin/python3
  test -f "$logo/scripts/logo_pipeline.py"
  /opt/opensagetv-vibe/logo-python/bin/python3 -c 'import cairosvg, PIL'
  test -f "$android/dev.sh"
  test -f "$android/docker/entrypoint.sh"
  test -f "$android/source/dev/gradlew"
  test -f "$sagemc/source/dev/SageMC_169.xml"
  test -f "$tmdb/source/main/java/org/opensagetv/vibe/tmdb/TmdbMetadataService.java"
  test -f "$ffmpeg_plugin/src/main/java/org/opensagetv/vibe/ffmpeg/SageTVFFmpegPlugin.java"
  test -f "$core_mcp/src/main/java/org/opensagetv/vibe/coremcp/SageTVCoreMcpPlugin.java"
  command -v docker >/dev/null
  docker buildx version >/dev/null
  command -v smbclient >/dev/null
  command -v ccache >/dev/null
  for command in ffmpeg ffprobe dvdauthor spumux spuunmux convert identify fc-match; do
    command -v "$command" >/dev/null
  done
  test -S /var/run/docker.sock
  docker info >/dev/null
}

android_environment() {
  env \
    JAVA_HOME=/opt/java/jdk17 \
    JDK_HOME=/opt/java/jdk17 \
    GRADLE_USER_HOME=/work/.gradle/android \
    ANDROID_USER_HOME="$android/adb" \
    ADB_VENDOR_KEYS="$android/adb/adbkey" \
    SAGETV_WORKSPACE="$android" \
    SAGETV_DEV_SOURCE="$android/source/dev" \
    SAGETV_EXISTING_SOURCE="$android/source/existing" \
    SAGETV_MCP_CONFIG="$android/config/firetv.toml" \
    SAGETV_ARTIFACT_DIR="$android/artifacts/firetv" \
    OPENSAGETV_VIBE_BUILD_ENV_ROOT="$manifest" \
    PYTHONPATH="$android/mcp/src" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/java/jdk17/bin:/opt/opensagetv-vibe/android-python/bin:$PATH" \
    "$@"
}

logo_environment() {
  env \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/opensagetv-vibe/logo-python/bin:$PATH" \
    "$@"
}

logo_pipeline() {
  logo_environment /opt/opensagetv-vibe/logo-python/bin/python3 \
    "$logo/scripts/logo_pipeline.py" "$@" --android-root "$android"
}

logo_build_install() {
  logo_pipeline all
}

android_prepare() {
  logo_build_install
  android_environment python3 "$android/scripts/repair_dev_gradle.py" --workspace "$android"
}

android_command() {
  local action="$1"
  shift
  android_environment bash "$android/docker/entrypoint.sh" "$action" "$@"
}

android_info() {
  validate_environment
  echo "default_java=$(java -version 2>&1 | head -1)"
  echo "android_java=$(/opt/java/jdk17/bin/java -version 2>&1 | head -1)"
  echo "android_legacy_java=$(/opt/java/jdk8/bin/java -version 2>&1 | head -1)"
  echo "android_sdk_root=$ANDROID_SDK_ROOT"
  android_environment /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --list_installed \
    | grep -E '^(  )?(build-tools;29\.0\.2|build-tools;36\.0\.0|ndk;21\.0\.6113669|platform-tools|platforms;android-(29|36))([[:space:]]|$)'
  /opt/android-sdk/platform-tools/adb version | head -2
  echo "android_bundletool=$(/opt/java/jdk17/bin/java -jar "$BUNDLETOOL_JAR" version)"
  echo "smbclient=$(smbclient --version)"
  echo "dvd_authoring_dvdauthor=$(dvdauthor --version 2>&1 | head -1)"
  echo "dvd_authoring_spumux=$(spumux --version 2>&1 | head -1)"
  echo "dvd_authoring_imagemagick=$(convert -version 2>&1 | head -1)"
  echo "dvd_authoring_font=$(fc-match 'DejaVu Sans' | head -1)"
  logo_environment python3 -c 'import importlib.metadata as m; print("logo_cairosvg=" + m.version("CairoSVG")); print("logo_pillow=" + m.version("Pillow"))'
  android_environment python3 -c 'import importlib.metadata as m; import mcp; print("android_mcp=" + m.version("mcp"))'
  echo 'android_toolchain=PASS'
}

run_android_suite() {
  mkdir -p "$manifest/output/test-results"
  {
    android_prepare
    android_command test
    android_command validate
    android_command build
    android_command bundle
    test -s "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apk"
    test -s "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apk.sha256"
    test -s "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.aab"
    test -s "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apks"
    test -s "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-release-candidate.aab"
    echo 'ANDROID CLIENT SUITE PASSED'
  } | tee "$manifest/output/test-results/android-client.log"
}

android_clean() {
  if [[ -x "$android/source/dev/gradlew" ]]; then
    android_environment bash -c "cd '$android/source/dev' && ./gradlew --no-daemon clean"
  fi
  rm -f \
    "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apk" \
    "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apk.sha256" \
    "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.aab" \
    "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.aab.sha256" \
    "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apks" \
    "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apks.sha256" \
    "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-release-candidate.aab" \
    "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-release-candidate.aab.sha256"
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
    python3 code/mim/tests/run_plugin_runtime_tests.py
    bash code/mim/tests/run_media_tests.sh
  } | tee output/test-results/non-android-suite.log
}

package_mim_plugin_runtime() {
  cd "$fm"
  local version
  version="$(sed -n 's/^VERSION=//p' release.properties 2>/dev/null || true)"
  if [[ -z "$version" ]]; then
    version="$(grep -Eo 'v?[0-9]+\.[0-9]+\.[0-9]+' code/mim/sagetv_ffmpeg_mim.cpp | head -1 | sed 's/^v//')"
  fi
  : "${version:?Unable to determine MIM version}"
  python3 code/tools/package_sagetv_plugin_runtime.py --target linux-x64 --version "$version"
  python3 code/tools/package_sagetv_plugin_runtime.py --target windows-x64 --version "$version"
  python3 code/mim/tests/run_plugin_runtime_tests.py
}

runtime_stage() {
  env \
    CORE_PACKAGE="$core/output/packages/sagetv-server-x86_64.tar.gz" \
    XMLTV_OUTPUT="$xmltv/output" \
    CORE_MCP_OUTPUT="$core_mcp/output" \
    CORE_MCP_SOURCE="$core_mcp" \
    bash "$container/stage-artifacts.sh"
}

runtime_images() {
  env \
    SKIP_ARTIFACT_STAGE=true \
    CORE_SOURCE="$core" XMLTV_SOURCE="$xmltv" CORE_MCP_SOURCE="$core_mcp" \
    OPENSAGETV_VIBE_SERVER_IMAGE="$production_image" \
    OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE="$debug_image" \
    bash "$container/build.sh"
}

runtime_image_status() {
  local expected installed installed_debug
  expected="$(bash "$container/scripts/runtime-environment-fingerprint.sh")"
  installed="$(docker image inspect "$production_image" \
    --format '{{index .Config.Labels "org.opensagetv.vibe.runtime-environment.fingerprint"}}' 2>/dev/null || true)"
  installed_debug="$(docker image inspect "$debug_image" \
    --format '{{index .Config.Labels "org.opensagetv.vibe.runtime-environment.fingerprint"}}' 2>/dev/null || true)"
  echo "expected_runtime_environment_fingerprint=$expected"
  echo "installed_runtime_environment_fingerprint=${installed:-missing}"
  echo "installed_debug_runtime_environment_fingerprint=${installed_debug:-missing}"
  if [[ "$expected" == "$installed" && "$expected" == "$installed_debug" ]]; then
    echo 'runtime_image_rebuild_needed=false'
  else
    echo 'runtime_image_rebuild_needed=true'
  fi
}

runtime_test() {
  mkdir -p "$manifest/output/test-results"
  env \
    CORE_SOURCE="$core" \
    XMLTV_SOURCE="$xmltv" \
    CORE_MCP_SOURCE="$core_mcp" \
    OPENDCT_STATUS_FILE="$manifest/output/test-results/opendct-live.status" \
    OPENSAGETV_VIBE_SERVER_IMAGE="$production_image" \
    OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE="$debug_image" \
    bash "$container/tests/runtime-validation.sh" | tee "$manifest/output/test-results/runtime-validation.log"
}

runtime_update_package() {
  local component="${1:?component required: core, xmltv, tmdb, or comskip}"
  env CORE_SOURCE="$core" XMLTV_SOURCE="$xmltv" TMDB_SOURCE="$tmdb" \
    bash "$container/scripts/create-component-update.sh" \
      "$component" "$container/output/component-updates"
}

runtime_update_test() {
  local component="${1:-all}"
  if [[ "$component" == all ]]; then
    for item in core xmltv tmdb comskip; do
      env CORE_SOURCE="$core" XMLTV_SOURCE="$xmltv" TMDB_SOURCE="$tmdb" \
        bash "$container/scripts/test-component.sh" "$item"
    done
    env CORE_SOURCE="$core" XMLTV_SOURCE="$xmltv" TMDB_SOURCE="$tmdb" \
      bash "$container/tests/component-update-selftest.sh"
  else
    env CORE_SOURCE="$core" XMLTV_SOURCE="$xmltv" TMDB_SOURCE="$tmdb" \
      bash "$container/scripts/test-component.sh" "$component"
    if [[ "$component" == tmdb ]]; then
      env CORE_SOURCE="$core" XMLTV_SOURCE="$xmltv" TMDB_SOURCE="$tmdb" \
        bash "$container/tests/component-update-selftest.sh" "$component"
    fi
  fi
}

release_package() {
  env \
    CORE_SOURCE="$core" MIM_SOURCE="$fm" FFMPEG_PLUGIN_SOURCE="$ffmpeg_plugin" \
    CORE_MCP_SOURCE="$core_mcp" XMLTV_SOURCE="$xmltv" TMDB_SOURCE="$tmdb" \
    CONTAINER_SOURCE="$container" LOGO_SOURCE="$logo" ANDROID_SOURCE="$android" \
    SAGEMC_SOURCE="$sagemc" \
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
  local status="$1" rc="${2:-0}" release_path="not assembled" opendct="not run" android_apk="not built"
  [[ ! -s "$manifest/output/RELEASE_PATH" ]] || release_path="$(cat "$manifest/output/RELEASE_PATH")"
  [[ ! -s "$manifest/output/test-results/opendct-live.status" ]] || opendct="$(cat "$manifest/output/test-results/opendct-live.status")"
  if [[ -s "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apk" ]]; then
    android_apk="$(sha256sum "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apk" | cut -d' ' -f1)"
  fi
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
    echo "- Android Java: $(/opt/java/jdk17/bin/java -version 2>&1 | head -1)"
    echo "- Android client: $(cat "$android/VERSION")"
    echo "- Android APK SHA-256: $android_apk"
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

configure_safe_directories() {
  local path
  for path in "$core" "$fm" "$ffmpeg_plugin" "$core_mcp" "$xmltv" "$tmdb" "$container" "$logo" "$android" "$sagemc" "$manifest"; do
    [[ -d "$path/.git" ]] || continue
    if ! git config --global --get-all safe.directory 2>/dev/null | grep -Fqx "$path"; then
      git config --global --add safe.directory "$path"
    fi
  done
}

configure_safe_directories

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
  ffmpeg-runtime-package) package_mim_plugin_runtime ;;
  ffmpeg-plugin-test) cd "$ffmpeg_plugin"; exec bash scripts/test.sh ;;
  ffmpeg-plugin-validate) cd "$ffmpeg_plugin"; exec bash scripts/validate.sh ;;
  ffmpeg-plugin-build) cd "$ffmpeg_plugin"; exec env MIM_REPO_ROOT="$fm" bash scripts/package-dev.sh ;;
  ffmpeg-plugin-all)
    cd "$ffmpeg_plugin"
    bash scripts/test.sh
    bash scripts/validate.sh
    env MIM_REPO_ROOT="$fm" bash scripts/package-dev.sh
    ;;
  core-mcp-test)
    cd "$core_mcp"
    exec env SAGETV_JAR="$ffmpeg_plugin/.deps/stock/Sage.jar" python3 scripts/project.py test
    ;;
  core-mcp-validate) cd "$core_mcp"; exec python3 scripts/project.py validate ;;
  core-mcp-build)
    cd "$core_mcp"
    exec env SAGETV_JAR="$ffmpeg_plugin/.deps/stock/Sage.jar" python3 scripts/project.py package
    ;;
  core-mcp-all)
    cd "$core_mcp"
    exec env SAGETV_JAR="$ffmpeg_plugin/.deps/stock/Sage.jar" python3 scripts/project.py all
    ;;
  xmltv) cd "$xmltv"; exec bash scripts/build.sh ;;
  tmdb-test) cd "$tmdb"; exec bash scripts/build.sh ;;
  tmdb-validate)
    cd "$tmdb"
    find . -type f \( -name 'tmdb_config.toml' -o -name '*.sqlite3' -o -name '*.sqlite3-wal' -o -name '*.sqlite3-shm' \) \
      -not -path './.deps/*' -not -path './output/*' -print -quit | grep -q . && {
        echo 'ERROR: private TMDB configuration/cache in publishable source' >&2; exit 1; }
    echo 'PASS: no private TMDB configuration/cache in publishable source'
    ;;
  tmdb-build) cd "$tmdb"; exec bash scripts/build.sh ;;
  tmdb-all)
    cd "$tmdb"
    bash /workspace/release-manifest/scripts/dev-entrypoint.sh tmdb-validate
    bash scripts/build.sh
    echo 'PASS: TMDB package is ready for component-only install/update/rollback'
    ;;
  tmdb-consumer-test)
    CORE_SOURCE="$core" TMDB_SOURCE="$tmdb" XMLTV_SOURCE="$xmltv" SAGEMC_SOURCE="$sagemc" \
      exec bash "$manifest/tests/tmdb-consumer-stress.sh"
    ;;
  logo-info)
    validate_environment
    logo_environment python3 -c 'import importlib.metadata as m; print("cairosvg=" + m.version("CairoSVG")); print("pillow=" + m.version("Pillow"))'
    test "$(find "$logo/M_PLUS_Rounded_1c" -maxdepth 1 -type f -name '*.ttf' | wc -l)" = 7
    fc-scan --format 'logo_font=%{family}\n' \
      "$logo/M_PLUS_Rounded_1c/MPLUSRounded1c-ExtraBold.ttf" | head -1
    echo 'logo_toolchain=PASS'
    ;;
  logo-test)
    logo_environment python3 -m unittest discover -s "$logo/tests" -p 'test_*.py' -v
    ;;
  logo-validate) logo_pipeline validate ;;
  logo-build) logo_pipeline build ;;
  logo-install) logo_pipeline install ;;
  logo-all)
    logo_environment python3 -m unittest discover -s "$logo/tests" -p 'test_*.py' -v
    logo_build_install
    ;;
  android-info) android_info ;;
  android-test) android_prepare; android_command test "$@" ;;
  android-validate) android_prepare; android_command validate "$@" ;;
  android-build) android_prepare; android_command build "$@" ;;
  android-bundle) android_prepare; android_command bundle "$@" ;;
  android-bundle-install) android_command bundle-install "$@" ;;
  android-all) run_android_suite ;;
  android-mcp) android_command mcp "$@" ;;
  sagemc-test) cd "$sagemc"; exec env SAGETV_CORE_ROOT="$core" bash scripts/test.sh "$@" ;;
  sagemc-validate) cd "$sagemc"; exec env SAGETV_CORE_ROOT="$core" bash scripts/validate.sh "$@" ;;
  sagemc-build) cd "$sagemc"; exec env SAGETV_CORE_ROOT="$core" bash scripts/build.sh "$@" ;;
  sagemc-all)
    cd "$sagemc"
    env SAGETV_CORE_ROOT="$core" bash scripts/test.sh "$@"
    env SAGETV_CORE_ROOT="$core" bash scripts/build.sh "$@"
    ;;
  runtime-stage) runtime_stage ;;
  runtime-images) runtime_images ;;
  runtime-image-status) runtime_image_status ;;
  runtime-test) runtime_test ;;
  runtime-update-package) runtime_update_package "$@" ;;
  runtime-update-test) runtime_update_test "$@" ;;
  release) release_package ;;
  runtime-all) run_runtime_all ;;
  clean)
    cd "$core"; bash tests/linux-modern/clean.sh
    android_clean
    rm -rf "$fm/output" "$ffmpeg_plugin/build" "$ffmpeg_plugin/output" "$core_mcp/build" "$core_mcp/dist" "$core_mcp/output" "$manifest/output" "$xmltv/build" "$xmltv/output" "$tmdb/output" "$container/artifacts" "$logo/generated" "$sagemc/output"
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
    run_stage 'MIM SageTV plugin runtime packages' package_mim_plugin_runtime
    run_stage 'Stock-server FFmpeg Standard plugin and STVi' bash -c "cd '$ffmpeg_plugin' && bash scripts/test.sh && bash scripts/validate.sh && MIM_REPO_ROOT='$fm' bash scripts/package-dev.sh"
    run_stage 'Stock-server Core MCP Standard plugin' bash -c "cd '$core_mcp' && SAGETV_JAR='$ffmpeg_plugin/.deps/stock/Sage.jar' python3 scripts/project.py all"
    run_stage 'XMLTV compile, regression tests, and package' bash -c "cd '$xmltv' && bash scripts/build.sh"
    run_stage 'Reusable TMDB service compile, cache/HTTP tests, and package' bash -c "cd '$tmdb' && bash scripts/build.sh"
    run_stage 'SageMC Studio graph tests, validation, and package' bash -c "cd '$sagemc' && SAGETV_CORE_ROOT='$core' bash scripts/test.sh && SAGETV_CORE_ROOT='$core' bash scripts/build.sh"
    run_stage 'Simultaneous SageMC/XMLTV shared-TMDB adapter stress' \
      env CORE_SOURCE="$core" TMDB_SOURCE="$tmdb" XMLTV_SOURCE="$xmltv" SAGEMC_SOURCE="$sagemc" \
      bash "$manifest/tests/tmdb-consumer-stress.sh"
    run_stage 'Android client tests, validation, deterministic APK/AAB builds, and bundletool checks' run_android_suite
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
    echo 'Commands: all core core-mcp-test core-mcp-validate core-mcp-build core-mcp-all ffmpeg-linux ffmpeg-windows ffmpeg-info test-mim ffmpeg-runtime-package ffmpeg-plugin-test ffmpeg-plugin-validate ffmpeg-plugin-build ffmpeg-plugin-all xmltv tmdb-test tmdb-validate tmdb-build tmdb-all tmdb-consumer-test logo-info logo-test logo-validate logo-build logo-install logo-all android-info android-test android-validate android-build android-bundle android-bundle-install android-all android-mcp sagemc-test sagemc-validate sagemc-build sagemc-all runtime-stage runtime-images runtime-image-status runtime-test runtime-update-package runtime-update-test release runtime-all clean shell'
    ;;
esac
