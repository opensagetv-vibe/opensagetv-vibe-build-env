#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; projects="$(cd "$root/.." && pwd)"
image="${OPENSAGETV_BUILD_IMAGE:-opensagetv-build-env:u26-j11}"; cmd="${1:-help}"
shift || true
if [[ "$cmd" == image || "$cmd" == all ]]; then docker build -t "$image" "$root"; [[ "$cmd" == image ]] && exit 0; fi
if [[ "$cmd" == clean ]]; then cmd=shell; set -- -lc 'cd /work/sagetv && ./sagetv-dev.sh clean; rm -rf /project/output /workspace/release-manifest/output'; fi
tty=(); [[ "$cmd" == shell && $# -eq 0 ]] && tty=(-it)
docker run --rm --init "${tty[@]}" \
  -v "$projects/opensagetv-core:/work/sagetv" \
  -v "$projects/opensagetv-ffmpeg-mim:/project" \
  -v "$projects/opensagetv-xmltv-import:/workspace/xmltv-import" \
  -v "$root:/workspace/release-manifest" "$image" "$cmd" "$@"
