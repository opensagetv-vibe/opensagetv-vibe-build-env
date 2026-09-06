# Building with the unified container

## Prerequisites

- Docker Desktop on Windows, or Docker Engine on Linux/Unraid.
- An amd64 host with the eight supported build/release repositories checked out
  as siblings.
- Git only when using the checkout helpers. No compiler, Java, Gradle, Python,
  FFmpeg toolchain, or Ubuntu package is installed on the host.

The default development base is `ubuntu:26.04`, the Java baseline is OpenJDK
11, and the server target platform is Linux/amd64. FFmpeg 9.0.1 source and all
toolchain bases are pinned in the Dockerfile. Android commands explicitly use
the digest-pinned JDK 17 tree; the frozen v0.5.75 comparison build explicitly
uses JDK 8. Neither changes the image-wide Java 11 default.

For a pre-publication fresh-clone audit, first clone this build-environment
repository into an empty parent directory. Then run `checkout-all.ps1` with
`-SkipArchive`, `-SourceRoot`, and `-ResolvedManifest`; on Linux set
`OPENSAGETV_VIBE_SOURCE_ROOT` and `OPENSAGETV_VIBE_RESOLVED_MANIFEST` before
`checkout-all.sh --skip-archive`. The resulting repositories are independent
`--no-local` clones detached at the manifest commits. Run `all` from that fresh
build-environment checkout.

## Full clean build and release

Windows:

```powershell
cd opensagetv-vibe-build-env
.\opensagetv-vibe-dev.ps1 image   # only initially or after Dockerfile changes
.\opensagetv-vibe-dev.ps1 all
```

Linux:

```bash
cd opensagetv-vibe-build-env
./opensagetv-vibe-dev.sh image     # only initially or after Dockerfile changes
./opensagetv-vibe-dev.sh all
```

`all` invokes Core's clean script before compilation, so historical native or
Java build products are not reused. It then compiles both FFmpeg targets and
XMLTV and the Android debug client, stages only verified artifacts, builds both
runtime targets, starts a clean server, runs networking/integration tests, and
packages the release.
Runtime integration includes one supervisor-controlled JVM recovery and three
complete container restarts with health, Tini, zombie, descriptor, thread, and
RSS checks. Set `OPENSAGETV_VIBE_RESTART_CYCLES` to at least two before
`runtime-test` or `all` to change the cycle count.

To explicitly remove every generated component and release output first:

```powershell
.\opensagetv-vibe-dev.ps1 clean
.\opensagetv-vibe-dev.ps1 all
```

`clean` does not remove the reusable development container, its Gradle download
cache, the FFmpeg/MIM compiler cache, or the two canonical runtime images.
Runtime validation uses uniquely
labeled temporary containers, networks, and volumes and verifies they are gone
when the test exits.

## Iterative component work

Use the component commands documented in `README.md`; all run through
`docker exec` in `opensagetv-vibe-dev`. To inspect binaries or debug a failure:

```powershell
.\opensagetv-vibe-dev.ps1 shell
```

Inside that shell the component roots are:

```text
/work/sagetv                 Core
/project                     FFmpeg/MIM
/workspace/xmltv-import      XMLTV importer
/workspace/container         runtime/Unraid image
/workspace/logo              canonical artwork generator and build output
/workspace/android-client    Android client, MCP, tests, and APK output
/workspace/release-manifest  unified controller and final output
```

The host Docker socket is mounted at `/var/run/docker.sock`. Production and
debug images are therefore built and tested from this same development
container while Docker Engine remains the host daemon.

Android-only headless iteration uses the same container:

```powershell
.\opensagetv-vibe-dev.ps1 android-info
.\opensagetv-vibe-dev.ps1 android-test
.\opensagetv-vibe-dev.ps1 android-validate
.\opensagetv-vibe-dev.ps1 android-build
```

