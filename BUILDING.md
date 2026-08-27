# Building with the unified container

## Prerequisites

- Docker Desktop on Windows, or Docker Engine on Linux/Unraid.
- An amd64 host with the five supported repositories checked out as siblings.
- Git only when using the checkout helpers. No compiler, Java, Gradle, Python,
  FFmpeg toolchain, or Ubuntu package is installed on the host.

The default development base is `ubuntu:26.04`, the Java baseline is OpenJDK
11, and the target platform is Linux/amd64. FFmpeg 9.0.1 source and all
toolchain bases are pinned in the Dockerfile.

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
XMLTV, stages only verified artifacts, builds both runtime targets, starts a
clean server, runs networking/integration tests, and packages the release.

To explicitly remove every generated component and release output first:

```powershell
.\opensagetv-vibe-dev.ps1 clean
.\opensagetv-vibe-dev.ps1 all
```

`clean` does not remove the reusable development container, its Gradle download
cache, or the two last known runtime images. Runtime validation uses uniquely
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
/workspace/release-manifest  unified controller and final output
```

The host Docker socket is mounted at `/var/run/docker.sock`. Production and
debug images are therefore built and tested from this same development
container while Docker Engine remains the host daemon.

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

## Commissioned OpenDCT test

Set `OPENDCT_TEST_HOST`, `OPENDCT_TEST_PORT`, and `OPENDCT_TEST_ENCODER` before
`runtime-test` or `all`. The host wrappers forward only these test variables and
the supported release/image overrides. Without all three, the physical scan is
reported as `SKIPPED`; the deterministic mock-protocol test still runs.

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

Use a new appdata directory. The release contains no current server database,
properties, recordings, passwords, or other commissioned state.
