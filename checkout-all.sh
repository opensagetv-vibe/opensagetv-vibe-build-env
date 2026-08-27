#!/usr/bin/env bash
set -euo pipefail

build_env="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace="$(cd "$build_env/.." && pwd)"
organization="${OPENSAGETV_VIBE_ORG:-opensagetv-vibe}"
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
  opensagetv-vibe-archive
)

for repository in "${repositories[@]}"; do
  if [[ "$skip_archive" == true && "$repository" == opensagetv-vibe-archive ]]; then
    continue
  fi

  branch=ubuntu26-modern-build
  [[ "$repository" == opensagetv-vibe-archive ]] && branch=main
  target="$workspace/$repository"
  url="https://github.com/$organization/$repository.git"

  if [[ ! -e "$target" ]]; then
    git clone --branch "$branch" --single-branch "$url" "$target"
    continue
  fi
  if [[ ! -d "$target/.git" ]]; then
    echo "ERROR: existing path is not a Git repository: $target" >&2
    exit 1
  fi
  if [[ -n "$(git -C "$target" status --porcelain)" ]]; then
    echo "ERROR: refusing to update dirty repository: $target" >&2
    exit 1
  fi

  git -C "$target" fetch origin "$branch"
  if git -C "$target" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$target" switch "$branch"
  else
    git -C "$target" switch --create "$branch" --track "origin/$branch"
  fi
  git -C "$target" merge --ff-only "origin/$branch"
done

echo "OpenSageTV Vibe workspace ready: $workspace"
