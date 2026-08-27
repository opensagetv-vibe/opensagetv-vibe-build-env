# Changelog

## Unreleased

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
