# Third-party notices

The original scripts and documentation in this repository are licensed under
the top-level `LICENSE`. The development image installs or consumes independent
third-party components under their own licenses, including Ubuntu packages,
OpenJDK/Temurin, Android SDK/NDK and platform tools, FFmpeg, BTBN FFmpeg build
images, crosstool-NG, Gradle, bundletool, Python packages from
`android-requirements.lock`, CairoSVG, Pillow, Docker/Buildx, dvdauthor,
ImageMagick, Fontconfig, and DejaVu fonts.

Pinned versions, image digests, download hashes, and source revisions are
authoritative in `Dockerfile`, `android-requirements.lock`, and
`release-manifest.yml`. Those components are not relicensed by this repository.
Review their upstream license files and the component repositories' notices
before redistributing generated binaries or image exports. Final release
assembly also generates SPDX 2.3 SBOMs for the exact files and installed
runtime packages.
