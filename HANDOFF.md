# OpenSageTV Vibe build-environment handoff

## Web Client plugin integration — 2026-09-27

The unified environment now mounts `opensagetv-vibe-web-client-plugin`, exposes
`web-client-test|validate|build|all`, and includes it in the complete pipeline.
The image owns Servlet 3.1 plus pinned Playwright/Chromium browser-test tooling.
This changes the build environment only; public Web Client publication remains
blocked on its physical `.232` gates and explicit user approval.

## Standard takeover

Read `AGENTS.md`, `README.md`, `TASKS.md`, and `WORKFLOW.md`, then run
`dev.cmd test`, `dev.cmd validate`, and the appropriate build gate. Updates and
handoff packages use `artifacts/downloads` and the root update/package scripts.
Windows handoff wrappers must retain the `-ProjectRoot "%~dp0."` form; the dot
is intentional protection against native PowerShell's quoted trailing-backslash
argument parsing. The twelve-repository workflow contract enforces it.

## Current state

The unified build/release workflow is operational. On 2026-09-04 the one
development image was rebuilt with Buildx/BuildKit, persistent ccache, the
complete deterministic media-fixture toolchain, and the logo toolchain; its
current ID is
`sha256:fb832f6ccdcbc6df811a27eb4401958110505bac9f8abf9e38d86ed691bf6ed6`.
The only reusable development container remains `opensagetv-vibe-dev`.
Android component wrappers pass the invoking checkout path into that unified
container. The container is recreated with a different bind mount only when
an independent Android checkout is selected; its image, name, Gradle cache,
and ccache are retained. The v0.5.75-to-v0.5.85 independent update test proved
that the tests/build came from the worktree rather than the canonical source.
Java 11/17/8, Android SDK/NDK/platform-tools, bundletool, MCP, Docker socket,
Buildx 0.36.1, ccache, and Samba client checks pass. The intended persistent
volumes are `opensagetv-vibe-gradle-cache` and
`opensagetv-vibe-ccache`; no phase-specific containers are used.

The Dockerfile contract is `u26-j11-release-v8`. It adds a pinned isolated logo
Python environment (CairoSVG 2.9.0 and Pillow 12.3.0), libcairo/Fontconfig,
the mounted logo project, and automatic generation/validation/SHA-verified
Android installation. It also permanently includes
the deterministic DVD/video fixture authoring tools (`dvdauthor`, `spumux`,
`spuunmux`, ImageMagick, fontconfig, DejaVu fonts, FFmpeg, and ffprobe). The
rebuilt image and the one recreated reusable container pass all executable and
version checks. The logo pipeline passes all three unit tests, generates and
validates 25 Android-owned resources, installs them with bounded manifest
updates, and the packaged debug APK contains the complete drawable, launcher,
round-launcher, adaptive-foreground, and adaptive-background resource set. The
Android 1,286-file project manifest and complete twelve-repository handoff
workflow pass. A real 1920x1080i MPEG-2 TS fixture with synchronized visual/
audio pulses, dual AC-3, CEA-608/708, and its Comskip sidecar was generated and
probed inside that container. `dev.cmd test` and `dev.cmd validate` pass.

The current canonical local runtime images are production
`sha256:ac844ebf288eab9b3d9be5a77ef5038b5bb179e76ca44ffad3c3b8530bbd8286`
and debug
`sha256:f9b4f5177b003d7f5eb2fafa6dbe7b0d32993f5e60c9bdc3e39e958b51fd8dc2`.
Both record runtime-environment fingerprint
`4e0bae1443cf5f113495d3d3646912ec641c022a3ae4ba314fa9ec8ff5f8f9b7`.
`runtime-image-status` reports `runtime_image_rebuild_needed=false`, and a
normal `runtime-images` invocation exits without rebuilding. Project cleanup
reports zero dangling Vibe images.

Core, MIM, XMLTV, and Comskip now have verified component-only packages. Their
package/install/rollback self-tests all pass. MIM 0.4.7 was installed on the
isolated Unraid test instance by updating appdata and restarting only that
container; the protected production SageTV and OpenDCT instances retained
their prior start times. Appdata replacements persist across normal restarts;
the image reseeds a component only when its image fingerprint changes or an
explicit recovery reset is requested.

On 2026-08-29 `runtime-all` staged the clean current Core, FFmpeg/MIM, XMLTV,
and Android outputs, rebuilt production/debug images, passed the complete
runtime validation and release assembly, and exported the exact production
archive subsequently commissioned on Unraid. The production local image-store
ID is
`sha256:98aa13d5f93b9aa3110a6e33f09058d8cc0cbbffc2554fb89ef14d85d3354ea5`;
the portable archive config ID loaded by Unraid is
`sha256:fb6ebf551d9cc3fbf1ccfd1dffc6ef52aa1270f3edfbdbe9c5be90ad755858c0`.
Release provenance now records both explicitly instead of assuming they are
identical under Docker Desktop's containerd-backed image store.

Both host wrappers label the reusable container with a normalized sibling-
workspace identity. Moving to another checkout recreates the same named
container with correct bind mounts while preserving the shared Gradle cache;
Windows and WSL calls from the same checkout continue to reuse it.

