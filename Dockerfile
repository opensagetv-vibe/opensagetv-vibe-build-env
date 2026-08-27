# syntax=docker/dockerfile:1.18

# The FFmpeg cross-toolchains are internal stages of this unified development
# image. They are deliberately not published or tagged as a separate SageTV
# builder image.
ARG BTBN_BASE_IMAGE=ghcr.io/btbn/ffmpeg-builds/base@sha256:1add1617fb7b9e661b34632b9bdc468e80c8b8ea517a6fa51d1a90634ea69112
ARG BTBN_LINUX_IMAGE=ghcr.io/btbn/ffmpeg-builds/linux64-gpl-9.0@sha256:69ce235cb2437154c54db6bee4b6b8c38290a19b6daca90b5ae769896f018761
ARG BTBN_WIN64_IMAGE=ghcr.io/btbn/ffmpeg-builds/win64-gpl-9.0@sha256:2171aae9e82c7543a05d9f5f7674ebab3815168e2afa430c0dc7d3a5f877299a

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
      org.opencontainers.image.description="One development image for OpenSageTV Vibe Core, FFmpeg/MIM, XMLTV, tests, and release staging" \
      org.opencontainers.image.source="https://github.com/opensagetv-vibe/opensagetv-vibe-build-env" \
      org.opencontainers.image.version="u26-j11-toolchain-v1"
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    JDK_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    GRADLE_USER_HOME=/work/.gradle \
    OPENSAGETV_VIBE_BUILD_ENV_VERSION=u26-j11-toolchain-v1
RUN rm -f /etc/apt/sources.list.d/nodesource.list /etc/apt/sources.list.d/nodesource.sources \
 && apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake binutils build-essential ca-certificates curl ffmpeg file g++ gcc gdb git \
    libasound2-dev libaudio-dev libavc1394-dev libfreetype6-dev libgif-dev libiec61883-dev \
    libjpeg-dev libjpeg-turbo-progs libnsl-dev libpng-dev libpulse-dev libraw1394-dev libtiff-dev libtool \
    libx11-dev libxt-dev lsof make openjdk-11-jdk patchelf pkg-config procps python3 \
    python3-pil strace unzip wget xz-utils yasm zip zlib1g-dev \
 && grep -q '^VERSION_ID="26.04"$' /etc/os-release \
 && java -version \
 && rm -rf /var/lib/apt/lists/*
COPY scripts/dev-entrypoint.sh /usr/local/bin/opensagetv-vibe-dev
RUN chmod 0755 /usr/local/bin/opensagetv-vibe-dev
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/opensagetv-vibe-dev"]
CMD ["help"]
