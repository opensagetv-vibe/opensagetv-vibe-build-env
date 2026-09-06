# syntax=docker/dockerfile:1.18

# The FFmpeg cross-toolchains are internal stages of this unified development
# image. They are deliberately not published or tagged as a separate SageTV
# builder image.
ARG BTBN_BASE_IMAGE=ghcr.io/btbn/ffmpeg-builds/base@sha256:1add1617fb7b9e661b34632b9bdc468e80c8b8ea517a6fa51d1a90634ea69112
ARG BTBN_LINUX_IMAGE=ghcr.io/btbn/ffmpeg-builds/linux64-gpl-9.0@sha256:69ce235cb2437154c54db6bee4b6b8c38290a19b6daca90b5ae769896f018761
ARG BTBN_WIN64_IMAGE=ghcr.io/btbn/ffmpeg-builds/win64-gpl-9.0@sha256:2171aae9e82c7543a05d9f5f7674ebab3815168e2afa430c0dc7d3a5f877299a
ARG ANDROID_JDK8_IMAGE=eclipse-temurin:8-jdk-jammy@sha256:7cb1137d4a02aeb7ca85faae69c5f0720703936cbfb0b4af21067c73174f9b5e
ARG ANDROID_JDK17_IMAGE=eclipse-temurin:17-jdk-jammy@sha256:400014962ad7224461f945bb1cc3d7d5a1927ce15b8245b72d9cedcda554cd2a

FROM ${ANDROID_JDK8_IMAGE} AS android-jdk8
FROM ${ANDROID_JDK17_IMAGE} AS android-jdk17

FROM ${BTBN_LINUX_IMAGE} AS btbn-linux
USER root
RUN bash -lc '\
  vars="FFBUILD_TOOLCHAIN FFBUILD_RUST_TARGET FFBUILD_TARGET_FLAGS FFBUILD_CROSS_PREFIX FFBUILD_PREFIX FFBUILD_DESTDIR FFBUILD_DESTPREFIX FFBUILD_CMAKE_TOOLCHAIN PKG_CONFIG PKG_CONFIG_LIBDIR CC CXX LD AR RANLIB NM DLLTOOL GENDEF CFLAGS CXXFLAGS LDFLAGS STAGE_CFLAGS STAGE_CXXFLAGS FF_CONFIGURE FF_CFLAGS FF_CXXFLAGS FF_LIBS FF_LDFLAGS FF_LDEXEFLAGS"; \
  : > /sagetv-env.sh; \
  for v in $vars; do if [[ -v "$v" ]]; then printf "export %s=%q\\n" "$v" "${!v}" >> /sagetv-env.sh; fi; done'

FROM ${BTBN_WIN64_IMAGE} AS btbn-win64
USER root
RUN bash -lc '\
  vars="FFBUILD_TOOLCHAIN FFBUILD_RUST_TARGET FFBUILD_TARGET_FLAGS FFBUILD_CROSS_PREFIX FFBUILD_PREFIX FFBUILD_DESTDIR FFBUILD_DESTPREFIX FFBUILD_CMAKE_TOOLCHAIN PKG_CONFIG PKG_CONFIG_LIBDIR CC CXX LD AR RANLIB NM DLLTOOL GENDEF CFLAGS CXXFLAGS LDFLAGS STAGE_CFLAGS STAGE_CXXFLAGS FF_CONFIGURE FF_CFLAGS FF_CXXFLAGS FF_LIBS FF_LDFLAGS FF_LDEXEFLAGS"; \
  : > /sagetv-env.sh; \
  for v in $vars; do if [[ -v "$v" ]]; then printf "export %s=%q\\n" "$v" "${!v}" >> /sagetv-env.sh; fi; done'

FROM ${BTBN_BASE_IMAGE} AS ffmpeg-toolchain
USER root
ARG FFMPEG_TAG=n9.0.1
ARG FFMPEG_COMMIT=bf1b838f2ab88b4f8fd83443325c782ea0e0f7fa
ARG TOOLCHAIN_VERSION=ffmpeg9-v5

RUN mkdir -p \
    /opt/sagetv/targets/linux64 \
    /opt/sagetv/targets/win64 \
    /opt/sagetv/src/ffmpeg

COPY --from=btbn-linux /opt/ct-ng /opt/sagetv/targets/linux64/ct-ng
COPY --from=btbn-linux /opt/ffbuild /opt/sagetv/targets/linux64/ffbuild
COPY --from=btbn-linux /sagetv-env.sh /opt/sagetv/targets/linux64/env.sh
COPY --from=btbn-win64 /opt/ct-ng /opt/sagetv/targets/win64/ct-ng
COPY --from=btbn-win64 /opt/ffbuild /opt/sagetv/targets/win64/ffbuild
COPY --from=btbn-win64 /sagetv-env.sh /opt/sagetv/targets/win64/env.sh

