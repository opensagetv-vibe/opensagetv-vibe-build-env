# Contributing to the OpenSageTV Vibe build environment

This repository owns the one Ubuntu 26.04 development image and the one
reusable `opensagetv-vibe-dev` container used by every component. Do not add
component-specific development containers or host build prerequisites.

Run `dev.cmd test` on Windows or `./dev.sh test` on Linux before review. A final
release candidate must run `opensagetv-vibe-dev.ps1 all` or
`./opensagetv-vibe-dev.sh all` with clean sibling checkouts. Record results in
`CHANGELOG.md` and `HANDOFF.md`, remove completed tasks from `TASKS.md`, and do
not create version-specific status files.

Docker images produced by the workflow are local/test artifacts. Publish only
the source repository and checksummed commissioning/export files; do not push
images to a registry unless a future reviewed policy explicitly changes this.

Before any GitHub push, PR, tag, or release, run the applicable
`github_change_gate.cmd` / `github_change_gate.sh` command documented in
`WORKFLOW.md`. Multi-repository changes must use one pilot, wait for its
required workflow to pass, and then update and verify repositories one at a
time. A failed identity, target, workflow, PR check, tag, or asset gate stops
the batch.
