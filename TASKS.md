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
