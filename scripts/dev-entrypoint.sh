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
    cd "$core"; bash tests/linux-modern/all.sh
    ffmpeg_target linux-x64 linux64
    ffmpeg_target windows-x64 win64
    cd "$xmltv"; bash scripts/build.sh
    mkdir -p "$manifest/output"; cp "$core/output/BUILD_REPORT.md" "$manifest/output/CORE_BUILD_REPORT.md"
    echo "BUILD PASSED" ;;
  shell) exec bash "$@" ;;
  help|*) echo "Commands: all core ffmpeg-linux ffmpeg-windows test-mim xmltv shell" ;;
esac
