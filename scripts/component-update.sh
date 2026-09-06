#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "${1:?project root required}" && pwd)"
action="${2:-auto}"
explicit_package="${3:-}"
project="$(basename "$project_root")"
downloads="$project_root/artifacts/downloads"
state_dir="$project_root/artifacts/update_runner"
state_file="$state_dir/state.env"
mkdir -p "$downloads" "$state_dir"

read_property() {
  local key="$1" file="$2"
  tr -d '\r' < "$file" | sed -n -E "s/^${key}=([^[:space:]]+)$/\\1/p" | tail -n 1
}

metadata="$project_root/release.properties"
test -f "$metadata" || { echo "ERROR: missing $metadata" >&2; exit 2; }
current_version="$(read_property VERSION "$metadata")"
requires_build="$(read_property REQUIRES_BUILD "$metadata")"
package_id="$(read_property PACKAGE_ID "$metadata")"
package_id="${package_id:-$project}"
[[ -n "$current_version" && "$requires_build" =~ ^(true|false)$ ]] || {
  echo 'ERROR: release.properties requires VERSION and REQUIRES_BUILD=true|false' >&2
  exit 2
}

version_from_package() {
  local name="$(basename "$1")" prefix="${package_id}-v" suffix="-changed-files-only.zip"
  [[ "$name" == "$prefix"*"$suffix" ]] || return 1
  local value="${name#"$prefix"}"
  printf '%s\n' "${value%"$suffix"}"
}

version_gt() {
  local candidate="$1" baseline="$2"
  [[ "$candidate" != "$baseline" ]] &&
    [[ "$(printf '%s\n%s\n' "$candidate" "$baseline" | sort -V | tail -1)" == "$candidate" ]]
}

newest=''
newest_version=''
while IFS= read -r -d '' candidate; do
  version="$(version_from_package "$candidate" || true)"
  [[ -n "$version" ]] && version_gt "$version" "$current_version" || continue
  if [[ -z "$newest" || "$(printf '%s\n%s\n' "$newest_version" "$version" | sort -V | tail -1)" == "$version" ]]; then
    newest="$candidate"; newest_version="$version"
  fi
done < <(find "$downloads" -maxdepth 1 -type f -name "${package_id}-v*-changed-files-only.zip" -print0)

safe_path() {
  local path="$1"
  [[ -n "$path" && "$path" != /* && "$path" != *\\* && "$path" != *:* ]] || return 1
  [[ "$path" != '..' && "$path" != ../* && "$path" != */../* && "$path" != */.. ]]
}

verify_package() {
  local package="$1" staging duplicate entry line digest path actual release_package_id deletion
  declare -A expected=()
  unzip -tq "$package" >/dev/null
  duplicate="$(unzip -Z1 "$package" | sed '/\/$/d' | sort | uniq -d | head -1)"
  [[ -z "$duplicate" ]] || { echo "ERROR: duplicate ZIP entry: $duplicate" >&2; return 1; }
  while IFS= read -r entry; do
    [[ "$entry" == */ ]] && continue
    safe_path "$entry" || { echo "ERROR: unsafe ZIP path: $entry" >&2; return 1; }
  done < <(unzip -Z1 "$package")
  if zipinfo -l "$package" | awk '$1 ~ /^l/ { found=1 } END { exit !found }'; then
    echo 'ERROR: update ZIP contains a symbolic link' >&2
    return 1
  fi

  staging="$(mktemp -d "$state_dir/preflight.XXXXXX")"
  trap 'rm -rf -- "$staging"' RETURN
  unzip -q "$package" -d "$staging"
  test -f "$staging/PROJECT_MANIFEST.sha256" || {
    echo 'ERROR: package lacks PROJECT_MANIFEST.sha256' >&2; return 1;
  }
  test -f "$staging/release.properties" || {
    echo 'ERROR: package lacks release.properties' >&2; return 1;
  }
  [[ "$(read_property VERSION "$staging/release.properties")" == "$newest_version" ]] || {
    echo 'ERROR: filename and release.properties versions differ' >&2; return 1;
  }
  release_package_id="$(read_property PACKAGE_ID "$staging/release.properties")"
  [[ "${release_package_id:-$project}" == "$package_id" ]] || {
    echo 'ERROR: package identity does not match this project' >&2; return 1;
  }
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^([0-9a-fA-F]{64})\ \ (.+)$ ]] || {
      echo "ERROR: invalid manifest line: $line" >&2; return 1;
    }
    digest="${BASH_REMATCH[1],,}"; path="${BASH_REMATCH[2]}"
    safe_path "$path" || { echo "ERROR: unsafe manifest path: $path" >&2; return 1; }
    [[ -z "${expected[$path]+present}" ]] || { echo "ERROR: duplicate manifest path: $path" >&2; return 1; }
    expected["$path"]="$digest"
    if [[ -f "$staging/$path" ]]; then
      actual="$(sha256sum "$staging/$path" | awk '{print $1}')"
    elif [[ -f "$project_root/$path" ]]; then
      actual="$(sha256sum "$project_root/$path" | awk '{print $1}')"
    else
      echo "ERROR: manifest file unavailable: $path" >&2; return 1
    fi
    [[ "$actual" == "$digest" ]] || { echo "ERROR: hash mismatch: $path" >&2; return 1; }
  done < "$staging/PROJECT_MANIFEST.sha256"
  if [[ -f "$staging/release-deletions.lst" ]]; then
    while IFS= read -r deletion || [[ -n "$deletion" ]]; do
      deletion="${deletion%$'\r'}"
      [[ -n "$deletion" && "$deletion" != \#* ]] || continue
      safe_path "$deletion" || { echo "ERROR: unsafe deletion path: $deletion" >&2; return 1; }
      [[ "$deletion" != PROJECT_MANIFEST.sha256 && "$deletion" != release-deletions.lst ]] || {
        echo "ERROR: deletion list targets an update control file: $deletion" >&2; return 1;
      }
      [[ -z "${expected[$deletion]+present}" ]] || {
        echo "ERROR: deletion remains present in the new manifest: $deletion" >&2; return 1;
      }
    done < "$staging/release-deletions.lst"
  fi
  while IFS= read -r -d '' entry; do
    path="${entry#"$staging/"}"
    [[ "$path" == PROJECT_MANIFEST.sha256 ]] && continue
    [[ -n "${expected[$path]+present}" ]] || {
      echo "ERROR: packaged file is absent from full manifest: $path" >&2
      return 1
    }
  done < <(find "$staging" -type f -print0)
  rm -rf -- "$staging"
  trap - RETURN
}

case "$action" in
  auto) ;;
  --verify|--apply-package)
    [[ -n "$explicit_package" && -f "$explicit_package" ]] || {
      echo "ERROR: $action requires an existing update ZIP path" >&2
      exit 2
    }
    newest="$(realpath -- "$explicit_package")"
    newest_version="$(version_from_package "$newest" || true)"
    [[ -n "$newest_version" ]] || {
      echo "ERROR: update filename does not match PACKAGE_ID=$package_id" >&2
      exit 2
    }
    if [[ "$action" == --verify ]]; then
      verify_package "$newest"
      echo "PACKAGE VERIFIED: $(basename "$newest")"
      exit 0
    fi
    ;;
  *)
    echo 'Usage: component-update.sh PROJECT_ROOT [--verify|--apply-package ZIP]' >&2
    exit 2
    ;;
