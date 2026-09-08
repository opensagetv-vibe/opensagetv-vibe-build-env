#!/usr/bin/env bash
set -euo pipefail

build_env="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
projects="$(dirname "$build_env")"
repos=(
  opensagetv-vibe-build-env
  opensagetv-vibe-core
  opensagetv-vibe-container
  opensagetv-vibe-ffmpeg-mim
  opensagetv-vibe-xmltv-import
  opensagetv-vibe-logo
  opensagetv-vibe-android-client
  opensagetv-vibe-sagemc
  opensagetv-vibe-archive
)
required=(
  README.md CHANGELOG.md HANDOFF.md TASKS.md AGENTS.md WORKFLOW.md
  release.properties release-deletions.lst
  dev.sh dev.cmd dev.ps1 update.sh update.cmd update.ps1
  create_ai_handoff_zip.cmd artifacts/downloads/.gitkeep
)

for repo in "${repos[@]}"; do
  root="$projects/$repo"
  [[ -d "$root/.git" ]] || { echo "ERROR: missing checkout: $repo" >&2; exit 1; }
  for path in "${required[@]}"; do
    [[ -f "$root/$path" ]] || { echo "ERROR: $repo lacks $path" >&2; exit 1; }
  done
  tr -d '\r' < "$root/release.properties" | grep -Eq '^VERSION=[^[:space:]]+$'
  tr -d '\r' < "$root/release.properties" | grep -Eq '^PACKAGE_ID=[^[:space:]]+$'
  tr -d '\r' < "$root/release.properties" | grep -Eq '^REQUIRES_BUILD=(true|false)$'
  [[ ! -e "$root/TASK_CODEX.md" ]] || { echo "ERROR: obsolete task list remains in $repo" >&2; exit 1; }
  [[ ! -e "$root/ChangeLog.txt" ]] || { echo "ERROR: legacy version text remains in $repo" >&2; exit 1; }
  grep -Fq -- '-ProjectRoot "%~dp0."' "$root/create_ai_handoff_zip.cmd" || {
    echo "ERROR: $repo handoff wrapper does not protect the quoted trailing-backslash path" >&2
    exit 1
  }
  bash -n "$root/dev.sh" "$root/update.sh"
  (cd / && bash "$root/dev.sh" help >/dev/null)
  echo "PASS: $repo workflow contract"
done

grep -Eq '[[:space:]]smbclient([[:space:]\\]|$)' "$build_env/Dockerfile"
grep -Fq 'command -v smbclient' "$build_env/scripts/dev-entrypoint.sh"
echo 'PASS: unified image owns the SMB2/SMB3 fixture publication client'

for package in dvdauthor fontconfig fonts-dejavu-core imagemagick; do
  grep -Eq "[[:space:]]${package}([[:space:]\\]|$)" "$build_env/Dockerfile"
done
grep -Fq 'for command in ffmpeg ffprobe dvdauthor spumux spuunmux convert identify fc-match; do' \
  "$build_env/scripts/dev-entrypoint.sh"
grep -Fq 'command -v "$command"' "$build_env/scripts/dev-entrypoint.sh"
echo 'PASS: unified image owns deterministic DVD/video fixture authoring tools'

grep -Fq 'COPY --from=logo_src requirements.lock' "$build_env/Dockerfile"
grep -Fq 'OPENSAGETV_VIBE_LOGO_PYTHON=' "$build_env/Dockerfile"
grep -Fq 'logo_build_install' "$build_env/scripts/dev-entrypoint.sh"
echo 'PASS: unified image owns deterministic logo generation and Android synchronization'

grep -Fq 'ADB_VENDOR_KEYS="$android/adb/adbkey"' "$build_env/scripts/dev-entrypoint.sh"
echo 'PASS: Android device authorization survives reusable-container recreation'

echo 'PASS: all OpenSageTV Vibe repositories share the root workflow contract'
