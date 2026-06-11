# syntax=docker/dockerfile:1
# NoC-PoC: ROOT OF TRUST build/sim environment.
# - Multi-arch: linux/amd64 + linux/arm64 (native trên Mac M1, không cần Rosetta)
# - apt-first: tool lấy từ apt khi có gói; prebuilt binary khi không (sbt, firtool);
#   build-from-source là phương án cuối (hiện chưa cần)
# - MULTI-STAGE: stage "fetcher" tải/giải nén prebuilt binaries — curl output, tarball,
#   apt cache của bước tải KHÔNG đi vào image cuối; image cuối cũng không cần gnupg/apt-repo phụ
# - Reference versions theo Chipyard 1.13.0 conda-reqs: gcc 13.2, openjdk >=20,
#   sbt, dtc, verilator 5.022 (apt 24.04 = 5.020 — xác nhận tương thích ở P0 bước 2)
# Build bằng src/docker/build.sh (KHÔNG build tay để tag nhất quán).

ARG BASE_IMAGE=ubuntu:24.04

# ============ Stage 1: fetcher — chỉ để tải prebuilt binaries ============
FROM ${BASE_IMAGE} AS fetcher
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
# Version phải khớp Chisel của Chipyard version đã pin — xác nhận ở P0 bước 2.
# Chipyard 1.13.0 pin firtool-1.75.0 (conda-reqs/circt.json) — verified 2026-06-10
ARG FIRTOOL_VERSION=1.75.0
ARG SBT_VERSION=1.10.7

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# firtool (CIRCT) — không có gói apt.
# arm64: NO aarch64 prebuilt exists (checked firtool-1.75.0 release assets AND
# org.chipsalliance:llvm-firtool maven jar — P0 actual.md 2026-06-11). Ship the
# linux-x64 binary instead and run it via binfmt_misc (qemu/Rosetta — available
# out of the box on Docker Desktop). Identical binary on both arches => identical
# Verilog output => reproducible across machines. Cost: slower elaboration on arm64.
# Requires amd64 multiarch libc in the runtime stage (see below).
RUN set -eu; \
    FT_ARCH=linux-x64; \
    mkdir -p /opt/firtool; \
    curl -fL "https://github.com/llvm/circt/releases/download/firtool-${FIRTOOL_VERSION}/firrtl-bin-${FT_ARCH}.tar.gz" \
         -o /tmp/firtool.tar.gz; \
    tar -xzf /tmp/firtool.tar.gz -C /opt/firtool --strip-components=1

# sbt — tgz chính thức thay vì apt repo: image cuối không cần gnupg + keyring + sources.list phụ
RUN mkdir -p /opt/sbt \
    && curl -fL "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" \
       | tar -xz -C /opt/sbt --strip-components=1

# ============ Stage 2: runtime — image cuối ============
FROM ${BASE_IMAGE}
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Ho_Chi_Minh LANG=C.UTF-8 \
    PATH=/opt/sbt/bin:/opt/firtool/bin:${PATH}

# Mọi thứ có gói apt (apt-first), một layer duy nhất, dọn cache ngay
RUN apt-get update && apt-get install -y --no-install-recommends \
    # core build
    build-essential git make autoconf cmake ca-certificates curl jq sudo \
    python3 python3-pip \
    # JVM for chisel/sbt elaboration — JDK 17 LTS, NOT default-jdk (= 21 on noble):
    # chipyard 1.13's sbt 1.8.2 (scala 2.12.17 parser) cannot read JDK 21
    # classfiles -> "errorBadIndex/SbtParser NoClassDefFound" (P0 actual.md 2026-06-11)
    openjdk-17-jdk-headless \
    # HW tools
    verilator \
    device-tree-compiler \
    # RISC-V bare-metal toolchain — from apt, NOT built from source
    gcc-riscv64-unknown-elf \
    && (apt-get install -y --no-install-recommends picolibc-riscv64-unknown-elf \
        || echo "NOTE: picolibc-riscv64-unknown-elf not available; newlib bundled with gcc package") \
    && rm -rf /var/lib/apt/lists/*

# Prebuilt binaries từ fetcher — chỉ artifact cuối, không kèm tarball/cache
COPY --from=fetcher /opt/firtool /opt/firtool
COPY --from=fetcher /opt/sbt /opt/sbt

# arm64 only: amd64 libc/libstdc++ so the x64 firtool runs via binfmt_misc
# (qemu/Rosetta). Default DEB822 sources must be pinned to arm64 first, else
# apt tries amd64 on ports.ubuntu.com -> 404. ~40MB, arm64 image only.
ARG TARGETARCH
RUN if [ "${TARGETARCH}" = "arm64" ]; then \
      sed -i 's|^URIs:|Architectures: arm64\nURIs:|' /etc/apt/sources.list.d/ubuntu.sources \
      && dpkg --add-architecture amd64 \
      && printf 'deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble main universe\ndeb [arch=amd64] http://archive.ubuntu.com/ubuntu noble-updates main universe\n' \
         > /etc/apt/sources.list.d/amd64.list \
      && apt-get update \
      && apt-get install -y --no-install-recommends libc6:amd64 libstdc++6:amd64 zlib1g:amd64 \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# Non-root user (ubuntu:24.04 có sẵn user 'ubuntu' — thay bằng 'dev')
RUN (userdel -r ubuntu 2>/dev/null || true) \
    && useradd -m -s /bin/bash dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Tool report — audit bằng: docker run --rm <image> /home/dev/versions.sh
RUN printf '#!/bin/bash\nfor t in "gcc --version" "riscv64-unknown-elf-gcc --version" "verilator --version" "sbt --version" "firtool --version" "dtc --version"; do echo "== $t"; $t 2>&1 | head -2; done; echo "== java"; java -version 2>&1 | head -1\n' \
        > /home/dev/versions.sh && chmod +x /home/dev/versions.sh \
    && chown dev:dev /home/dev/versions.sh

USER dev
WORKDIR /work
CMD ["/bin/bash"]
