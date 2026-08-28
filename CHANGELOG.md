# Changelog

## Unreleased

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
