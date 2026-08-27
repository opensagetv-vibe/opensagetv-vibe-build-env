#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-help}"; shift || true
core=/work/sagetv; fm=/project; xmltv=/workspace/xmltv-import; manifest=/workspace/release-manifest
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
}
ffmpeg_target() {
  local id="$1" key="$2"; local target="/opt/sagetv/targets/$key"
  rm -rf /opt/ct-ng /opt/ffbuild; ln -s "$target/ct-ng" /opt/ct-ng; ln -s "$target/ffbuild" /opt/ffbuild
  source "$target/env.sh"; export PATH="/opt/ct-ng/bin:$PATH" PKG_CONFIG_LIBDIR=/opt/ffbuild/lib/pkgconfig:/opt/ffbuild/share/pkgconfig
  cd "$fm"; bash code/docker/build_target_unified.sh "$id"
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
    ;;
  test-mim) run_mim_suite ;;
  xmltv) cd "$xmltv"; exec bash scripts/build.sh ;;
  clean)
    cd "$core"; bash tests/linux-modern/clean.sh
    rm -rf "$fm/output" "$manifest/output" "$xmltv/build"
    echo "Build outputs cleaned"
    ;;
  all)
    validate_environment
    mkdir -p "$manifest/output"
    report="$manifest/output/BUILD_REPORT.md"
    rm -f "$report" "$manifest/output/CORE_BUILD_REPORT.md"
    trap 'rc=$?; printf "# OpenSageTV Unified Build Report\n\nBUILD FAILED (exit %s)\n" "$rc" > "$report"; exit "$rc"' ERR
    cd "$core"; bash tests/linux-modern/all.sh
    ffmpeg_target linux-x64 linux64
    ffmpeg_target windows-x64 win64
    run_mim_suite
    cd "$xmltv"; bash scripts/build.sh
    cp "$core/output/BUILD_REPORT.md" "$manifest/output/CORE_BUILD_REPORT.md"
    {
      echo '# OpenSageTV Unified Build Report'; echo
      echo 'BUILD PASSED'; echo
      echo "- Base: Ubuntu 26.04 (linux/amd64)"
      echo "- Java: $(java -version 2>&1 | head -1)"
      echo "- GCC: $(gcc --version | head -1)"
      echo "- Kernel: $(uname -srmo)"
      echo; echo '| Component | Result |'; echo '|---|---|'
      echo '| SageTV Core clean build/tests/package | PASS |'
      echo '| FFmpeg/MIM Linux x64 | PASS |'
      echo '| FFmpeg/MIM Windows x64 | PASS |'
      echo '| MIM init/control/teardown/containment | PASS |'
      echo '| MIM completed/growing/join/repeated media integrity | PASS |'
      echo '| XMLTV compile/tests/package | PASS |'
    } > "$report"
    trap - ERR
    echo "BUILD PASSED" ;;
  shell) exec bash "$@" ;;
  help|*) echo "Commands: all core ffmpeg-linux ffmpeg-windows ffmpeg-info test-mim xmltv clean shell" ;;
esac
