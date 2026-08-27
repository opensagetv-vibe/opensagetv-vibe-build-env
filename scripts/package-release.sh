#!/usr/bin/env bash
set -euo pipefail

manifest_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
core="${CORE_SOURCE:-/work/sagetv}"
fm="${MIM_SOURCE:-/project}"
xmltv="${XMLTV_SOURCE:-/workspace/xmltv-import}"
container="${CONTAINER_SOURCE:-/workspace/container}"
release_id="${OPENSAGETV_VIBE_RELEASE_ID:-opensagetv-vibe-9.2.10-u26-j11}"
production_image="${OPENSAGETV_VIBE_SERVER_IMAGE:-ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11}"
debug_image="${OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE:-ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11-debug}"
output="$manifest_root/output"
release_dir="$output/releases/$release_id"
package_dir="$output/packages"
bundle="$package_dir/$release_id.tar.zst"
opendct_status="$output/test-results/opendct-live.status"

test -s "$core/output/packages/sagetv-server-x86_64.tar.gz"
test -s "$fm/output/linux-x64/ffmpeg_MIM"
test -s "$fm/output/windows-x64/SageTVTranscoder.exe"
test -s "$xmltv/output/packages/XMLTVImportPlugin.jar"
test -s "$opendct_status"
docker image inspect "$production_image" >/dev/null
docker image inspect "$debug_image" >/dev/null

rm -rf "$release_dir"
mkdir -p \
  "$release_dir/components/core" \
  "$release_dir/components/ffmpeg-mim/linux-x64" \
  "$release_dir/components/ffmpeg-mim/windows-x64" \
  "$release_dir/components/xmltv" \
  "$release_dir/images" "$release_dir/sbom" \
  "$release_dir/docs/build-env" "$release_dir/docs/container" \
  "$package_dir"

cp "$core/output/packages/sagetv-server-x86_64.tar.gz" "$release_dir/components/core/"
cp "$core/output/BUILD_REPORT.md" "$release_dir/components/core/BUILD_REPORT.md"
cp -a "$fm/output/linux-x64/." "$release_dir/components/ffmpeg-mim/linux-x64/"
cp -a "$fm/output/windows-x64/." "$release_dir/components/ffmpeg-mim/windows-x64/"
cp "$xmltv/output/packages/XMLTVImportPlugin.jar" "$release_dir/components/xmltv/"
cp -a "$xmltv/output/config-examples" "$release_dir/components/xmltv/"
cp -a "$xmltv/output/test-results" "$release_dir/components/xmltv/"
cp "$container/unRAID/opensagetv-vibe/sagetv-vibe-server-u26-gpu-j11.xml" "$release_dir/"
cp "$container/README.md" "$container/HANDOFF.md" "$container/CHANGELOG.md" \
  "$release_dir/docs/container/"
cp "$manifest_root/README.md" "$manifest_root/BUILDING.md" \
  "$manifest_root/HANDOFF.md" "$manifest_root/CHANGELOG.md" \
  "$release_dir/docs/build-env/"

production_archive="$release_dir/images/opensagetv-vibe-server-u26-gpu-j11.tar.gz"
debug_archive="$release_dir/images/opensagetv-vibe-server-u26-gpu-j11-debug.tar.gz"
docker save "$production_image" | gzip -n -6 > "$production_archive"
docker save "$debug_image" | gzip -n -6 > "$debug_archive"
gzip -t "$production_archive"
gzip -t "$debug_archive"
gzip -dc "$production_archive" | tar -tf - >/dev/null
gzip -dc "$debug_archive" | tar -tf - >/dev/null

production_packages="$release_dir/sbom/production-packages.tsv"
debug_packages="$release_dir/sbom/debug-packages.tsv"
docker run --rm --entrypoint /usr/bin/dpkg-query "$production_image" -W '-f=${Package}\t${Version}\t${Architecture}\n' | sort > "$production_packages"
docker run --rm --entrypoint /usr/bin/dpkg-query "$debug_image" -W '-f=${Package}\t${Version}\t${Architecture}\n' | sort > "$debug_packages"
production_id="$(docker image inspect "$production_image" --format '{{.Id}}')"
debug_id="$(docker image inspect "$debug_image" --format '{{.Id}}')"

python3 "$manifest_root/scripts/generate-sbom.py" \
  --name opensagetv-vibe-release-artifacts --version "$release_id" \
  --root "$release_dir/components" --output "$release_dir/sbom/release-artifacts.spdx.json"
python3 "$manifest_root/scripts/generate-sbom.py" \
  --name opensagetv-vibe-server-production --version "$release_id" \
  --image-id "$production_id" --packages "$production_packages" \
  --output "$release_dir/sbom/production-image.spdx.json"
python3 "$manifest_root/scripts/generate-sbom.py" \
  --name opensagetv-vibe-server-debug --version "$release_id" \
  --image-id "$debug_id" --packages "$debug_packages" \
  --output "$release_dir/sbom/debug-image.spdx.json"

python3 "$manifest_root/scripts/generate-release-manifest.py" \
  --release-id "$release_id" --release-dir "$release_dir" \
  --production-image "$production_image" --debug-image "$debug_image" \
  --repo build_env "$manifest_root" \
  --repo core "$core" \
  --repo container "$container" \
  --repo ffmpeg_mim "$fm" \
  --repo xmltv_import "$xmltv" \
  --opendct-status "$opendct_status" \
  --output "$release_dir/release-manifest.json"

cat > "$release_dir/RELEASE_REPORT.md" <<EOF
# OpenSageTV Vibe release assembly

- Release: $release_id
- Platform: linux/amd64
- Production image: $production_image ($production_id)
- Debug image: $debug_image ($debug_id)
- MIM default: disabled
- Hardware decode default: enabled
- OpenDCT live channel scan: $(cat "$opendct_status")

| Release stage | Result |
|---|---|
| Core, FFmpeg/MIM, and XMLTV artifact staging | PASS |
| Production image export | PASS |
| Debug image export | PASS |
| SPDX artifact SBOM | PASS |
| SPDX production/debug image SBOMs | PASS |
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
sha256sum "$bundle" > "$output/SHA256SUMS"
(cd "$output" && sha256sum -c SHA256SUMS >/dev/null)
printf '%s\n' "$release_dir" > "$output/RELEASE_PATH"
echo "RELEASE ASSEMBLY PASSED: $release_dir"
