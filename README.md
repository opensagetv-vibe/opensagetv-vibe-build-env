# OpenSageTV Vibe unified build environment

This repository is the single build, test, runtime-validation, and local-release
interface for OpenSageTV Vibe. One Ubuntu 26.04/OpenJDK 11 development image and
one reusable container build all supported component artifacts, construct the
production and debug server images, start a clean SageTV server, test it, and
assemble offline release media.

The public development image is `opensagetv-vibe-build-env:u26-j11`; the only
reusable development container is `opensagetv-vibe-dev`. Linux and Windows
FFmpeg toolchains are private stages in this Dockerfile. Normal use never
creates or manages a separate FFmpeg builder image or phase container.

## Required checkout layout

Check out these sibling repositories under one parent directory:

```text
opensagetv-vibe-build-env/
opensagetv-vibe-container/
opensagetv-vibe-core/
opensagetv-vibe-ffmpeg-mim/
opensagetv-vibe-xmltv-import/
```

`checkout-all.ps1` and `checkout-all.sh` create this layout. Pass
`-SkipArchive` or `--skip-archive` when only the supported build graph is
needed. The helpers refuse to update a dirty repository. Before publication,
or for an offline audit, they can clone independent objects from a local source
root and detach every supported repository at the commits in a resolved release
manifest:

```powershell
.\checkout-all.ps1 -SkipArchive `
  -SourceRoot C:\source\opensagetv-vibe `
  -ResolvedManifest C:\release\release-manifest.json
```

```bash
OPENSAGETV_VIBE_SOURCE_ROOT=/source/opensagetv-vibe \
OPENSAGETV_VIBE_RESOLVED_MANIFEST=/release/release-manifest.json \
  ./checkout-all.sh --skip-archive
```

Local clones use `--no-local`, so they do not borrow Git objects from the source
repositories. Without these options the helpers continue to clone the planned
GitHub organization and branch heads.

## One-command build

Windows Docker Desktop:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\opensagetv-vibe-dev.ps1 all
```

Linux:

```bash
./opensagetv-vibe-dev.sh all
```

Docker is the only host build dependency. The first invocation builds the
development image if it is absent. Source repositories are bind-mounted, so
source edits do not require an image rebuild.

`all` performs, in order:

1. Ubuntu, Java, toolchain, mount, and Docker-daemon validation.
2. Clean SageTV Core Java/native build, tests, ELF/JNI/PNG validation, server
   smoke tests, and packaging.
3. Linux x64 and Windows x64 FFmpeg 9.0.1/MIM builds.
4. MIM lifecycle, growing-file, join-in-progress, A/V integrity, and teardown
   tests.
5. XMLTV compilation and all importer regression tests.
6. Exact-hash staging of Core, Linux MIM, and XMLTV runtime artifacts.
7. Linux/amd64 production and debug runtime image builds.
8. Clean-appdata health, supervised JVM recovery, repeated container restart
   soak, SageTV UDP discovery, TCP service, XMLTV selection, OpenDCT protocol,
   lifecycle metrics, and resource-cleanup validation.
9. Exact source/image/artifact manifest, SHA-256 files, SPDX 2.3 SBOMs,
   compressed Docker exports, and the versioned release bundle.

Any failed stage writes `BUILD FAILED`, records the failed stage in
`output/BUILD_REPORT.md`, and returns non-zero. A successful run prints
`BUILD PASSED`.

## Commands

| Command | Purpose |
|---|---|
| `image` | Build the pinned private toolchain stages and unified image |
| `start` | Create or start the one reusable development container |
| `all` | Clean-build, test, build images, run the server, and package everything |
| `core` | Run the complete Core Ubuntu 26 build/test/package suite |
| `ffmpeg-linux`, `ffmpeg-windows` | Build one FFmpeg/MIM target |
| `ffmpeg-info` | Validate both toolchains, Docker access, and container source mount |
| `test-mim` | Run all non-Android MIM lifecycle and real-media tests |
| `xmltv` | Build and test only the XMLTV importer JAR |
| `runtime-stage` | Validate and stage already-built runtime artifacts |
| `runtime-images` | Build production and debug runtime images |
| `runtime-test` | Start a clean runtime and test lifecycle/health/network/plugin behavior |
| `release` | Reassemble manifests, SBOMs, checksums, image exports, and bundle |
| `runtime-all` | Run staging, runtime image, runtime test, and release stages |
| `shell` | Enter the same reusable development container |
| `clean` | Remove generated outputs, preserving the container, cache, and images |
| `stop`, `remove-dev` | Stop or deliberately remove only the development container |

The container mounts the Docker socket to build and validate runtime images.
That socket grants the development container control of the host Docker daemon;
use this workflow only with trusted source.

## Runtime restart soak

`runtime-test`, `runtime-all`, and `all` use the same temporary SageTV
container for one supervisor-controlled JVM recovery and three full container
restarts. Each pass requires TCP readiness, healthy state, Tini PID 1, zero
zombies, a live Java PID file, and bounded descriptor, thread, and RSS growth.
To run more cycles from Windows:

```powershell
$env:OPENSAGETV_VIBE_RESTART_CYCLES='10'
.\opensagetv-vibe-dev.ps1 runtime-test
```

The Linux wrapper accepts the same environment variable. Values below two are
rejected. Advanced timeout and metric-growth limits are documented in
`opensagetv-vibe-container/tests/runtime-restart-soak.sh`.

## Optional commissioned OpenDCT scan

The deterministic OpenDCT V3 mock-wire test always runs. A physical scan also
runs when all three variables are set on the host; the wrappers forward them
into the reusable container:

```powershell
$env:OPENDCT_TEST_HOST='192.168.10.10'
$env:OPENDCT_TEST_PORT='9000'
$env:OPENDCT_TEST_ENCODER='atsc_hdhomerun_10703705'
.\opensagetv-vibe-dev.ps1 runtime-test
```

If they are absent, the report says `SKIPPED` and why; it never records a false
physical-scan pass.

## Outputs and offline Unraid loading

Final output is under `output/`:

```text
output/BUILD_REPORT.md
output/CORE_BUILD_REPORT.md
output/SHA256SUMS
output/packages/opensagetv-vibe-9.2.10-u26-j11.tar.zst
output/releases/opensagetv-vibe-9.2.10-u26-j11/
```

The release directory contains Core, Linux/Windows FFmpeg/MIM, XMLTV, the CA
template, separated build/container documentation, two compressed Docker image
archives, SPDX SBOMs, exact commits/image IDs/artifact hashes, and a release
checksum file.

Copy the versioned release directory to a low-power Unraid server, then run
these commands from that directory:

```bash
sha256sum -c SHA256SUMS
gzip -dc images/opensagetv-vibe-server-u26-gpu-j11.tar.gz | docker load
```

Install the CA XML and commission the clean appdata path documented by the
container repository. No SageTV settings or appdata are included in the build
or release bundle.

MIM is included but remains `MIM_ENABLED=false` until the separate Android
MiniClient and physical AMD/NVIDIA release gates pass. Hardware decode defaults
to enabled and falls back to software when device initialization is unavailable.
