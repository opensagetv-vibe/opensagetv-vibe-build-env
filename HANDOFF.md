# OpenSageTV Vibe build-environment handoff

The unified image is `opensagetv-vibe-build-env:u26-j11`. Its Dockerfile owns
the internal BtbN Linux/Windows FFmpeg toolchain stages and adds the complete
SageTV Core toolchain plus Java 11. No separately tagged SageTV FFmpeg builder
image is part of the supported workflow. `opensagetv-vibe-dev.sh all` is
canonical. This repository owns build-environment orchestration and the
compatibility manifest, not product source or appdata.

Both host wrappers reuse the single `opensagetv-vibe-dev` container. Do not add
phase-specific `docker run --name` calls. Source is bind-mounted, so compile and
test by `docker exec` in this container. Rebuild with `image` only after build
dependencies change; the wrapper detects the image ID and replaces the same
container. `opensagetv-vibe-gradle-cache` is the one intentional project build-cache
volume. Temporary runtime tests must use `--rm` or explicit `docker rm -v`
because the production image declares five data volumes.

The image wrapper resolves FFmpeg `n9.0.1` to pinned commit
`bf1b838f2ab88b4f8fd83443325c782ea0e0f7fa` and supplies it to BuildKit as a
tag-plus-checksum named context. BtbN stage images are pinned by digest. After a successful
explicit image rebuild the wrapper removes the obsolete standalone builder tag
if it exists.

MIM 0.4.5's complete non-Android gate now runs from both `test-mim` and `all`:
init/rollback, option/control forwarding, teardown/crash containment, and real
completed/growing/join/repeated media integrity. The consolidated image was
rebuilt on 2026-08-27 and its clean `all` run returned `BUILD PASSED` for Core,
Linux and Windows FFmpeg/MIM, MIM tests, and XMLTV. `ffmpeg-info`, static
validation, and the FFmpeg compatibility launcher passed; Docker retained only
the public unified build image and one reusable development container. Android
MiniClient commissioning and physical AMD/NVIDIA testing remain release gates,
so `all` builds the experimental artifacts but never enables MIM in runtime. No
release has been published.
