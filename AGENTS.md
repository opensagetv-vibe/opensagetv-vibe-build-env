# OpenSageTV Vibe build-environment contributor rules

Read `README.md`, `HANDOFF.md`, `TASKS.md`, and `WORKFLOW.md` before changing
the repository. These instructions apply to humans and every AI assistant.

- `TASKS.md` is the only local backlog. Remove completed entries immediately
  and record evidence in `CHANGELOG.md` and current state in `HANDOFF.md`.
- Do not create prompt, review, session, or per-version Markdown/text files.
- Version history belongs only in `CHANGELOG.md`; machine metadata belongs in
  `release.properties`.
- Use the one `opensagetv-vibe-build-env:u26-j11` image and one
  `opensagetv-vibe-dev` container. Do not create phase/component containers.
- Root launchers must resolve from their own location and work from any CWD.
- Generate update/handoff packages only with `create_ai_handoff_zip.cmd`.
- Never claim device, tuner, GPU, Unraid, or network hardware validation from
  host-only tests.
