# Handoff

The unified image is `opensagetv-build-env:u26-j11`. It derives from the locally built BtbN-based Ubuntu 26 FFmpeg builder and adds the complete SageTV Core toolchain plus Java 11. `opensagetv-dev.sh all` is canonical. It owns orchestration and the compatibility manifest, not product source or appdata.

Both host wrappers reuse the single `opensagetv-dev` container. Do not add
phase-specific `docker run --name` calls. Source is bind-mounted, so compile and
test by `docker exec` in this container. Rebuild with `image` only after build
dependencies change; the wrapper detects the image ID and replaces the same
container. `opensagetv-gradle-cache` is the one intentional project build-cache
volume. Temporary runtime tests must use `--rm` or explicit `docker rm -v`
because the production image declares five data volumes.

MIM 0.4.5's complete non-Android gate now runs from both `test-mim` and `all`:
init/rollback, option/control forwarding, teardown/crash containment, and real
completed/growing/join/repeated media integrity. The 2026-08-26 clean `all` run
returned `BUILD PASSED`. Android MiniClient commissioning and physical
AMD/NVIDIA testing remain release gates, so `all` builds the experimental
artifacts but never enables MIM in runtime. No release has been published.
