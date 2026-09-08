# OpenSageTV Vibe unified build environment

This repository is the single build, test, runtime-validation, and local-release
interface for OpenSageTV Vibe. One Ubuntu 26.04/OpenJDK 11 development image and
one reusable container build all supported component artifacts, construct the
production and debug server images, start a clean SageTV server, test it, and
assemble offline release media. The same image also carries explicitly selected
JDK 17/JDK 8 and Android SDK tooling for the Android MiniClient, plus the pinned
CairoSVG/Pillow/Fontconfig logo toolchain; Java 11 remains the global/default
SageTV server toolchain.

The public development image is `opensagetv-vibe-build-env:u26-j11`; the only
reusable development container is `opensagetv-vibe-dev`. Linux and Windows
FFmpeg toolchains are private stages in this Dockerfile. Normal use never
creates or manages a separate FFmpeg builder image or phase container.

The Docker image names used by the scripts are local build tags. This project
does not push development or SageTV runtime images to GHCR or another registry.
Commissioning output is a checksummed compressed Docker image file plus the
matching Unraid CA template and documentation; load that file on the target
server with `docker load`.

All repositories use the takeover/update contract documented in
[`WORKFLOW.md`](WORKFLOW.md). This repository also supports the same root
`dev.cmd`/`dev.sh`, `update.cmd`/`update.sh`, and
`create_ai_handoff_zip.cmd` interface as every component.

Create one handoff containing the verified changed-files packages for all ten
sibling repositories with:

```bat
create_workspace_handoff_zip.cmd
```

The bundle is written under `artifacts/downloads` and includes
`APPLY_WORKSPACE_HANDOFF.cmd`, which safely validates, extracts, tests,
validates, builds, and installs every component in dependency order.
From an existing build-environment checkout, run
`install_workspace_handoff_zip.cmd [ZIP] [PROJECTS_ROOT]` to extract the outer
bundle into an isolated temporary directory and invoke that complete workflow.
With no ZIP argument it selects the newest workspace bundle in
`artifacts/downloads`.

## Required checkout layout

Check out these sibling repositories under one parent directory:

