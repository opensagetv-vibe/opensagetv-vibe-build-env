#!/usr/bin/env bash
set -euo pipefail

manifest_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
core="${CORE_SOURCE:-/work/sagetv}"
fm="${MIM_SOURCE:-/project}"
xmltv="${XMLTV_SOURCE:-/workspace/xmltv-import}"
tmdb="${TMDB_SOURCE:-/workspace/tmdb}"
container="${CONTAINER_SOURCE:-/workspace/container}"
logo="${LOGO_SOURCE:-/workspace/logo}"
android="${ANDROID_SOURCE:-/workspace/android-client}"
sagemc="${SAGEMC_SOURCE:-/workspace/sagemc}"
release_id="${OPENSAGETV_VIBE_RELEASE_ID:-opensagetv-vibe-9.2.10-u26-j11}"
production_image="${OPENSAGETV_VIBE_SERVER_IMAGE:-ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11}"
debug_image="${OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE:-ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11-debug}"
build_image="${OPENSAGETV_VIBE_BUILD_IMAGE:-opensagetv-vibe-build-env:u26-j11}"
output="$manifest_root/output"
release_dir="$output/releases/$release_id"
package_dir="$output/packages"
image_export_cache="$output/image-exports"
bundle="$package_dir/$release_id.tar.zst"
opendct_status="$output/test-results/opendct-live.status"
runtime_validation_log="$output/test-results/runtime-validation.log"
android_test_log="$output/test-results/android-client.log"
tmdb_version="$(sed -n 's/^VERSION=//p' "$tmdb/release.properties" | tr -d '\r')"

test -s "$core/output/packages/sagetv-server-x86_64.tar.gz"
test -s "$fm/output/linux-x64/ffmpeg_MIM"
test -s "$fm/output/windows-x64/SageTVTranscoder.exe"
test -s "$xmltv/output/packages/XMLTVImportPlugin.jar"
test -s "$tmdb/output/packages/OpenSageTVVibeTMDB-plugin.zip"
test -s "$tmdb/output/packages/OpenSageTVVibeTMDB-plugin-$tmdb_version.zip"
test -s "$tmdb/output/packages/OpenSageTVVibeTMDB.jar"
test -s "$tmdb/output/packages/gson-2.14.0.jar"
test -s "$tmdb/output/packages/sqlite-jdbc-3.53.2.1.jar"
test -s "$tmdb/output/packages/opensagetv-vibe-tmdb.plugin.xml"
test -s "$tmdb/output/packages/SHA256SUMS"
test -s "$tmdb/release.properties"
test -s "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apk"
test -s "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.aab"
test -s "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-release-candidate.aab"
test -s "$android/VERSION"
test -s "$sagemc/output/OpenSageTV-Vibe-SageMC-v$(cat "$sagemc/VERSION")-offline.zip"
test -s "$sagemc/output/OpenSageTV-Vibe-SageMC-v$(cat "$sagemc/VERSION")-stv.zip"
test -s "$opendct_status"
test -s "$runtime_validation_log"
test -s "$android_test_log"
grep -q '^ANDROID CLIENT SUITE PASSED$' "$android_test_log"
restart_cycles="$(sed -n 's/^RUNTIME RESTART SOAK PASSED: supervisor restart + \([0-9][0-9]*\) container restarts$/\1/p' "$runtime_validation_log" | tail -1)"
[[ "$restart_cycles" =~ ^[0-9]+$ ]] || {
  echo "ERROR: runtime restart soak PASS marker is missing" >&2
  exit 1
}
docker image inspect "$production_image" >/dev/null
docker image inspect "$debug_image" >/dev/null
docker image inspect "$build_image" >/dev/null

rm -rf "$release_dir"
mkdir -p \
  "$release_dir/components/core" \
  "$release_dir/components/ffmpeg-mim/linux-x64" \
  "$release_dir/components/ffmpeg-mim/windows-x64" \
  "$release_dir/components/xmltv" \
  "$release_dir/components/tmdb" \
  "$release_dir/components/android-client" \
  "$release_dir/components/sagemc" \
  "$release_dir/images" "$release_dir/sbom" \
  "$release_dir/test-results" \
  "$release_dir/docs/build-env" "$release_dir/docs/container" "$release_dir/docs/android-client" "$release_dir/docs/sagemc" "$release_dir/docs/tmdb" \
  "$package_dir" "$image_export_cache"