The common workflow contract and isolated update-runner self-test pass on
2026-08-28. The latter proves automatic and explicit changed-files ZIP
application, all test/validate/build/install gates, and completed-state resume.
Use `create_workspace_handoff_zip.cmd` to produce the complete twelve-project
commissioning bundle under `artifacts/downloads`. Use
`install_workspace_handoff_zip.cmd [ZIP] [PROJECTS_ROOT]` when the outer ZIP
also needs to be extracted before applying its verified packages and running
all resumable gates.
An independently committed temporary sibling layout passed Android test,
validation, and clean build through that mechanism; the container is currently
restored to `C:/TMP_SAGETV_DOCKER/projects`.

On 2026-09-08 the reusable `opensagetv-vibe-tmdb` repository became the tenth
mounted component. Its root and unified `tmdb-test|validate|build|all` commands
pass in the existing image, including SQLite/cache/API regressions and actual
`Sage.jar` plugin binary linkage. Both checkout helpers and the complete
workspace handoff now include it; the isolated ten-package apply/test/validate/
build/install self-test passes. No toolchain-image rebuild was needed.
The `runtime-update-package tmdb` and `runtime-update-test tmdb` paths also pass;
the latter proves exact payload install, private-config preservation, and
rollback without rebuilding Docker.
The full pipeline and standalone `tmdb-consumer-test` command now compile the
actual SageMC and XMLTV adapters against one shared service fixture. Four SageMC
and four XMLTV workers completed 4,000 adapter operations and 12,000 service
calls without failure, proving simultaneous consumer isolation before runtime
commissioning.

On 2026-09-20 `opensagetv-vibe-SageTVFFmpegPlugin` became the eleventh
mounted component. The reusable container exposes its test, validation, build,
and all commands without an image rebuild. Checkout reconstruction, workspace
handoff ordering, release artifact staging, exact repository/version
provenance, SPDX coverage, and build-environment documentation now include the
plugin. Physical commissioning on `.232` and the non-Pro Fire TV verified the
stock-Sage.jar install/upgrade/repair/uninstall contract, VAAPI Fixed/MIM
recorded playback, two live channel changes, and HDMI video/audio continuity.
Publishing remains prohibited until the user gives final approval.

On 2026-09-20 `opensagetv-vibe-core-MCP-Plugin` became the twelfth mounted and
release-tracked component. Every production/debug Vibe server image now requires
its package during artifact staging, seeds its JAR into persistent appdata, and
registers the Standard plugin while preserving local security settings. The
clean runtime gate proved plugin loading and authenticated loopback health, and
the commissioned `.232` container loads version `0.1.1` from the rebuilt image
without modifying the plugin JAR in appdata by hand. The final production image
was loaded there with exported config ID
`sha256:c8813f8babe45a47293a15d2606809c5de49bfc5470dfce94a55e5c5107873b6`;
the server and plugin JAR hashes plus HTTP health match the local validated
build.

Java 11 remains the default server toolchain, while Android commands select
JDK 17 and the frozen comparison command selects JDK 8 per process. The
original Android integration gate passed 151 scaffold/static tests, 35 MCP
tests, full validation, and a clean 60-task build. The subsequently reviewed
v0.5.80 tree passed the larger gate and its current hash is recorded below.

Passed stages:

- Clean Core Java, native, server, ELF/JNI, system-libpng, malformed-PNG,
  startup, and shutdown tests.
- FFmpeg 9.0.1/MIM 0.4.5 Linux and Windows builds.
- Completed/growing/join/repeated-switch MIM A/V and teardown tests.
- XMLTV 3.5 build and complete regression suite.
- Standalone TMDB plugin build, shared SageMC/XMLTV consumer stress, release
  artifact staging, exact source/version provenance, and SPDX coverage.
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

The current Android v0.5.80 working tree was also revalidated independently
through this installed image: 174 scaffold/static tests, 35 MCP tests, full
source validation, and a clean 60-task build pass. Its current APK SHA-256 is
`60e1d19ab15968ef48e24691cfd14f8998ce0bc6e6e8bda960f6d65e8d8aa668`.

The twelve repositories now share the same location-independent root workflow,
resumable update gates, package directory, takeover documents, and
`create_ai_handoff_zip.cmd`. An isolated temporary Git fixture passed package
creation, path/hash/manifest validation, extraction, all four gates, and a
second completed-state resume run. The workspace handoff command packages and
applies all components in dependency order.

Python/MCP dependencies are installed from the exact transitive
`android-requirements.lock`; Android platform-tools are pinned and checked at
37.0.1. The Android repository owns its Gradle wrapper checksum, dependency
lockfiles, and artifact verification metadata. Authoritative image-version
metadata is after the expensive SDK installation layer, so component source
changes continue to reuse the installed image.

## Architecture invariants

- Development image: `opensagetv-vibe-build-env:u26-j11`.
- Reusable development container: `opensagetv-vibe-dev`.
- Intentional cache volume: `opensagetv-vibe-gradle-cache`.
- Intentional compiler cache volume: `opensagetv-vibe-ccache`.
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
For ordinary Core/MIM/XMLTV/Comskip changes, prefer
`runtime-update-package COMPONENT` and `runtime-update-test COMPONENT`; do not
rebuild the runtime image. `runtime-image-status` is the authoritative rebuild
decision. Windows host variables are explicitly forwarded through WSL and then
into Docker.

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

Source publication is approved under the `opensagetv-vibe` GitHub organization.
Publish this repository's reviewed source and commissioning scripts only. Do
not push the development or runtime Docker images to a registry; release them
as checksummed export files for offline `docker load` commissioning.
