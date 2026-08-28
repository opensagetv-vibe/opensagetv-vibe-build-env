#!/usr/bin/env bash
set -euo pipefail

build_env="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace="$(cd "$build_env/.." && pwd)"
organization="${OPENSAGETV_VIBE_ORG:-opensagetv-vibe}"
source_root="${OPENSAGETV_VIBE_SOURCE_ROOT:-}"
resolved_manifest="${OPENSAGETV_VIBE_RESOLVED_MANIFEST:-}"
skip_archive=false

if [[ "${1:-}" == "--skip-archive" ]]; then
  skip_archive=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--skip-archive]" >&2
  exit 2
fi

repositories=(
  opensagetv-vibe-build-env
  opensagetv-vibe-core
  opensagetv-vibe-container
  opensagetv-vibe-ffmpeg-mim
  opensagetv-vibe-xmltv-import
  opensagetv-vibe-android-client
  opensagetv-vibe-archive
)

manifest_name() {
  case "$1" in
    opensagetv-vibe-build-env) echo build_env ;;
    opensagetv-vibe-core) echo core ;;
    opensagetv-vibe-container) echo container ;;
    opensagetv-vibe-ffmpeg-mim) echo ffmpeg_mim ;;
    opensagetv-vibe-xmltv-import) echo xmltv_import ;;
    opensagetv-vibe-android-client) echo android_client ;;
    *) return 1 ;;
  esac
}

manifest_commit() {
  local name="$1"
  awk -v name="$name" '
    $0 ~ "\\\"" name "\\\"[[:space:]]*:" { found=1; next }
    found && /"commit"[[:space:]]*:/ {
      line=$0
      sub(/^.*"commit"[[:space:]]*:[[:space:]]*"/, "", line)
      sub(/".*$/, "", line)
      print line
      exit
    }
  ' "$resolved_manifest"
}

if [[ -n "$source_root" ]]; then source_root="$(cd "$source_root" && pwd)"; fi
if [[ -n "$resolved_manifest" ]]; then
  resolved_manifest="$(cd "$(dirname "$resolved_manifest")" && pwd)/$(basename "$resolved_manifest")"
  [[ -s "$resolved_manifest" ]] || { echo "ERROR: resolved manifest is missing" >&2; exit 1; }
fi

for repository in "${repositories[@]}"; do
  if [[ "$skip_archive" == true && "$repository" == opensagetv-vibe-archive ]]; then
    continue
  fi

  branch=ubuntu26-modern-build
  if [[ "$repository" == opensagetv-vibe-archive || "$repository" == opensagetv-vibe-android-client ]]; then
    branch=main
  fi
  target="$workspace/$repository"
  if [[ -n "$source_root" ]]; then
    url="$source_root/$repository"
  else
    url="https://github.com/$organization/$repository.git"
  fi

  if [[ ! -e "$target" ]]; then
    clone_args=(clone --branch "$branch" --single-branch)
    [[ -z "$source_root" ]] || clone_args+=(--no-local)
    git "${clone_args[@]}" "$url" "$target"
  else
    if [[ ! -d "$target/.git" ]]; then
      echo "ERROR: existing path is not a Git repository: $target" >&2
      exit 1
    fi
    if [[ -n "$(git -C "$target" status --porcelain)" ]]; then
      echo "ERROR: refusing to update dirty repository: $target" >&2
      exit 1
    fi
    [[ -z "$source_root" ]] || git -C "$target" remote set-url origin "$url"
    git -C "$target" fetch origin "$branch"
    if git -C "$target" show-ref --verify --quiet "refs/heads/$branch"; then
      git -C "$target" switch "$branch"
    else
      git -C "$target" switch --create "$branch" --track "origin/$branch"
    fi
    git -C "$target" merge --ff-only "origin/$branch"
  fi

  if [[ -n "$resolved_manifest" ]] && name="$(manifest_name "$repository")"; then
    commit="$(manifest_commit "$name")"
    [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || {
      echo "ERROR: resolved manifest has no valid commit for $name" >&2
      exit 1
    }
    git -C "$target" cat-file -e "$commit^{commit}"
    git -C "$target" switch --detach "$commit"
  fi
done

echo "OpenSageTV Vibe workspace ready: $workspace"
