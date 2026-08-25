#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-help}"; shift || true
core=/work/sagetv; fm=/project; xmltv=/workspace/xmltv-import; manifest=/workspace/release-manifest
ffmpeg_target() {
  local id="$1" key="$2"; local target="/opt/sagetv/targets/$key"
  rm -rf /opt/ct-ng /opt/ffbuild; ln -s "$target/ct-ng" /opt/ct-ng; ln -s "$target/ffbuild" /opt/ffbuild
  source "$target/env.sh"; export PATH="/opt/ct-ng/bin:$PATH" PKG_CONFIG_LIBDIR=/opt/ffbuild/lib/pkgconfig:/opt/ffbuild/share/pkgconfig
  cd "$fm"; bash code/docker/build_target_unified.sh "$id"
}
case "$cmd" in
  core) cd "$core"; exec bash tests/linux-modern/all.sh "$@" ;;
  ffmpeg-linux) ffmpeg_target linux-x64 linux64 ;;
  ffmpeg-windows) ffmpeg_target windows-x64 win64 ;;
  test-mim) cd "$fm"; bash code/mim/tests/run_init_tests.sh; exec bash code/mim/tests/run_mim_tests.sh ;;
  xmltv) cd "$xmltv"; exec bash scripts/build.sh ;;
  all)
    mkdir -p "$manifest/output"
    report="$manifest/output/BUILD_REPORT.md"
    rm -f "$report" "$manifest/output/CORE_BUILD_REPORT.md"
    trap 'rc=$?; printf "# OpenSageTV Unified Build Report\n\nBUILD FAILED (exit %s)\n" "$rc" > "$report"; exit "$rc"' ERR
    cd "$core"; bash tests/linux-modern/all.sh
    ffmpeg_target linux-x64 linux64
    ffmpeg_target windows-x64 win64
    cd "$fm"; bash code/mim/tests/run_init_tests.sh; bash code/mim/tests/run_mim_tests.sh
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
      echo '| XMLTV compile/tests/package | PASS |'
    } > "$report"
    trap - ERR
    echo "BUILD PASSED" ;;
  shell) exec bash "$@" ;;
  help|*) echo "Commands: all core ffmpeg-linux ffmpeg-windows test-mim xmltv shell" ;;
esac
