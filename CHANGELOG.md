# Changelog

## Unreleased

- Made the canonical-and-Vibe current-Ubuntu container path the first build
  priority. Documented the stock-Core evidence lane for `google/sagetv` #516,
  #519, #528, and separable #529 changes plus the later focused
  `OpenSageTV/sagetv-dockers` runtime proposal.

- Added the workspace-wide GitHub change gate and authoritative project
  manifest for all Vibe repositories. It validates pre-push identity and Git
  state, enforces pilot-first sequential repository updates, verifies required
  PR and exact-head workflow checks, and validates release tag/asset-digest
  boundaries. The unpublished archive remains explicitly excluded until its
  Git LFS/publication policy is approved.

- Added the `opensagetv-vibe-web-client-plugin` mount and component commands to
  the reusable container and full build graph.
- Added the Servlet 3.1 API plus a pinned Playwright 1.63.0/Chromium environment
  as a late image layer for deterministic Web Client compilation and offline
  browser validation without invalidating the larger Android/FFmpeg layers.

## Unreleased

- Added `opensagetv-vibe-core-MCP-Plugin` as the twelfth unified component and
  made it a required input to every Vibe runtime image. Checkout reconstruction,
  reusable-container commands, workspace handoff, release staging, source and
  version provenance, and workflow contracts now include it.
- Added runtime seeding and preservation rules for the Core MCP plugin. Clean
  runtime validation now requires SageTV to load the plugin and return a healthy
  loopback endpoint before the container image can pass.

- Added `opensagetv-vibe-SageTVFFmpegPlugin` as the eleventh unified component.
- Completed its checkout, reusable-container command, workspace-handoff,
  release staging, exact-source manifest, SPDX, and documentation integration.
  The staged component contains deterministic Standard plugin, STVi,
  Linux/Windows launcher, rendered manifest, and checksum artifacts.
- Updated repository CI to the current Node 24-based
  `actions/checkout@v7` release. CI also locks executable Git metadata for the
  documented Linux entry points and maintained consumer-stress test.
- Added validated Docker image-export reuse keyed by exact local image ID.
  Metadata/plugin-only release assembly now reuses unchanged offline archives
  rather than recompressing both runtime images.
- Added the standalone TMDB canonical/versioned plugin ZIPs, V9 repository
  manifest, checksums, service/dependency JARs, attribution docs, source
  revision, and package version to unified release assembly. The
  release-artifact SPDX document covers every exact staged TMDB file.
- Added `opensagetv-vibe-tmdb` as the tenth unified component with a dedicated
  bind mount, checkout identity, root commands, clean handling, checkout
  reconstruction, and complete workspace handoff coverage. The installed image
  passed its tests/build and the ten-repository handoff self-test without an
  image rebuild.
- Added `tmdb` to targeted runtime component package/test handling. The
  install/rollback self-test preserves private configuration and now runs only
  the selected expensive component lifecycle for faster iteration.
- Added `tmdb-consumer-test` and the same mandatory full-pipeline stage. It
  exercises the real SageMC and XMLTV adapters simultaneously against one
  shared TMDB service for 4,000 adapter operations and 12,000 service calls.

- Added `opensagetv-vibe-sagemc` as the ninth workspace project. The unified
  container now mounts, audits, tests, validates, and packages SageMC; checkout,
  workspace-handoff, release-provenance, and common workflow contracts include
  it without rebuilding the development image.
- Made the common `release.properties` checks tolerant of CRLF files while
  retaining exact value validation on both Windows and Linux checkouts.

- Prepared `opensagetv-vibe-build-env` for public source development under the
  Apache License 2.0 with contribution, security, and third-party dependency
  notices plus read-only GitHub repository checks.
- Made registry policy explicit: development/runtime images remain local build
  products and are distributed only as checksummed commissioning export files;
  this repository does not push Docker images to GHCR or another registry.
- Updated the release manifest to FFmpeg/MIM 0.4.8, XMLTV 3.5.0, and Android
  client 0.5.85 and encoded the no-registry/export-file policy.

- Made the single reusable development container checkout-aware for Android.
  Android root scripts now pass their own absolute project root to the unified
  environment, which labels and mounts that exact checkout at
  `/workspace/android-client`. Switching between the canonical tree and an
  independent release-verification worktree recreates only
  `opensagetv-vibe-dev` with the new bind mount; the build image and both
  persistent caches are reused. This prevents an independent workflow from
  silently testing the canonical working tree.