esac

if [[ -n "$newest" ]]; then
  echo "UPDATE: validating $(basename "$newest")"
  verify_package "$newest"
  unzip -oq "$newest" -d "$project_root"
  if [[ ! -f "$project_root/scripts/project_manifest.py" ]]; then
    rm -f -- "$project_root/PROJECT_MANIFEST.sha256"
  fi
  if [[ -f "$project_root/release-deletions.lst" ]]; then
    while IFS= read -r path || [[ -n "$path" ]]; do
      path="${path%$'\r'}"
      [[ -n "$path" && "$path" != \#* ]] || continue
      safe_path "$path" || { echo "ERROR: unsafe deletion path: $path" >&2; exit 1; }
      target="$project_root/$path"
      resolved_parent="$(realpath -m -- "$(dirname "$target")")"
      case "$resolved_parent" in
        "$project_root"|"$project_root"/*) ;;
        *) echo "ERROR: deletion path escapes through a symlink: $path" >&2; exit 1 ;;
      esac
      [[ ! -d "$target" || -L "$target" ]] || { echo "ERROR: refusing directory deletion: $path" >&2; exit 1; }
      rm -f -- "$target"
    done < "$project_root/release-deletions.lst"
  fi
  current_version="$newest_version"
  requires_build="$(read_property REQUIRES_BUILD "$project_root/release.properties")"
  rm -f -- "$state_file"
  echo "UPDATE: applied v$current_version"
else
  echo "UPDATE: no newer package for $project in artifacts/downloads"
fi

done_test=false; done_validate=false; done_build=false; done_install=false
if [[ -f "$state_file" ]]; then
  # shellcheck disable=SC1090
  source "$state_file"
fi
if [[ "${state_version:-}" != "$current_version" ]]; then
  done_test=false; done_validate=false; done_build=false; done_install=false
fi
save_state() {
  {
    printf 'state_version=%q\n' "$current_version"
    printf 'done_test=%q\n' "$done_test"
    printf 'done_validate=%q\n' "$done_validate"
    printf 'done_build=%q\n' "$done_build"
    printf 'done_install=%q\n' "$done_install"
  } > "$state_file.tmp"
  mv -f "$state_file.tmp" "$state_file"
}
run_gate() {
  local gate="$1"
  echo "===== $project: $gate ====="
  bash "$project_root/dev.sh" "$gate"
}
if [[ "$done_test" != true ]]; then run_gate test; done_test=true; save_state; fi
if [[ "$done_validate" != true ]]; then run_gate validate; done_validate=true; save_state; fi
if [[ "$requires_build" == true ]]; then
  if [[ "$done_build" != true ]]; then run_gate build; done_build=true; save_state; fi
  if [[ "$done_install" != true ]]; then run_gate install; done_install=true; save_state; fi
else
  done_build=skipped; done_install=skipped; save_state
  echo 'SKIPPED: release metadata declares REQUIRES_BUILD=false'
fi
echo "WORKFLOW COMPLETE: $project v$current_version"
