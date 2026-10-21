# OpenSageTV Vibe build-environment tasks

> **Pre-commit task maintenance:** Immediately before every repository commit, move
> completed `[x]` items out of active sections and into
> `## Checklist change ledger`. Preserve IDs, evidence, and context; never
> discard completion history. Active sections contain unchecked work only.

This is the only active backlog for this repository. Completed work moves to
the checklist change ledger; release evidence is also recorded in
`CHANGELOG.md` and `HANDOFF.md`.



- [ ] TOP PRIORITY: add a reproducible current-Ubuntu stock-Core build/runtime
  lane beside the existing Vibe lane. It must build canonical SageTV with the
  proposed GCC/64-bit, ImageLoader/native-library, launcher, and source-clean
  patches; run the affected server/container gates; and preserve exact evidence
  that can be attached to the separate `google/sagetv` pull requests. The Vibe
  Ubuntu 26 lane must continue to pass from the same unified environment.

- [ ] Complete the first `web-client-all` gate with the new late-layer Servlet
  and Playwright/Chromium dependencies, then record its exact image identity.

- [ ] Rerun the complete whole-project `all` release pipeline on the final
  published component revisions.
- [ ] Make standalone `release` reject component outputs whose embedded source
  revision differs from the current repository revision.
- [ ] Normalize staged release text so host CRLF checkout policy cannot change
  otherwise identical release hashes.
- [ ] Batch semantic dirty-state detection so Core verification on a Windows
  bind mount does not require the current slow per-file fallback.
- [ ] Remove or normalize unconfigured legacy x264/FFmpeg `distclean` calls so
  ignored legacy clean errors do not pollute clean-build logs.

## Checklist change ledger

- [x] **SAGEMC-PLUGIN-001 dependency (2026-10-21):** Canonical SageMC-Plugin
  registry/checkout/handoff/source mounts and bounded development-install
  dispatch. Shared workflow, Bash/Python/PowerShell syntax and twelve-project
  handoff selftest pass. Reusable container mount verified; native layout guard
  prevents stale binds. Keys/caches/runtime destinations preserved. Source-only
  pilot CI required before dependent pushes; no image or Core rebuild.

- [x] **PLUGIN-RENAME-001 (2026-10-21):** Four canonical plugin roots now
  drive checkout, dispatch, GitHub registry, handoff and mount migration.
  Workflow contracts, Bash/Python/PowerShell syntax and twelve-project handoff
  selftest pass. Idle unified dev container recreated; four mounts readable,
  named caches/persistent Android identity preserved. No server/runtime rebuild.
  Workspace Android order389 reviewed unchanged; pilot CI required before
  downstream pushes (publication verification remains workspace-owned).

- [x] **XMLTV-PLUGIN-002 dependency (2026-10-18).** Rename active XMLTV
  checkout/registry/handoff/source URLs to opensagetv-vibe-xmltv-Plugin;
  preserve internal mount path and guard its source identity in both wrappers.
  New package dispatch and stock-JAR compile validation; no runtime image
  rebuild or ADB identity reset. Common contracts and independent twelve-
  repository handoff/install self-test pass. XMLTV's own task ledger owns
  lifecycle/packaging/server qualification; no catalog publication implied.

- [x] 2026-10-16 release onboarding: register Client Extension source in the
  shared GitHub gate with a contract preserving the unpublished archive.
  Source publication does not qualify unfinished companion DVD release gates.
  `dev.cmd test` passes shell/Python/workflow contracts and the independent
  twelve-component workspace handoff/install self-test; no runtime/image change.

- 2026-10-08 pre-commit review: synchronize the stock/plugin-first task-fix
  policy and existing companion build dispatch. Root order reviewed at Android
  revision305; unfinished build/runtime tasks remain unchecked. Script/sibling
  workflow contracts pass; no image rebuild or hardware qualification claimed.
