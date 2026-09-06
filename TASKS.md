# OpenSageTV Vibe build-environment tasks

This is the only active backlog for this repository. Completed work is removed
and recorded in `CHANGELOG.md` and `HANDOFF.md`.

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
