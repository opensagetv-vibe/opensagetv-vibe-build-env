# Building with the unified container

The only supported multi-project build environment is
`opensagetv-vibe-build-env:u26-j11`, running as the reusable named container
`opensagetv-vibe-dev`.

The same Dockerfile builds its private `ffmpeg-toolchain` stage and the final
development image. Do not create or tag a separate FFmpeg/MIM builder image.

From Windows Docker Desktop:

```powershell
.\opensagetv-vibe-dev.ps1 image
.\opensagetv-vibe-dev.ps1 start
.\opensagetv-vibe-dev.ps1 all
```

From Linux or WSL:

```bash
./opensagetv-vibe-dev.sh image
./opensagetv-vibe-dev.sh start
./opensagetv-vibe-dev.sh all
```

Component commands reuse that same container. For example, rebuilding only the
XMLTV JAR is `./opensagetv-vibe-dev.sh xmltv` or
`.\opensagetv-vibe-dev.ps1 xmltv`. Use `shell` for interactive work and `stop` when
idle.

Do not rebuild the Docker image for source changes. All component sources are
bind-mounted. Run `image` only when the unified Dockerfile or installed build
dependencies change. `clean` removes outputs; `remove-dev` removes the named
development container. Neither command removes runtime appdata.

`ffmpeg-info` verifies both embedded target trees and reports the pinned FFmpeg
tag, commit, toolchain revision, and unified image version.