- Fixed every Windows `create_ai_handoff_zip.cmd` wrapper to pass
  `-ProjectRoot "%~dp0."`. A quoted `%~dp0` ends in a backslash and can cause
  native Windows PowerShell to deliver a malformed value containing a quote or
  line ending to `Path.GetFullPath()`. The shared workflow contract now checks
  all eight wrappers so synchronized project workflows cannot reintroduce the
  failure.

- Added `opensagetv-vibe-logo` as the eighth workspace project and release
  provenance input. Build-environment contract v8 installs pinned CairoSVG,
  Pillow, libcairo, Fontconfig, and Python dependencies; mounts the logo source;
  exposes logo-only commands; and regenerates/validates/SHA-installs all Android
  artwork before every Android test, validation, build, bundle, or full gate.
  The rebuilt image, generated APK resource inventory, Android 1,286-file
  manifest, and complete eight-repository handoff workflow all pass.
  Logo component `all` now generates disposable output before validating it,
  so a clean checkout or updated image-mode contract cannot fail on stale
  generated artwork.

- Added bounded APT retries to the unified image dependency layer so a
  transient Ubuntu mirror/proxy fetch error does not invalidate an otherwise
  reproducible toolchain build.
- Bumped the unified image contract to `u26-j11-release-v7` and made the
  deterministic Android DVD/video fixture toolchain reproducible. Clean image
  builds now install and validate `dvdauthor`/`spumux`/`spuunmux`, ImageMagick,
  fontconfig, and DejaVu fonts alongside FFmpeg/ffprobe. `android-info` records
  the authoring tool/font versions; the shared workflow contract prevents these
  packages or executable checks from disappearing silently.
- Added persistent `opensagetv-vibe-ccache` alongside the existing Gradle
  cache and wired it into Linux/Windows FFmpeg/MIM compilation. A repeat Linux
  build reached 2478 cache hits from 2761 cacheable calls (89.75%).
- Added `runtime-update-package` and `runtime-update-test` to the unified
  Windows/Linux interface for Core, MIM, XMLTV, and Comskip appdata updates.
  All four component package/install/rollback self-tests pass.
- Added Buildx 0.36.1 to the unified image, changed runtime images to BuildKit,
  added runtime-environment fingerprint status/skip handling, and retained only
  the canonical production/debug images. The one reusable development
  container and two intentional cache volumes remain.
- Fixed `dev.cmd` environment forwarding through WSL so force flags, OpenDCT
  commissioning values, runtime soak controls, and image overrides reach the
  unified container exactly as they do on Linux.

- Bumped the unified image to `u26-j11-release-v6` and added Ubuntu's
  `smbclient`. Environment validation now requires it, enabling the Android MCP
  fixture workflow to publish deterministic caption/seek/Comskip media to an
  SMB2/SMB3 test share from the same reusable development container.
- Rebuilt and recreated the single reusable development environment on
  2026-08-30. Image ID
  `sha256:a3b97ab5e64e2e5fcff57384b0fde6436f01c0e15f9b99afa9fae5a5b42039a4`
  passed Java 11/17/8, Android SDK/NDK/platform-tools, bundletool, MCP,
  Docker-socket, and Samba 4.23.6 client validation.
- Rebuilt the unified development image with bundletool 1.18.3 and the complete
  Android/Core toolchain; current image ID is
  `sha256:365419322572efdb7b13dd89029f4dc1f27496dcc8267df21cf4fa9c1a2d1cb4`.
  The component Python syntax gate now excludes frozen/third-party/build output
  trees so retained Python 2 upstream helpers cannot be misclassified as
  current Python 3 workflow code.
- Added checksum-pinned Google bundletool 1.18.3 to the unified Android
  toolchain and made environment validation fail if it is absent or reports a
  different version. This supports reproducible AAB validation and APK-set
  installation gates without creating a separate Android build image.
- Completed a fresh `runtime-all` on 2026-08-29 after the clean Core rebuild.
  Exact artifact staging, Ubuntu 26 production/debug images, discovery, XMLTV,
  OpenDCT wire protocol, one supervised JVM recovery, three full container
  restarts, zero-zombie checks, SPDX SBOMs, image exports, and offline release
  assembly passed.
- Record both Docker Desktop's local image-store ID and the portable
  `docker save` archive config ID. Containerd-backed Docker Desktop can expose
  different values; the archive ID is the identity observed after loading on
  Unraid and is now used by image SBOM provenance.
- Added a workspace handoff creator and commissioner. One command creates
  verified changed-files packages for all seven repositories and a parent ZIP
  containing the updater plus Windows commissioning entrypoint.
