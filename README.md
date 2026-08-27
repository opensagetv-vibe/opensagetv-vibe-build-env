# OpenSageTV Unified Build Environment

One Linux Docker development image and host wrappers for building Core,
FFmpeg/MIM, XMLTV, runtime images, Unraid templates, and local release bundles
from Windows Docker Desktop, Linux, or Unraid.

This is the single supported build interface for the separated release. It extends the Ubuntu 26.04 BtbN-derived cross-builder with OpenJDK 11 and all Core dependencies, so Core, Linux/Windows FFmpeg/MIM, tests, reports, and release staging run in one image/container.

The wrappers maintain exactly one named development container,
`opensagetv-dev`. Source repositories are bind-mounted, so a source edit does
not rebuild the image or create another container. The container is recreated
only after the build image itself changes. One named
`opensagetv-gradle-cache` volume is retained intentionally so downloaded Gradle
dependencies survive that recreation; it contains no SageTV appdata.

## Commands

Linux/WSL:

```bash
./opensagetv-dev.sh all
```

Windows Docker Desktop:

```powershell
.\opensagetv-dev.ps1 all
```

If local PowerShell policy blocks scripts, invoke the same file with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\opensagetv-dev.ps1 all
```

Both wrappers support:

| Command | Purpose |
|---|---|
| `start` | Create once if needed, then start `opensagetv-dev` |
| `all` | Build and test every component in the existing container |
| `core`, `ffmpeg-linux`, `ffmpeg-windows`, `test-mim`, `xmltv` | Run one build/test stage |
| `shell` | Open a shell in that same container |
| `clean` | Delete generated build outputs, not the container or caches |
| `stop` | Stop the reusable container |
| `remove-dev` | Remove only the reusable development container |
| `image` | Rebuild the image after Dockerfile/dependency changes |

`test-mim` runs both deterministic process/control regressions and real
FFmpeg media checks. The latter generate 29.97 and 59.94 fps MPEG-TS fixtures,
exercise completed and growing/join-in-progress inputs, repeat startup and
teardown, verify audio/video timing and packet counts, fully decode every
result, and reject orphan processes. Results are saved at
`opensagetv-ffmpeg-mim/output/test-results/non-android-suite.log`.

`all` builds the image automatically only when it is missing. Use `image`
explicitly after changing the Dockerfile; the next command recreates the one
named container against the new image. Normal source edits are visible
immediately through the bind mounts.

Low-power Unraid servers should load artifacts/images built on a faster amd64
Docker host. The development container contains no SageTV appdata and does not
replace the separately commissioned runtime container.
