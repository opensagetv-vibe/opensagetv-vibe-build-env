# Handoff

The unified image is `opensagetv-build-env:u26-j11`. It derives from the locally built BtbN-based Ubuntu 26 FFmpeg builder and adds the complete SageTV Core toolchain plus Java 11. `opensagetv-dev.sh all` is canonical. It owns orchestration and the compatibility manifest, not product source or appdata.

MIM's control test remains a release gate; `all` builds its experimental artifacts but never enables them in runtime. No release has been published.
