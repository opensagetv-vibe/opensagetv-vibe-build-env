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


## Stock-server test-control policy

- For any new testing, commissioning, diagnostic, or automation control, first
  implement or extend the stock-compatible `opensagetv-vibe-core-MCP-Plugin`
  using supported `sage.SageTV.api`/`apiUI` calls and verify it against an
  unmodified stock SageTV server.
- Do not patch `Sage.jar`, add private MiniClient events, or change Core merely
  to make a test easier. Existing public APIs, the bounded MCP bridge, and
  external test tooling are the required first option.
- Change Core only when the required production runtime behavior cannot be
  expressed through the stock plugin/API boundary. Document the proven API
  gap, keep the extension optional and negotiated with a safe stock fallback,
  and verify older clients and installations remain unaffected.