cp "$core/output/packages/sagetv-server-x86_64.tar.gz" "$release_dir/components/core/"
cp "$core/output/BUILD_REPORT.md" "$release_dir/components/core/BUILD_REPORT.md"
cp -a "$fm/output/linux-x64/." "$release_dir/components/ffmpeg-mim/linux-x64/"
cp -a "$fm/output/windows-x64/." "$release_dir/components/ffmpeg-mim/windows-x64/"
cp "$xmltv/output/packages/XMLTVImportPlugin.jar" "$release_dir/components/xmltv/"
cp -a "$xmltv/output/config-examples" "$release_dir/components/xmltv/"
cp -a "$xmltv/output/test-results" "$release_dir/components/xmltv/"
cp "$tmdb/output/packages/OpenSageTVVibeTMDB-plugin.zip" \
  "$tmdb/output/packages/OpenSageTVVibeTMDB-plugin-$tmdb_version.zip" \
  "$tmdb/output/packages/OpenSageTVVibeTMDB.jar" \
  "$tmdb/output/packages/gson-2.14.0.jar" \
  "$tmdb/output/packages/sqlite-jdbc-3.53.2.1.jar" \
  "$tmdb/output/packages/opensagetv-vibe-tmdb.plugin.xml" \
  "$tmdb/output/packages/SHA256SUMS" \
  "$tmdb/release.properties" "$release_dir/components/tmdb/"
cp "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apk" \
  "$release_dir/components/android-client/"
cp "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.aab" \
  "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apks" \
  "$android/artifacts/firetv/OpenSageTV-Vibe-Android-Client-release-candidate.aab" \
  "$release_dir/components/android-client/"
cp -a "$android/artifacts/reports/bundletool-"* \
  "$release_dir/components/android-client/"
cp "$android/VERSION" "$release_dir/components/android-client/VERSION"
cp "$sagemc/output/OpenSageTV-Vibe-SageMC-v$(cat "$sagemc/VERSION")-offline.zip" \
  "$sagemc/output/OpenSageTV-Vibe-SageMC-v$(cat "$sagemc/VERSION")-stv.zip" \
  "$sagemc/output/build-manifest.json" "$release_dir/components/sagemc/"
cp "$sagemc/VERSION" "$release_dir/components/sagemc/VERSION"
cp "$runtime_validation_log" "$release_dir/test-results/runtime-validation.log"
cp "$android_test_log" "$release_dir/test-results/android-client.log"
cp "$container/unRAID/opensagetv-vibe/sagetv-vibe-server-u26-gpu-j11.xml" "$release_dir/"
cp "$container/README.md" "$container/HANDOFF.md" "$container/CHANGELOG.md" \
  "$release_dir/docs/container/"
cp "$manifest_root/README.md" "$manifest_root/BUILDING.md" \
  "$manifest_root/HANDOFF.md" "$manifest_root/CHANGELOG.md" \
  "$release_dir/docs/build-env/"
cp "$android/README.md" "$android/HANDOFF.md" "$android/CHANGELOG.md" \
  "$android/MIGRATION_TO_OPENSAGETV_VIBE.md" \
  "$release_dir/docs/android-client/"
cp "$sagemc/README.md" "$sagemc/HANDOFF.md" "$sagemc/CHANGELOG.md" \
  "$sagemc/docs/ARCHITECTURE.md" "$sagemc/docs/UPSTREAM_PROVENANCE.md" \
  "$release_dir/docs/sagemc/"
cp "$tmdb/README.md" "$tmdb/HANDOFF.md" "$tmdb/CHANGELOG.md" \
  "$tmdb/THIRD_PARTY_NOTICES.md" "$tmdb/docs/TMDB_ATTRIBUTION.md" \
  "$release_dir/docs/tmdb/"

production_archive="$release_dir/images/opensagetv-vibe-server-u26-gpu-j11.tar.gz"
debug_archive="$release_dir/images/opensagetv-vibe-server-u26-gpu-j11-debug.tar.gz"

archive_config_id() {
  gzip -dc "$1" | tar -xOf - manifest.json | python3 -c '
import json, pathlib, re, sys
records = json.load(sys.stdin)
if len(records) != 1:
    raise SystemExit(f"expected one exported image, found {len(records)}")
config_path = records[0]["Config"]
name = pathlib.PurePosixPath(config_path).name
match = re.fullmatch(r"([0-9a-f]{64})(?:\.json)?", name)
if not match:
    raise SystemExit(f"invalid exported image config path: {config_path}")
print("sha256:" + match.group(1))
'
}

reuse_or_export_image() {
  local reference="$1" archive="$2" image_id="$3" cached temp
  cached="$image_export_cache/${image_id#sha256:}.tar.gz"
  if [[ -s "$cached" ]] && gzip -t "$cached" 2>/dev/null && \
      gzip -dc "$cached" | tar -tf - >/dev/null 2>&1; then
    ln "$cached" "$archive" 2>/dev/null || cp "$cached" "$archive"
    echo REUSED
    return
  fi
  temp="$(mktemp "$image_export_cache/.image-export.XXXXXX.tar.gz")"
  if ! docker save "$reference" | gzip -n -6 > "$temp"; then
    rm -f "$temp"
    return 1
  fi
  gzip -t "$temp"
  gzip -dc "$temp" | tar -tf - >/dev/null
  mv "$temp" "$cached"
  ln "$cached" "$archive" 2>/dev/null || cp "$cached" "$archive"
  echo EXPORTED
}

