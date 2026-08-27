ARG FFMPEG_BUILDER_IMAGE=opensagetv-vibe-ffmpeg-mim-builder:9.0.1-v5
FROM ${FFMPEG_BUILDER_IMAGE}
USER root
LABEL org.opencontainers.image.title="OpenSageTV Vibe Unified Build Environment" \
      org.opencontainers.image.description="One development image for OpenSageTV Vibe Core, FFmpeg/MIM, XMLTV, tests, and release staging" \
      org.opencontainers.image.source="https://github.com/opensagetv-vibe/opensagetv-vibe-build-env"
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    JDK_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    GRADLE_USER_HOME=/work/.gradle
RUN rm -f /etc/apt/sources.list.d/nodesource.list /etc/apt/sources.list.d/nodesource.sources \
 && apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake binutils build-essential ca-certificates curl ffmpeg file g++ gcc gdb git \
    libasound2-dev libaudio-dev libavc1394-dev libfreetype6-dev libgif-dev libiec61883-dev \
    libjpeg-dev libjpeg-turbo-progs libnsl-dev libpng-dev libpulse-dev libraw1394-dev libtiff-dev libtool \
    libx11-dev libxt-dev lsof make openjdk-11-jdk patchelf pkg-config procps python3 \
    python3-pil strace unzip wget xz-utils yasm zip zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*
COPY scripts/dev-entrypoint.sh /usr/local/bin/opensagetv-vibe-dev
RUN chmod 0755 /usr/local/bin/opensagetv-vibe-dev
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/opensagetv-vibe-dev"]
CMD ["help"]
