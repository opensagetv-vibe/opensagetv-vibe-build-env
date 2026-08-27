# OpenSageTV Vibe Build Environment

One Linux Docker development image and host wrappers for building Core,
FFmpeg/MIM, XMLTV, runtime images, Unraid templates, and local release bundles
from Windows Docker Desktop, Linux, or Unraid.

This is the single supported build interface for the separated release. Its
Dockerfile owns internal `ffmpeg-toolchain`, Linux-target, and Windows-target
stages, then adds OpenJDK 11 and all Core dependencies. Only the final
`opensagetv-vibe-build-env:u26-j11` image is loaded and managed; there is no
separate SageTV FFmpeg builder image or build container.

The wrappers maintain exactly one named development container,
`opensagetv-vibe-dev`. Source repositories are bind-mounted, so a source edit does
not rebuild the image or create another container. The container is recreated
only after the build image itself changes. One named
`opensagetv-vibe-gradle-cache` volume is retained intentionally so downloaded Gradle
dependencies survive that recreation; it contains no SageTV appdata.

## Commands

Linux/WSL:

```bash
./opensagetv-vibe-dev.sh all
```

Windows Docker Desktop:

```powershell
.\opensagetv-vibe-dev.ps1 all
```

If local PowerShell policy blocks scripts, invoke the same file with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\opensagetv-vibe-dev.ps1 all
```

Both wrappers support:

| Command | Purpose |
|---|---|
| `start` | Create once if needed, then start `opensagetv-vibe-dev` |
| `all` | Build and test every component in the existing container |
| `core`, `ffmpeg-linux`, `ffmpeg-windows`, `test-mim`, `xmltv` | Run one build/test stage |
| `shell` | Open a shell in that same container |
| `clean` | Delete generated build outputs, not the container or caches |
| `stop` | Stop the reusable container |
| `remove-dev` | Remove only the reusable development container |
| `image` | Build the internal FFmpeg toolchains and final unified image |
| `ffmpeg-info` | Verify and report the two internal target toolchains |

`test-mim` runs both deterministic process/control regressions and real
FFmpeg media checks. The latter generate 29.97 and 59.94 fps MPEG-TS fixtures,
exercise completed and growing/join-in-progress inputs, repeat startup and
teardown, verify audio/video timing and packet counts, fully decode every
result, and reject orphan processes. Results are saved at
`opensagetv-vibe-ffmpeg-mim/output/test-results/non-android-suite.log`.

## Check out the complete organization

GitHub organizations are collections of repositories, so Git cannot clone the
entire organization with one native command. Clone this build-environment
repository into an empty parent directory, then run the supplied Git-only
checkout helper:

```powershell
mkdir opensagetv-vibe
cd opensagetv-vibe
git clone https://github.com/opensagetv-vibe/opensagetv-vibe-build-env.git
.\opensagetv-vibe-build-env\checkout-all.ps1
```

```bash
mkdir opensagetv-vibe && cd opensagetv-vibe
git clone https://github.com/opensagetv-vibe/opensagetv-vibe-build-env.git
./opensagetv-vibe-build-env/checkout-all.sh
```

Both helpers refuse to update a dirty repository. Pass `-SkipArchive` on
Windows or `--skip-archive` on Linux for a build-only checkout without the
large historical archive.

`all` builds the image automatically only when it is missing. Use `image`
explicitly after changing the Dockerfile; the next command recreates the one
named container against the new image. Normal source edits are visible
immediately through the bind mounts.

The `image` command uses BuildKit stages inside this repository. FFmpeg source
is fetched at pinned commit
`bf1b838f2ab88b4f8fd83443325c782ea0e0f7fa` (`n9.0.1`) using BuildKit's
tag-plus-checksum context validation, and the BtbN base/Linux/Windows images are pinned by digest in the
Dockerfile. A local source context can be supplied with
`OPENSAGETV_VIBE_FFMPEG_SOURCE_CONTEXT` for an offline rebuild.

Low-power Unraid servers should load artifacts/images built on a faster amd64
Docker host. The development container contains no SageTV appdata and does not
replace the separately commissioned runtime container.
