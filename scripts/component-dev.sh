#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "${1:?project root required}" && pwd)"
command="${2:-help}"
shift 2 || true
project="$(basename "$project_root")"
build_env="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
unified="$build_env/opensagetv-vibe-dev.sh"

syntax_check() {
  local files=()
  while IFS= read -r -d '' file; do files+=("$file"); done \
    < <(find "$project_root" -type f -name '*.sh' -not -path '*/.git/*' -not -path '*/artifacts/*' -print0)
  ((${#files[@]} == 0)) || bash -n "${files[@]}"
  python3 - "$project_root" <<'PY'
import ast
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
for path in root.rglob("*.py"):
    relative = path.relative_to(root)
    # Validate first-party workflow/source Python only. Historical upstream
    # trees intentionally retain Python 2 build helpers (for example MPlayer's
    # mphelp_check.py), and frozen comparison/generated trees are not owned by
    # the Vibe workflow syntax gate.
    excluded_parts = {".git", "artifacts", "third_party", "existing", "output", "build"}
    if excluded_parts.intersection(relative.parts):
        continue
    ast.parse(path.read_text(encoding="utf-8"), filename=str(relative))
PY
  echo "PASS: $project shell/Python syntax"
}

artifact_only_install() {
  echo "SKIPPED: $project produces artifacts; it has no safe local install action."
}

# The build-environment repository also owns the complete unified controller.
# Keep its standard dev.{cmd,ps1,sh} entry points capable of invoking every
# unified command so Windows users do not need to know a second script name.
if [[ "$project" == opensagetv-vibe-build-env ]]; then
  case "$command" in
    image|start|stop|remove-dev|core|ffmpeg-linux|ffmpeg-windows|ffmpeg-info|test-mim|xmltv|logo-info|logo-test|logo-validate|logo-build|logo-install|logo-all|android-info|android-test|android-validate|android-build|android-bundle|android-bundle-install|android-all|android-mcp|runtime-stage|runtime-images|runtime-image-status|runtime-test|runtime-update-package|runtime-update-test|release|runtime-all|clean)
      exec "$unified" "$command" "$@"
      ;;
  esac
fi

case "$project:$command" in
  opensagetv-vibe-core:test) syntax_check ;;
  opensagetv-vibe-core:validate)
    test -x "$project_root/sagetv-dev.sh"
    test -f "$project_root/tests/linux-modern/test-all.sh"
    echo 'PASS: Core workflow layout'
    ;;
  opensagetv-vibe-core:build) exec "$unified" core "$@" ;;
  opensagetv-vibe-core:install) artifact_only_install ;;

  opensagetv-vibe-container:test) syntax_check ;;
  opensagetv-vibe-container:validate) exec "$unified" runtime-stage "$@" ;;
  opensagetv-vibe-container:build) exec "$unified" runtime-images "$@" ;;
  opensagetv-vibe-container:install) exec "$unified" runtime-test "$@" ;;
  opensagetv-vibe-container:package-update) exec "$unified" runtime-update-package "$@" ;;
  opensagetv-vibe-container:test-update) exec "$unified" runtime-update-test "$@" ;;

  opensagetv-vibe-ffmpeg-mim:test) syntax_check ;;
  opensagetv-vibe-ffmpeg-mim:validate) exec "$unified" ffmpeg-info "$@" ;;
  opensagetv-vibe-ffmpeg-mim:build)
    "$unified" ffmpeg-linux "$@"
    exec "$unified" ffmpeg-windows "$@"
    ;;
  opensagetv-vibe-ffmpeg-mim:install) exec "$unified" test-mim "$@" ;;

  opensagetv-vibe-xmltv-import:test)
    syntax_check
    test -f "$project_root/SAGETV_SERVER_ROOT_Contents/xmltv_src/XMLTVImportPlugin.java"
    echo 'PASS: XMLTV source layout'
    ;;
  opensagetv-vibe-xmltv-import:validate)
    test -f "$(dirname "$project_root")/opensagetv-vibe-core/output/server/Sage.jar"
    echo 'PASS: XMLTV Core dependency is staged'
    ;;
  opensagetv-vibe-xmltv-import:build) exec "$unified" xmltv "$@" ;;
  opensagetv-vibe-xmltv-import:install) artifact_only_install ;;

  opensagetv-vibe-logo:test)
    syntax_check
    exec "$unified" logo-test "$@"
    ;;
  opensagetv-vibe-logo:validate) exec "$unified" logo-validate "$@" ;;
  opensagetv-vibe-logo:build) exec "$unified" logo-build "$@" ;;
  opensagetv-vibe-logo:install) exec "$unified" logo-install "$@" ;;
  opensagetv-vibe-logo:all)
    # Generated artwork is disposable output. Build it before validation so a
    # clean checkout or a changed generator contract cannot validate stale or
    # absent PNGs.
    bash "$project_root/dev.sh" test "$@"
    bash "$project_root/dev.sh" build "$@"
    bash "$project_root/dev.sh" validate "$@"
    exec bash "$project_root/dev.sh" install "$@"
    ;;

  opensagetv-vibe-archive:test|opensagetv-vibe-archive:validate)
    test -f "$project_root/ARCHIVE_MANIFEST.md"
    test -f "$project_root/HANDOFF.md"
    if find "$project_root" -type l ! -exec test -e {} \; -print -quit | grep -q .; then
      echo 'ERROR: archive contains a broken symbolic link' >&2
      exit 1
    fi
    echo 'PASS: archive structure and provenance documents'
    ;;
  opensagetv-vibe-archive:build|opensagetv-vibe-archive:install) artifact_only_install ;;

  opensagetv-vibe-build-env:test)
    syntax_check
    bash "$project_root/tests/workflow-contract.sh"
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File \
      "$(wslpath -w "$project_root/tests/workspace-handoff-selftest.ps1")"
    echo 'PASS: unified workflow scripts'
    ;;
  opensagetv-vibe-build-env:validate)
    "$unified" start
    exec "$unified" ffmpeg-info "$@"
    ;;
  opensagetv-vibe-build-env:build) exec "$unified" image "$@" ;;
  opensagetv-vibe-build-env:install) exec "$unified" start "$@" ;;

  *:all)
    bash "$project_root/dev.sh" test "$@"
    bash "$project_root/dev.sh" validate "$@"
    bash "$project_root/dev.sh" build "$@"
    exec bash "$project_root/dev.sh" install "$@"
    ;;
  *:shell) exec "$unified" shell "$@" ;;
  *:help|*:-h|*:--help)
    cat <<EOF
Usage: ./dev.sh {test|validate|build|install|package-update|test-update|all|shell}

Project: $project
All paths resolve from the script location. Docker and the sibling
opensagetv-vibe-build-env checkout are the only workflow prerequisites.
EOF
    ;;
  *)
    echo "ERROR: unsupported command '$command' for $project" >&2
    exit 2
    ;;
esac
