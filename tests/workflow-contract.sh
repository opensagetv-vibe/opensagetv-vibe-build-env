#!/usr/bin/env bash
set -euo pipefail

build_env="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
projects="$(dirname "$build_env")"
repos=(
  opensagetv-vibe-build-env
  opensagetv-vibe-core
  opensagetv-vibe-container
  opensagetv-vibe-ffmpeg-mim
  opensagetv-vibe-FFmpeg-Plugin
  opensagetv-vibe-core-MCP-Plugin
  opensagetv-vibe-Xmltv-Plugin
  opensagetv-vibe-tmdb-Plugin
  opensagetv-vibe-logo
  opensagetv-vibe-android-client
  opensagetv-vibe-sagemc-Plugin
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

grep -Fq 'components/tmdb' "$build_env/scripts/package-release.sh"
grep -Fq 'OpenSageTVVibeTMDB-plugin.zip' "$build_env/scripts/package-release.sh"
grep -Fq 'opensagetv-vibe-tmdb.plugin.xml' "$build_env/scripts/package-release.sh"
grep -Fq 'TMDB_ATTRIBUTION.md' "$build_env/scripts/package-release.sh"
grep -Fq -- '--repo tmdb "$tmdb"' "$build_env/scripts/package-release.sh"
grep -Fq -- '--tmdb-version-file "$tmdb/release.properties"' "$build_env/scripts/package-release.sh"
grep -Fq '"tmdb": "https://github.com/opensagetv-vibe/opensagetv-vibe-tmdb-Plugin.git"' \
  "$build_env/scripts/generate-release-manifest.py"
echo 'PASS: unified release stages and records the standalone TMDB component'

grep -Fq 'components/ffmpeg-plugin' "$build_env/scripts/package-release.sh"
grep -Fq -- '--repo ffmpeg_plugin "$ffmpeg_plugin"' "$build_env/scripts/package-release.sh"
grep -Fq -- '--ffmpeg-plugin-version-file "$ffmpeg_plugin/release.properties"' "$build_env/scripts/package-release.sh"
grep -Fq '"ffmpeg_plugin": "https://github.com/opensagetv-vibe/opensagetv-vibe-FFmpeg-Plugin.git"' \
  "$build_env/scripts/generate-release-manifest.py"
echo 'PASS: unified release stages and records the stock-server FFmpeg plugin'

grep -Fq 'components/core-mcp-plugin' "$build_env/scripts/package-release.sh"
grep -Fq -- '--repo core_mcp "$core_mcp"' "$build_env/scripts/package-release.sh"
grep -Fq -- '--core-mcp-version-file "$core_mcp/release.properties"' "$build_env/scripts/package-release.sh"
grep -Fq '"core_mcp": "https://github.com/opensagetv-vibe/opensagetv-vibe-core-MCP-Plugin.git"' \
  "$build_env/scripts/generate-release-manifest.py"
echo 'PASS: unified release stages and records the stock-server Core MCP plugin'

python3 - "$build_env/config/github-projects.toml" <<'PY'
import sys
import tomllib
with open(sys.argv[1], 'rb') as source:
    projects = {row['name']: row for row in tomllib.load(source)['projects']}
companion = projects['opensagetv-vibe-client-extension-Plugin']
assert companion['workflow'] == 'Repository checks'
assert companion.get('publish', True)
assert projects['opensagetv-vibe-archive']['publish'] is False
PY
echo 'PASS: Client Extension source follows the shared GitHub gate; archive stays private'

for controller in opensagetv-vibe-dev.sh opensagetv-vibe-dev.ps1; do
  grep -Fq 'org.opensagetv.vibe.xmltv-project-name' "$build_env/$controller"
  grep -Fq 'opensagetv-vibe-Xmltv-Plugin:/workspace/xmltv-import' "$build_env/$controller"
done
grep -Fq 'opensagetv-vibe-Xmltv-Plugin:package)' "$build_env/scripts/component-dev.sh"
grep -Fq '.deps/stock/Sage.jar' "$build_env/scripts/component-dev.sh"
grep -Fq "'opensagetv-vibe-Xmltv-Plugin' = 'main'" "$build_env/checkout-all.ps1"
grep -Fq '"$repository" == opensagetv-vibe-Xmltv-Plugin ]]; then branch=main' "$build_env/checkout-all.sh"
echo 'PASS: XMLTV rename refreshes stale mounts and uses stock Core for packaging'

for controller in opensagetv-vibe-dev.sh opensagetv-vibe-dev.ps1; do
  grep -Fq 'org.opensagetv.vibe.ffmpeg-plugin-project-name' "$build_env/$controller"
  grep -Fq 'opensagetv-vibe-FFmpeg-Plugin' "$build_env/$controller"
  grep -Fq '/workspace/ffmpeg-plugin' "$build_env/$controller"
  grep -Fq 'opensagetv-vibe-WebClient-Plugin' "$build_env/$controller"
  grep -Fq 'opensagetv-vibe-tmdb-Plugin:/workspace/tmdb' "$build_env/$controller" || \
    grep -Fq 'projects/opensagetv-vibe-tmdb-Plugin}' "$build_env/$controller"
done
grep -Fq -- "-cne 'opensagetv-vibe-Xmltv-Plugin'" "$build_env/opensagetv-vibe-dev.ps1"
echo 'PASS: canonical plugin source names preserve runtime manifest identities'

for controller in opensagetv-vibe-dev.sh opensagetv-vibe-dev.ps1; do
  grep -Fq 'opensagetv-vibe-sagemc-Plugin' "$build_env/$controller"
  grep -Fq 'canonical-plugin-names-v3-sagemc' "$build_env/$controller"
done
grep -Fq 'opensagetv-vibe-sagemc-Plugin:install)' "$build_env/scripts/component-dev.sh"
grep -Fq 'scripts/install_development.py' "$build_env/scripts/component-dev.sh"
echo 'PASS: SageMC plugin rename refreshes native mounts and uses bounded dev installation'
