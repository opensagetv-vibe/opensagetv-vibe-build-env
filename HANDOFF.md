# OpenSageTV Vibe build-environment handoff

## Current state

The unified build/release workflow is operational. On 2026-08-28 the Windows
Docker Desktop wrapper completed the full post-Android-integration `all`
pipeline with `BUILD PASSED` from the one reusable `opensagetv-vibe-dev`
container. The validated development image is
`sha256:327a6bc70b719e9111143b5cd3c8af8314aa9a71dc2b6cf3fe0ad9ed4e1b9983`.

Java 11 remains the default server toolchain, while Android commands select
JDK 17 and the frozen comparison command selects JDK 8 per process. The
Android gate passed 151 scaffold/static tests, 35 MCP tests, full validation,
and a clean 60-task build. Its APK SHA-256 remained byte-identical to Phase 1:
`839113f460fed5e6f37ec244ea6a2fbc574c32e5f9b131085c95a349bb364a69`.

Passed stages:

- Clean Core Java, native, server, ELF/JNI, system-libpng, malformed-PNG,
  startup, and shutdown tests.
- FFmpeg 9.0.1/MIM 0.4.5 Linux and Windows builds.
- Completed/growing/join/repeated-switch MIM A/V and teardown tests.
- XMLTV 3.5 build and complete regression suite.
- Android v0.5.75 tests, validator, and deterministic Dev APK build.
- Exact runtime artifact staging.
- Ubuntu 26.04/OpenJDK 11 production and debug runtime image builds.
- Clean runtime health, one supervised JVM recovery, three complete container
  restart cycles, zero zombies, bounded descriptor/thread/RSS metrics, real UDP
  discovery response, TCP 42024 connection, XMLTV no-license auto-selection,
  OpenDCT V3 mock-wire behavior, and cleanup.
- Exact manifest, SHA-256 sets, three SPDX 2.3 SBOMs, compressed image exports,
  and versioned `.tar.zst` release bundle.

Release assembly refuses a missing or incomplete runtime-soak log. The log is
included under `test-results/`, hashed by the inner checksum set, and summarized
with its exact container-restart count in `release-manifest.json`.

The live physical OpenDCT/HDHomeRun scan was `SKIPPED` because this workstation
had no commissioned endpoint. The harness accepts explicit endpoint variables
and must be rerun on the target network. Android MiniClient and physical
AMD/NVIDIA commissioning remain product release gates, not build-environment
failures. MIM therefore remains disabled by default.

## Architecture invariants

- Development image: `opensagetv-vibe-build-env:u26-j11`.
- Reusable development container: `opensagetv-vibe-dev`.
- Intentional cache volume: `opensagetv-vibe-gradle-cache`.
- Runtime images are outputs, not development environments.
- FFmpeg Linux/Windows toolchains are private Docker stages owned here.
- Android SDK 29/36, NDK 21, JDK 17/JDK 8, ADB, and MCP are owned here; they
  do not change the image-wide Java 11 default.
- Android source is bind-mounted at `/workspace/android-client`, with its
  Gradle cache namespaced under the existing shared cache volume.
- No phase-specific build containers or separately managed FFmpeg builder image.
- Every component source and final output directory is bind-mounted.
- Runtime tests may create only labeled, temporary resources and must clean them
  even on error.

The Docker socket is deliberately mounted so the same development container can
build and run the server images. This is a privileged trust boundary and must
remain documented.

## Reproduction

Run `opensagetv-vibe-dev.ps1 all` on Windows Docker Desktop or
`opensagetv-vibe-dev.sh all` on Linux. `image` is needed only when the unified
Dockerfile/build dependencies change. `runtime-all` is the quick post-component
path for artifact staging, runtime image/test, and release regeneration.

The authoritative results are:

```text
output/BUILD_REPORT.md
output/CORE_BUILD_REPORT.md
../opensagetv-vibe-android-client/artifacts/firetv/OpenSageTV-Vibe-Android-Client-debug.apk
output/releases/opensagetv-vibe-9.2.10-u26-j11/RELEASE_REPORT.md
output/releases/opensagetv-vibe-9.2.10-u26-j11/release-manifest.json
output/releases/opensagetv-vibe-9.2.10-u26-j11/SHA256SUMS
```

Do not hand-edit the resolved JSON manifest or SBOMs. Regenerate them with
`release` after any artifact, image, documentation, or source-revision change.

For an exact pre-publication fresh-clone audit, bootstrap a clean copy of this
repository and give `checkout-all.ps1` a local `-SourceRoot` plus the prior
resolved `-ResolvedManifest`. The Linux helper uses the equivalent
`OPENSAGETV_VIBE_SOURCE_ROOT` and `OPENSAGETV_VIBE_RESOLVED_MANIFEST`
variables. Both paths use independent Git objects and detached manifest
commits; omit those settings after the GitHub repositories are published.

## Next commissioning work

The remaining target-hardware work is tracked in the workspace `task.md`:
physical host and `br0` discovery, a real OpenDCT/HDHomeRun scan, Intel/AMD/
NVIDIA device tests, Android MiniClient live playback, and a clean Unraid
commissioning/reload of the exact exported image. Keep MIM disabled until those
independent gates pass.

No repository or release has been pushed. Publication remains explicitly out of
scope until approved by the repository owner.