# The host wrapper supplies this named context with a tag plus checksum query,
# so BuildKit rejects the build if the tag does not peel to the commit above.
# BuildKit excludes Git metadata; component builds copy and patch this pristine
# source snapshot without downloading during compilation.
COPY --from=ffmpeg_src / /opt/sagetv/src/ffmpeg/

ENV OPENSAGETV_VIBE_FFMPEG_TOOLCHAIN=${TOOLCHAIN_VERSION} \
    SAGETV_FFMPEG_TAG=${FFMPEG_TAG} \
    SAGETV_FFMPEG_COMMIT=${FFMPEG_COMMIT}

FROM ffmpeg-toolchain AS development
USER root
LABEL org.opencontainers.image.title="OpenSageTV Vibe Unified Build Environment" \
      org.opencontainers.image.description="One development image for OpenSageTV Vibe Core, container, FFmpeg/MIM, XMLTV, logo, Android, tests, and release staging" \
      org.opencontainers.image.source="https://github.com/opensagetv-vibe/opensagetv-vibe-build-env" \
      org.opencontainers.image.version="u26-j11-release-v8"
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    JDK_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    GRADLE_USER_HOME=/work/.gradle \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_HOME=/opt/android-sdk \
    OPENSAGETV_VIBE_ANDROID_JAVA_HOME=/opt/java/jdk17 \
    OPENSAGETV_VIBE_ANDROID_LEGACY_JAVA_HOME=/opt/java/jdk8 \
    OPENSAGETV_VIBE_ANDROID_PYTHON=/opt/opensagetv-vibe/android-python/bin/python3 \
    OPENSAGETV_VIBE_LOGO_PYTHON=/opt/opensagetv-vibe/logo-python/bin/python3 \
    OPENSAGETV_VIBE_BUILD_ENV_VERSION=u26-j11-release-v8
