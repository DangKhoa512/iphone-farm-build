# =============================================================================
# Dockerfile thay thế — dùng khi đã có Docker Desktop
# Build:   docker build -t iphone-farm-builder .
# Run:     docker run --rm -v "%CD%\..\ios-deb:/project" iphone-farm-builder
# =============================================================================

FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Dependencies
RUN apt-get update -qq && apt-get install -y -qq \
    curl git make clang ca-certificates \
    libplist-utils zip unzip xz-utils bzip2 \
    python3 rsync fakeroot dpkg-dev \
    && rm -rf /var/lib/apt/lists/*

# Cài Theos
ENV THEOS=/opt/theos
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)" \
    || true

# Tải iOS SDKs
RUN git clone --depth=1 https://github.com/theos/sdks /opt/theos/sdks 2>&1 | tail -3

ENV PATH="/opt/theos/bin:$PATH"

WORKDIR /project

# Entrypoint: build khi container chạy
CMD ["bash", "-c", "\
    echo '=== Building DEB ===' && \
    make clean && \
    make package FINALPACKAGE=1 && \
    DEB=$(find packages/ -name '*.deb' | head -1) && \
    [ -n \"$DEB\" ] && cp \"$DEB\" /output/ && \
    echo \"=== Done: /output/$(basename $DEB) ===\""]