```text
opensagetv-vibe-build-env/
opensagetv-vibe-container/
opensagetv-vibe-core/
opensagetv-vibe-ffmpeg-mim/
opensagetv-vibe-xmltv-import/
opensagetv-vibe-tmdb/
opensagetv-vibe-logo/
opensagetv-vibe-android-client/
opensagetv-vibe-sagemc/
opensagetv-vibe-archive/
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
source edits do not require an image rebuild. The wrapper records a normalized
sibling-workspace identity on the named container; invoking it from a different
checkout recreates that same container with the new bind mounts instead of
running against an older checkout. The named Gradle cache is retained.
FFmpeg/MIM compiler objects use the separate persistent
`opensagetv-vibe-ccache` volume. Docker BuildKit owns image-layer caching;
normal cleanup removes only obsolete Vibe image objects and never prunes
unrelated Docker resources or either named cache.

Android's Python/MCP environment is installed from the exact transitive
`android-requirements.lock`, and the image verifies the pinned platform-tools
revision. The Android component owns its Gradle distribution checksum,
dependency lockfiles, and artifact checksum metadata. Change the Dockerfile or
these image-owned locks only when the toolchain actually changes; ordinary
component source edits continue to use the installed image and container.
The image also includes Ubuntu's `smbclient`, which the Android MCP fixture
workflow uses to publish deterministic playback media and Comskip sidecars to
an SMB2/SMB3 commissioning share without adding a second utility container.

`all` performs, in order:

1. Ubuntu, Java, toolchain, mount, and Docker-daemon validation.
2. Clean SageTV Core Java/native build, tests, ELF/JNI/PNG validation, server
   smoke tests, and packaging.
3. Linux x64 and Windows x64 FFmpeg 9.0.1/MIM builds.
4. MIM lifecycle, growing-file, join-in-progress, A/V integrity, and teardown
   tests.
5. XMLTV compilation and all importer regression tests.
6. Reusable TMDB service Java 8 compilation, SQLite/cache/API regression tests,
   and artifact packaging.
7. Canonical logo generation, 25-resource validation, and SHA-verified Android
   resource synchronization.
8. SageMC Studio graph/API/reference tests and deterministic plugin packaging.
9. Android client unit/static and MCP tests, source validation, and a clean
   deterministic debug APK build under JDK 17. Device operations are excluded.
10. Exact-hash staging of Core, Linux MIM, and XMLTV runtime artifacts.
11. Linux/amd64 production and debug runtime image builds.
12. Clean-appdata health, supervised JVM recovery, repeated container restart
   soak, SageTV UDP discovery, TCP service, XMLTV selection, OpenDCT protocol,
   lifecycle metrics, and resource-cleanup validation.
13. Exact source/image/artifact manifest, SHA-256 files, SPDX 2.3 SBOMs,
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
| `tmdb-test`, `tmdb-validate`, `tmdb-build`, `tmdb-all` | Test, validate, package, or run all gates for the reusable TMDB service |
| `logo-info` | Report the pinned logo Python/CairoSVG/Pillow/font environment |
| `logo-test`, `logo-validate` | Run logo unit tests or validate all generated assets |
| `logo-build`, `logo-install` | Generate canonical assets or atomically synchronize them into Android |
| `logo-all` | Test, generate, validate, and install the complete logo asset set |
| `android-info` | Prove Java isolation plus installed Android SDK/NDK/ADB/bundletool/MCP versions |
| `android-test`, `android-validate` | Run Android host/static tests or source validation |
| `android-build` | Clean-build the Dev APK with JDK 17 |
| `android-bundle` | Build and validate debug/release-candidate AABs plus the debug APK set |
| `android-bundle-install` | Package-check and install the debug AAB APK set on the configured device |
| `android-all` | Run tests, validation, deterministic APK/AAB builds, and bundletool validation together |
| `android-mcp` | Start the Android MCP stdio server; device commissioning remains explicit |
| `sagemc-test`, `sagemc-validate`, `sagemc-build`, `sagemc-all` | Audit, test, and package the SageMC modernization project |
| `runtime-stage` | Validate and stage already-built runtime artifacts |
| `runtime-images` | Build production and debug runtime images |
| `runtime-image-status` | Report the expected/installed runtime-environment fingerprints and whether an image rebuild is needed |
| `runtime-test` | Start a clean runtime and test lifecycle/health/network/plugin behavior |
| `runtime-update-package COMPONENT` | Create a verified `core`, `mim`, `xmltv`, `tmdb`, or `comskip` appdata update archive |
| `runtime-update-test COMPONENT|all` | Test component package, atomic install, restart health, and rollback without rebuilding Docker |
| `release` | Reassemble manifests, SBOMs, checksums, image exports, and bundle |
| `runtime-all` | Run staging, runtime image, runtime test, and release stages |
| `shell` | Enter the same reusable development container |
| `clean` | Remove generated outputs, preserving the container, cache, and images |
| `stop`, `remove-dev` | Stop or deliberately remove only the development container |

The container mounts the Docker socket to build and validate runtime images.
That socket grants the development container control of the host Docker daemon;
use this workflow only with trusted source.

## Fast component deployment versus image rebuild

The runtime image represents Ubuntu 26, Java 11, GPU/system libraries, and the
container supervisor. SageTV application payloads live in persistent appdata
after initial seeding. For a Core, FFmpeg/MIM, XMLTV, TMDB, or Comskip code change,
build that component, run `runtime-update-package`, copy the resulting archive
to Unraid, and restart only the selected SageTV test container. The installer
backs up replaced files and can roll them back.

Run `runtime-image-status` before any image build. `runtime-images` skips when
both canonical images already contain the expected environment fingerprint.
Rebuild only for Dockerfile, Ubuntu package, Java, GPU driver, system-library,
entrypoint/supervisor, or clean-baseline changes. To intentionally refresh an
otherwise identical image:

```powershell
$env:FORCE_RUNTIME_IMAGE_BUILD='true'
.\opensagetv-vibe-dev.ps1 runtime-images
Remove-Item Env:FORCE_RUNTIME_IMAGE_BUILD
```

The Windows wrapper explicitly carries supported settings through WSL before
forwarding them into `opensagetv-vibe-dev`; the Linux wrapper uses the same
allowlist.

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

The release directory contains Core, Linux/Windows FFmpeg/MIM, XMLTV, the
Android debug APK and test evidence, the CA
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