ARG ANDROID_SDK_TOOLS_URL=https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip
ARG ANDROID_SDK_TOOLS_SHA256=4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583
ARG ANDROID_PLATFORM_TOOLS_VERSION=37.0.1
RUN rm -f /etc/apt/sources.list.d/nodesource.list /etc/apt/sources.list.d/nodesource.sources \
 && apt-get -o Acquire::Retries=5 update \
 && apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
    autoconf automake binutils build-essential ca-certificates curl docker.io dvdauthor ffmpeg file fontconfig fonts-dejavu-core g++ gcc gdb git gzip imagemagick openssh-client \
    iproute2 iputils-ping jq libc6-i386 lib32gcc-s1 lib32stdc++6 lib32z1 \
    libasound2-dev libaudio-dev libavc1394-dev libfreetype6-dev libgif-dev libiec61883-dev \
    libcairo2 libffi-dev libjpeg-dev libjpeg-turbo-progs libnsl-dev libpng-dev libpulse-dev libraw1394-dev libtiff-dev libtool \
    libx11-dev libxt-dev lsof make openjdk-11-jdk patchelf pkg-config procps python3 smbclient \
    python3-pil python3-pip python3-venv strace unzip wget xz-utils yasm zip zlib1g-dev zstd \
 && grep -q '^VERSION_ID="26.04"$' /etc/os-release \
 && java -version \
 && docker --version \
 && rm -rf /var/lib/apt/lists/*

# Java 11 remains the image default for SageTV Core. Android commands opt into
# these digest-pinned JDKs per process: 17 for Dev and 8 for the frozen baseline.
COPY --from=android-jdk8 /opt/java/openjdk /opt/java/jdk8
COPY --from=android-jdk17 /opt/java/openjdk /opt/java/jdk17

COPY android-requirements.lock /opt/opensagetv-vibe/android-requirements.lock
RUN python3 -m venv /opt/opensagetv-vibe/android-python \
 && /opt/opensagetv-vibe/android-python/bin/python3 -m pip install --no-cache-dir --upgrade \
      'pip==26.2.1' 'setuptools==84.0.0' 'wheel==0.48.0' \
 && /opt/opensagetv-vibe/android-python/bin/python3 -m pip install --no-cache-dir \
      -r /opt/opensagetv-vibe/android-requirements.lock

# Logo inputs remain bind-mounted and editable. The unified image owns their
# exact renderer/runtime dependencies so neither host Python nor host fonts are
# required. M PLUS Rounded 1c is project-local and loaded through Fontconfig.
COPY --from=logo_src requirements.lock /opt/opensagetv-vibe/logo-requirements.lock
RUN python3 -m venv /opt/opensagetv-vibe/logo-python \
 && /opt/opensagetv-vibe/logo-python/bin/python3 -m pip install --no-cache-dir --upgrade \
      'pip==26.2.1' 'setuptools==84.0.0' 'wheel==0.48.0' \
 && /opt/opensagetv-vibe/logo-python/bin/python3 -m pip install --no-cache-dir \
      -r /opt/opensagetv-vibe/logo-requirements.lock \
 && /opt/opensagetv-vibe/logo-python/bin/python3 -c \
      'import cairosvg, PIL; print("logo_renderer=PASS")'

# Verify the official archive before installation. SDK 29/JDK 8 is retained
# solely for the frozen comparison build; SDK 36/JDK 17 is the active client.
RUN mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools" \
 && curl -fsSL "${ANDROID_SDK_TOOLS_URL}" -o /tmp/android-command-line-tools.zip \
 && echo "${ANDROID_SDK_TOOLS_SHA256}  /tmp/android-command-line-tools.zip" | sha256sum -c - \
 && unzip -q /tmp/android-command-line-tools.zip -d /tmp/android-command-line-tools \
 && mv /tmp/android-command-line-tools/cmdline-tools "${ANDROID_SDK_ROOT}/cmdline-tools/latest" \
 && rm -rf /tmp/android-command-line-tools /tmp/android-command-line-tools.zip \
 && yes | env JAVA_HOME=/opt/java/jdk17 \
      "${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null
RUN env JAVA_HOME=/opt/java/jdk17 \
    "${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager" \
      "platform-tools" \
      "platforms;android-29" \
      "build-tools;29.0.2" \
      "platforms;android-36" \
      "build-tools;36.0.0" \
      "ndk;21.0.6113669" \
 && grep -Fxq "Pkg.Revision=${ANDROID_PLATFORM_TOOLS_VERSION}" \
      "${ANDROID_SDK_ROOT}/platform-tools/source.properties"

# Bundletool is required to validate Android App Bundles and produce the APK
# sets used by local installation gates. Keep it after the large SDK layers so
# a tool-only update does not invalidate those downloads.
ARG BUNDLETOOL_VERSION=1.18.3
ARG BUNDLETOOL_SHA256=a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29
ENV BUNDLETOOL_JAR=/opt/android-tools/bundletool-all-1.18.3.jar
RUN mkdir -p /opt/android-tools \
 && curl -fsSL \
      "https://github.com/google/bundletool/releases/download/${BUNDLETOOL_VERSION}/bundletool-all-${BUNDLETOOL_VERSION}.jar" \
      -o "${BUNDLETOOL_JAR}" \
 && echo "${BUNDLETOOL_SHA256}  ${BUNDLETOOL_JAR}" | sha256sum -c - \
 && /opt/java/jdk17/bin/java -jar "${BUNDLETOOL_JAR}" version \
      | grep -Fxq "${BUNDLETOOL_VERSION}"

# Compiler outputs persist in a named volume. This layer intentionally follows
# the large Android/toolchain layers so adding or updating ccache does not force
# their downloads to run again.
RUN apt-get -o Acquire::Retries=5 update \
 && apt-get -o Acquire::Retries=5 install -y --no-install-recommends ccache \
 && rm -rf /var/lib/apt/lists/*

# Runtime-image builds use BuildKit so reusable intermediate layers stay in
# the builder cache instead of appearing as hundreds of <none> images.
ARG DOCKER_BUILDX_VERSION=0.36.1
ARG DOCKER_BUILDX_LINUX_AMD64_SHA256=48af8a397ebd60178778bf63611dbcebe5f5e7a9be90eb9147b24b9587455778
RUN mkdir -p /usr/local/libexec/docker/cli-plugins \
 && curl -fsSL \
      "https://github.com/docker/buildx/releases/download/v${DOCKER_BUILDX_VERSION}/buildx-v${DOCKER_BUILDX_VERSION}.linux-amd64" \
      -o /usr/local/libexec/docker/cli-plugins/docker-buildx \
 && echo "${DOCKER_BUILDX_LINUX_AMD64_SHA256}  /usr/local/libexec/docker/cli-plugins/docker-buildx" | sha256sum -c - \
 && chmod 0755 /usr/local/libexec/docker/cli-plugins/docker-buildx \
 && docker buildx version

ENV CCACHE_DIR=/work/.ccache \
    CCACHE_MAXSIZE=20G \
    PATH=/opt/android-sdk/platform-tools:/opt/android-sdk/build-tools/36.0.0:/opt/android-sdk/cmdline-tools/latest/bin:${PATH}
# Keep authoritative release metadata after expensive dependency layers so a
# metadata-only release bump reuses the Android SDK and Python caches.
ARG BUILD_ENV_VERSION=u26-j11-release-v8
ENV OPENSAGETV_VIBE_BUILD_ENV_VERSION=${BUILD_ENV_VERSION}
LABEL org.opencontainers.image.version=${BUILD_ENV_VERSION}
COPY scripts/dev-entrypoint.sh /usr/local/bin/opensagetv-vibe-dev
RUN chmod 0755 /usr/local/bin/opensagetv-vibe-dev
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/opensagetv-vibe-dev"]
CMD ["help"]
