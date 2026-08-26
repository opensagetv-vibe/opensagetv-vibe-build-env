# Building with the unified container

The only supported multi-project build environment is
`opensagetv-build-env:u26-j11`, running as the reusable named container
`opensagetv-dev`.

From Windows Docker Desktop:

```powershell
.\opensagetv-dev.ps1 start
.\opensagetv-dev.ps1 all
```

From Linux or WSL:

```bash
./opensagetv-dev.sh start
./opensagetv-dev.sh all
```

Component commands reuse that same container. For example, rebuilding only the
XMLTV JAR is `./opensagetv-dev.sh xmltv` or
`.\opensagetv-dev.ps1 xmltv`. Use `shell` for interactive work and `stop` when
idle.

Do not rebuild the Docker image for source changes. All component sources are
bind-mounted. Run `image` only when the unified Dockerfile or installed build
dependencies change. `clean` removes outputs; `remove-dev` removes the named
development container. Neither command removes runtime appdata.