- Added a host installer that accepts the outer workspace ZIP, extracts it to
  a temporary directory, verifies the expected seven packages, runs the full
  commissioner, and cleans only that temporary extraction.
- Added an isolated workflow self-test covering automatic and explicit ZIP
  application, manifest/baseline validation, all four gates, and completed
  state resume; added a seven-repository contract test for the common files,
  metadata, shell syntax, and root command interface.
- Added a synthetic seven-repository outer-bundle test that proves ZIP
  extraction and test/validate/build/install dispatch without touching real
  worktrees.
- Limited Git safe-directory setup inside the unified container to the six
  known mounted source repositories so Core builds work from Windows bind
  mounts without weakening Git ownership checks globally.
- Added the shared cross-repository takeover/update implementation and the
  standard root dev, update, handoff-package, documentation, metadata, task,
  and `artifacts/downloads` contract used by every supported component.
- Added `android-requirements.lock` for the exact transitive Python/MCP
  environment, pinned Android platform-tools to revision 37.0.1 with a
  post-install guard, and moved authoritative build-environment version
  metadata after the expensive SDK layer. Component/source-only edits continue
  to reuse the installed image and do not rebuild that layer.
- Completed Android download reproducibility with the component's Gradle
  distribution checksum, dependency lockfiles, and artifact checksum
  verification metadata. The unified `android-all` gate now passes 174 project
  tests, 35 MCP tests, validation, and all 60 clean Gradle tasks.
- Exported `/workspace/release-manifest` as
  `OPENSAGETV_VIBE_BUILD_ENV_ROOT` for direct unified Android commands so tests
  inspect the mounted unified wrappers instead of assuming a differently named
  sibling path.
- Added a normalized sibling-workspace identity to both host wrappers. The one
  named development container is now recreated when a command is launched from
  a different checkout instead of silently continuing with stale bind mounts;
  Windows and WSL representations of the same path normalize to one identity.
- Proved the rebind behavior with an independently committed Android/build-env
  sibling layout: its root test, validation, and clean 60-task build passed on
  the installed image, after which the one container was rebound to the real
  workspace and the temporary checkout was removed.
- Verified the complete post-integration Windows Docker Desktop `all` pipeline
  on 2026-08-28. Core, Linux/Windows FFmpeg/MIM, MIM media integrity, XMLTV,
  Android tests/validation/APK, production/debug images, runtime discovery and
  restart soak, exact manifests, checksums, SPDX SBOMs, and offline exports all
  passed in `opensagetv-vibe-dev`. The physical OpenDCT scan and Android-device
  commissioning remain explicit hardware gates.
- Integrated `opensagetv-vibe-android-client` into the one Ubuntu 26 unified
  image and reusable `opensagetv-vibe-dev` container. Java 11 remains the
  default; Android commands select digest-pinned JDK 17, and the frozen
  comparison build selects digest-pinned JDK 8 per process.
- Added checksum-verified Android command-line tools, SDK platforms/build tools
  29 and 36, NDK 21.0.6113669, ADB, and an isolated pinned Python/MCP virtual
  environment to the unified image.
- Added `android-info`, `android-test`, `android-validate`, `android-build`,
  `android-all`, and `android-mcp` to both host interfaces. Headless Android
  gates now run inside `all`; device installation and playback remain explicit.
- Added Android exact commit, version, APK hash/size, test status, documentation,
  and test log to resolved release provenance and the offline bundle.
- Extended both checkout helpers to reconstruct the Android sibling repository
  and detach it at the resolved manifest commit.

- Added an offline/pre-publication mode to both checkout helpers. They can make
  independent `--no-local` sibling clones from a local source root and detach
  the supported repositories at exact commits from a resolved release
  manifest, while preserving the existing GitHub branch workflow by default.
- Added the configurable runtime restart soak to `runtime-test`, `runtime-all`,
  and `all`, and forwarded its cycle, timeout, and metric-growth settings from
  both host wrappers. Unified reports now identify restart-soak validation
  explicitly. Release assembly requires its successful log, includes that log
  in the offline bundle, and records the exact cycle count in the manifest.
- Made the outer release-bundle checksum record a portable
  `packages/<bundle>` path instead of the development container's absolute
  workspace path, so validation works unchanged after transfer to another
  Windows, Linux, or Unraid host.
- Made release dirty-state detection compare staged/tracked content while
  normalizing only checkout CRLF differences. This prevents inherited
  `.gitattributes` and Windows bind mounts from falsely marking clean source
  commits dirty without hiding actual content, staging, deletion, or untracked
  changes.
