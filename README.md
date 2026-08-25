# OpenSageTV Unified Build Environment

One Linux Docker development image and host wrappers for building Core,
FFmpeg/MIM, XMLTV, runtime images, Unraid templates, and local release bundles
from Windows Docker Desktop, Linux, or Unraid.

This is the single supported build interface for the separated release. It extends the Ubuntu 26.04 BtbN-derived cross-builder with OpenJDK 11 and all Core dependencies, so Core, Linux/Windows FFmpeg/MIM, tests, reports, and release staging run in one image/container.

Run `./opensagetv-dev.sh all` on Linux/WSL or `./opensagetv-dev.ps1 all` on Windows Docker Desktop. Low-power Unraid servers should load artifacts/images built on a faster amd64 Docker host.
