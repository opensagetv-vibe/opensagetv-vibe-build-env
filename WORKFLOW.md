# Common project workflow

## Task fix and server-boundary policy

Apply this policy to every task workflow, including dependency fixes across
Vibe repositories. Fix and test necessary plugins and update the test-server
plugin without asking again solely for repository-boundary approval.

Prefer the Android client, then a stock-compatible plugin. Change non-stock
`.232` Core only for a proven production defect that neither can correct;
document the API gap and alternatives, keep optional negotiation and safe
stock/older-client fallback, and run affected compatibility tests. Never patch
Core merely to simplify testing.

Stock `.175` installation changes are limited to plugin installation/update.
Do not modify its stock Sage.jar, stock FFmpeg, Core binaries, or server
installation/configuration files. Preserve user settings, recordings and
unrelated clients; reversible supported SageTV playback APIs remain allowed.

Non-stock `.232` restarts are authorized for task updates without asking
again; coordinate them with active test guards and preserve data/settings.
  Always ask the user before restarting stock `.175`, even when it appears idle,
  unless an explicit user-granted bounded restart window is active. Record
  its UTC expiry in the task/handoff, and check expiry and revocation before
  every restart. After expiry or revocation, ask again; stock files stay protected.

Update owning TASKS.md, linked dependencies and the workspace suggested order
as work changes; move completed checkoffs into the checklist change ledger.
Test only affected gates, preserve unrelated completed matrices, and do not
stop independent authorized work for a status question or a dependency-only
permission request. Unrelated work, publication, destructive actions and
interruption of recordings/other users still require their own authority.

Every supported OpenSageTV Vibe repository exposes the same root interface:

```text
dev.cmd test|validate|build|install|all
./dev.sh test|validate|build|install|all
update.cmd
./update.sh
create_ai_handoff_zip.cmd
```

Paths are resolved from the launcher location, not the caller's working
directory. Component commands delegate to this repository's installed unified
image/container. `install` is component-specific and reports `SKIPPED` when a
repository produces only an artifact.

The build-environment root also exposes extended unified commands such as
`android-all`, `runtime-image-status`, `runtime-images`,
`runtime-update-package`, and `runtime-update-test`. These still reuse the one
`opensagetv-vibe-dev` container. Application-component updates are installed
in appdata and do not rebuild the runtime image; an image rebuild is reserved
for Ubuntu/Java/driver/system-library or container-infrastructure changes.
Both Windows and Linux wrappers forward only the documented commissioning and
runtime-control variables.

Update ZIPs are downloaded to `artifacts/downloads`. They must be named
`<PACKAGE_ID>-v<version>-changed-files-only.zip` (with `PACKAGE_ID` from
`release.properties`), contain `release.properties`,
the complete `PROJECT_MANIFEST.sha256`, changed files, and
`release-deletions.lst`. The update runner rejects corrupt, duplicate, unsafe,
or hash-mismatched packages before extraction, then resumes test, validation,
build, and install using state under `artifacts/update_runner`.

`create_ai_handoff_zip.cmd` builds the matching changed-files package with the
current documentation and workflow files. Never place credentials, appdata,
recordings, private signing keys, or generated build output in a handoff ZIP.

From this repository, `create_workspace_handoff_zip.cmd` creates all twelve
component packages plus one workspace bundle. Its included
`APPLY_WORKSPACE_HANDOFF.cmd` verifies and applies each package, then runs the
same resumable test/validate/build/install gates in dependency order.
`install_workspace_handoff_zip.cmd [ZIP] [PROJECTS_ROOT]` also extracts the
outer bundle and removes only its temporary extraction directory afterward.

When a task is completed, remove it from that repository's `TASKS.md`, record
the verified result in `CHANGELOG.md` and current takeover state in
`HANDOFF.md`, and mirror the active workspace dependency in root `task.md`.
Do not create version-specific Markdown or text status files.

## GitHub pull, push, and release gate

Every Vibe repository update is governed by `config/github-projects.toml` and
the fail-closed shared gate:

```text
github_change_gate.cmd audit
./github_change_gate.sh audit
```

The audit checks repository identity, default branch, clean state, origin
ancestry, outgoing author/committer identity, diff integrity, and the required
repository workflow before any push. For a multi-repository update, push only
the configured pilot (`opensagetv-vibe-build-env`), then require:

```text
github_change_gate.cmd verify-head --project opensagetv-vibe-build-env
```

Only after that passes may the next repository be pushed. Run `verify-head`
after each push and stop on the first failure. Use `verify-pr` with every
required target check before opening another PR, and `verify-release` after
publication to ensure the release tag identifies current `HEAD` and all public
assets have GitHub digests. Never publish all repositories concurrently before
the pilot succeeds.