- Integrated `opensagetv-vibe-container` into the same reusable development
  container and mounted the host Docker socket for runtime image construction,
  server startup, network tests, and image export.
- Extended `all` through exact-hash Core/MIM/XMLTV staging, production and
  debug image builds, clean-appdata SageTV health and startup, independent-peer
  UDP discovery, TCP 42024, XMLTV no-license selection, OpenDCT V3 protocol,
  and temporary-resource cleanup tests.
- Added `runtime-stage`, `runtime-images`, `runtime-test`, `release`, and
  `runtime-all` commands to both host wrappers.
- Added explicit forwarding for optional commissioned OpenDCT endpoint settings
  and supported release/image overrides.
- Replaced hand-maintained local manifest placeholders with generated exact
  component commits and dirty state, image IDs/platform/size, component
  versions, policy defaults, and per-artifact SHA-256/size records.
- Added versioned release assembly, compressed production/debug Docker exports,
  release and package checksum files, and three SPDX 2.3 SBOMs covering release
  artifacts and the installed packages in each runtime image.
- Added stage-aware failure reporting: any build, test, image, or packaging
  error now makes `all` write `BUILD FAILED` and return non-zero.
- Separated build-environment and container documentation inside the release
  bundle so same-named files cannot overwrite one another.
- Verified the complete Windows Docker Desktop pipeline on 2026-08-27. It
  returned `BUILD PASSED`; the physical OpenDCT scan was explicitly `SKIPPED`
  because no commissioned endpoint was provided, while its mock wire test
  passed.
- Folded the Linux and Windows FFmpeg cross-toolchains into private stages of
  the unified Dockerfile. Normal use now manages only
  `opensagetv-vibe-build-env:u26-j11` and `opensagetv-vibe-dev`; the standalone
  `opensagetv-vibe-ffmpeg-mim-builder` lifecycle is removed.
- Pinned FFmpeg `n9.0.1` to commit
  `bf1b838f2ab88b4f8fd83443325c782ea0e0f7fa` and pinned all three BtbN stage
  images by digest.
- Changed the `image` command to build the internal toolchain and final image
  together with BuildKit tag-plus-checksum source validation and added
  `ffmpeg-info` validation.
- Added targeted removal of the obsolete standalone builder tag after a
  successful unified image rebuild.
- Verified the consolidated image on 2026-08-27 with a clean `all` run. Core,
  Linux and Windows FFmpeg/MIM, MIM lifecycle/media integrity, and XMLTV all
  passed in the single reusable container. The compatibility launcher and
  `ffmpeg-info` validation also passed, and no standalone builder image or
  phase-specific container remained.
- Renamed the repository to `opensagetv-vibe-build-env` under the planned
  `opensagetv-vibe` GitHub organization.
- Renamed the unified image, reusable development container, Gradle cache,
  wrappers, bind-mounted sibling paths, and installed entrypoint to the
  `opensagetv-vibe-*` namespace.
- Added PowerShell and Bash Git-only checkout helpers for the complete six-repo
  organization, with an optional archive exclusion and dirty-worktree safety.
- Updated the release manifest to the full prefixed repository names and
  development branches.
- Expanded `test-mim` and `all` to run the real FFmpeg completed-recording,
  growing-file, join-in-progress, repeated-start, A/V integrity, full-decode,
  and orphan-process suite in addition to MIM unit/lifecycle tests.
- Persisted the non-Android MIM suite output under the FFmpeg project output and
  added the media-integrity gate to the unified build report.
- Verified the complete clean pipeline on 2026-08-26; it returned
  `BUILD PASSED` for Core, Linux/Windows FFmpeg/MIM, the MIM media suite, and
  XMLTV.
- Changed both host wrappers to reuse one named `opensagetv-vibe-dev` container for
  every Core, FFmpeg/MIM, XMLTV, test, and shell operation.
- Stopped rebuilding the development image during every `all` run. The image is
  now built automatically only when absent and explicitly with `image` after
  Dockerfile changes. An unreferenced superseded build image is removed after a
  successful explicit rebuild.
- Added `start`, `stop`, `remove-dev`, and unified output `clean` lifecycle
  commands. A changed image causes replacement of the same named container,
  never creation of a phase-specific container.
- Created the unified builder and release-manifest repository scaffold.
- Added the unified Ubuntu 26/OpenJDK 11 Core and Linux/Windows FFmpeg build image.
- Added Bash and PowerShell one-command interfaces and a pinned component manifest.