Each Android gate first runs the mounted logo pipeline. Logo-only iteration is
available through `logo-info`, `logo-test`, `logo-validate`, `logo-build`,
`logo-install`, and `logo-all` without starting another container.

Use `android-all` for those three gates together. `android-mcp` is an explicit
stdio/device operation and is not part of `all`; install, launch, and playback
commissioning must target only the protected Dev application identity.

## Runtime-only iteration

After component outputs already pass, avoid recompiling them:

```powershell
.\opensagetv-vibe-dev.ps1 runtime-stage
.\opensagetv-vibe-dev.ps1 runtime-images
.\opensagetv-vibe-dev.ps1 runtime-test
.\opensagetv-vibe-dev.ps1 release
```

Or run those four stages together with `runtime-all`. `runtime-stage` verifies
the Core gzip archive, XMLTV JAR, the MIM checksum set, and copy hashes before
the Docker context is changed.

`runtime-images` first hashes only the runtime-environment inputs and compares
that value with both installed image labels. If they match, no Docker build is
performed. Inspect this decision independently with:

```powershell
.\opensagetv-vibe-dev.ps1 runtime-image-status
```

Dockerfile, Ubuntu/Java/GPU runtime packages, system libraries, and container
entrypoint/supervisor changes require an image build. Core, MIM, XMLTV, and
Comskip application changes do not.

## Component-only appdata updates

After the relevant component build/test succeeds:

```powershell
.\opensagetv-vibe-dev.ps1 runtime-update-package mim
.\opensagetv-vibe-dev.ps1 runtime-update-test mim
```

Use `core`, `mim`, `xmltv`, or `comskip`; use `all` only with the test command.
The package and SHA-256 sidecar are under the container repository's
`output/component-updates`. Transfer both to the low-CPU Unraid server or use
`opensagetv-vibe-container/scripts/deploy-component-update.sh`. The installer
targets the isolated Vibe container by default, creates a timestamped appdata
backup, performs atomic replacements, restarts only that container, and runs a
component health check. It does not rebuild/reload Docker and it does not
restart production SageTV or OpenDCT.

## Commissioned OpenDCT test

Set `OPENDCT_TEST_HOST`, `OPENDCT_TEST_PORT`, and `OPENDCT_TEST_ENCODER` before
`runtime-test` or `all`. The host wrappers forward these settings, the restart
soak settings, and the supported release/image overrides. Without all three
OpenDCT settings, the physical scan is reported as `SKIPPED`; the deterministic
mock-protocol test still runs.

## Release integrity

Verify the complete bundle in the development container:

```bash
cd /workspace/release-manifest/output
sha256sum -c SHA256SUMS
tar --zstd -tf packages/opensagetv-vibe-9.2.10-u26-j11.tar.zst >/dev/null
cd releases/opensagetv-vibe-9.2.10-u26-j11
sha256sum -c SHA256SUMS
```

The resolved JSON manifest is generated, not hand-maintained. It records each
component commit and semantic dirty state (host-only CRLF checkout conversion
is ignored), image ID/size/platform, release policy, and
the size and SHA-256 of every packaged artifact. Three SPDX 2.3 JSON documents
cover release files and the installed Debian packages in both runtime images.

## Low-CPU Unraid transfer

Build and test on a faster Windows/Linux amd64 Docker host. Transfer the
versioned release directory, or at minimum its production image, CA XML, and
matching checksum information. From a complete release directory on Unraid,
validate it and load without recompiling:

```bash
sha256sum -c SHA256SUMS
gzip -t images/opensagetv-vibe-server-u26-gpu-j11.tar.gz
gzip -dc images/opensagetv-vibe-server-u26-gpu-j11.tar.gz | docker load
docker image inspect ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11
```

The `ghcr.io/...` text is only the canonical tag stored inside the exported
Docker archive. The workflow does not upload that tag to GHCR. `docker load`
creates it locally on Unraid from the transferred file.

Use a new appdata directory. The release contains no current server database,
properties, recordings, passwords, or other commissioned state.