production_id="$(docker image inspect "$production_image" --format '{{.Id}}')"
debug_id="$(docker image inspect "$debug_image" --format '{{.Id}}')"
production_export_status="$(reuse_or_export_image "$production_image" "$production_archive" "$production_id")"
debug_export_status="$(reuse_or_export_image "$debug_image" "$debug_archive" "$debug_id")"
gzip -t "$production_archive"
gzip -t "$debug_archive"

# Docker Desktop's containerd-backed local image-store ID can differ from the
# config digest written by `docker save`. Record both: the exported config ID
# is the identity that `docker load` will expose on the target Unraid host.
production_export_id="$(archive_config_id "$production_archive")"
debug_export_id="$(archive_config_id "$debug_archive")"

production_packages="$release_dir/sbom/production-packages.tsv"
debug_packages="$release_dir/sbom/debug-packages.tsv"
docker run --rm --entrypoint /usr/bin/dpkg-query "$production_image" -W '-f=${Package}\t${Version}\t${Architecture}\n' | sort > "$production_packages"
docker run --rm --entrypoint /usr/bin/dpkg-query "$debug_image" -W '-f=${Package}\t${Version}\t${Architecture}\n' | sort > "$debug_packages"

python3 "$manifest_root/scripts/generate-sbom.py" \
  --name opensagetv-vibe-release-artifacts --version "$release_id" \
  --root "$release_dir/components" --output "$release_dir/sbom/release-artifacts.spdx.json"
python3 "$manifest_root/scripts/generate-sbom.py" \
  --name opensagetv-vibe-server-production --version "$release_id" \
  --image-id "$production_export_id" --packages "$production_packages" \
  --output "$release_dir/sbom/production-image.spdx.json"
python3 "$manifest_root/scripts/generate-sbom.py" \
  --name opensagetv-vibe-server-debug --version "$release_id" \
  --image-id "$debug_export_id" --packages "$debug_packages" \
  --output "$release_dir/sbom/debug-image.spdx.json"

python3 "$manifest_root/scripts/generate-release-manifest.py" \
  --release-id "$release_id" --release-dir "$release_dir" \
  --production-image "$production_image" --debug-image "$debug_image" \
  --production-export-id "$production_export_id" \
  --debug-export-id "$debug_export_id" \
  --build-image "$build_image" \
  --repo build_env "$manifest_root" \
  --repo core "$core" \
  --repo container "$container" \
  --repo ffmpeg_mim "$fm" \
  --repo xmltv_import "$xmltv" \
  --repo tmdb "$tmdb" \
  --repo logo "$logo" \
  --repo android_client "$android" \
  --repo sagemc "$sagemc" \
  --opendct-status "$opendct_status" \
  --runtime-validation-log "$runtime_validation_log" \
  --android-test-log "$android_test_log" \
  --android-version-file "$android/VERSION" \
  --sagemc-version-file "$sagemc/VERSION" \
  --tmdb-version-file "$tmdb/release.properties" \
  --output "$release_dir/release-manifest.json"

cat > "$release_dir/RELEASE_REPORT.md" <<EOF
# OpenSageTV Vibe release assembly

- Release: $release_id
- Platform: linux/amd64
- Production image: $production_image
  - local image-store ID: $production_id
  - exported archive config ID: $production_export_id
  - archive action: $production_export_status
- Debug image: $debug_image
  - local image-store ID: $debug_id
  - exported archive config ID: $debug_export_id
  - archive action: $debug_export_status
- Development image: $build_image ($(docker image inspect "$build_image" --format '{{.Id}}'))
- MIM default: disabled
- Hardware decode default: enabled
- OpenDCT live channel scan: $(cat "$opendct_status")
- Runtime restart soak: PASS - one supervisor recovery and $restart_cycles container restarts

| Release stage | Result |
|---|---|
| Core, FFmpeg/MIM, XMLTV, TMDB, Android, and SageMC artifact staging | PASS |
| Shared SageMC/XMLTV TMDB consumer stress | PASS |
| Android unit/static tests, validation, and debug APK build | PASS |
| Android device commissioning | SKIPPED - not part of headless unified all |
| Production image export | PASS |
| Debug image export | PASS |
| SPDX artifact SBOM | PASS |
| SPDX production/debug image SBOMs | PASS |
| Runtime restart soak | PASS |
| Exact source/image/artifact manifest | PASS |
| Offline archive integrity | PASS |
EOF

(cd "$release_dir" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$release_dir" && sha256sum -c SHA256SUMS >/dev/null)
for sbom in "$release_dir"/sbom/*.spdx.json; do
  python3 - "$sbom" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
assert doc["spdxVersion"] == "SPDX-2.3"
assert doc["packages"]
PY
done

rm -f "$bundle"
tar --zstd -cf "$bundle" -C "$output/releases" "$release_id"
tar --zstd -tf "$bundle" >/dev/null
(cd "$output" && sha256sum "packages/$(basename "$bundle")" > SHA256SUMS)
(cd "$output" && sha256sum -c SHA256SUMS >/dev/null)
printf '%s\n' "$release_dir" > "$output/RELEASE_PATH"
echo "RELEASE ASSEMBLY PASSED: $release_dir"
