# Docker — Root of trust cho toàn project

## Nguyên tắc

1. **Image là root of trust**: mọi build/sim (Verilator flow) chạy trong image này — trên M1, x86, và GitHub CI đều dùng cùng một image pull từ Docker Hub. Image + digest được pin tại `docs/00-research-plan.md` mục 6.
2. **apt-first**: RISC-V toolchain (`gcc-riscv64-unknown-elf`), Verilator, dtc, JDK... lấy từ apt. Build-from-source chỉ khi không có gói — hiện chỉ có 2 ngoại lệ, đều là prebuilt binary chứ chưa phải build source: `sbt` (tgz chính thức từ GitHub releases) và `firtool` (binary từ GitHub releases của CIRCT). Cả hai tải ở stage `fetcher`.
3. **Multi-arch**: arm64 (native M1 — không cần Rosetta) + amd64. Chọn arch lúc build.
4. **Nhẹ**: ubuntu:24.04 + `--no-install-recommends` + jdk-headless, không conda (conda env của Chipyard ~10–20GB; image này mục tiêu ≤2GB). **Multi-stage build**: stage `fetcher` tải sbt/firtool — tarball, curl, gnupg, apt-repo phụ không đi vào image cuối; image cuối chỉ nhận artifact qua `COPY --from=fetcher`.
5. **Secrets chỉ qua env var**: xem `.env.example`. `.env` đã gitignore. CI dùng repository secrets.

## Workflow

```bash
cd src/docker

# 1. Build native (M1 → arm64, x86 → amd64)
./build.sh

# 2. Audit tool versions trong image
docker run --rm local/noc-poc-chipyard:latest /home/dev/versions.sh

# 3. Push lên Docker Hub
cp .env.example .env   # điền DOCKERHUB_USER + DOCKERHUB_TOKEN
source .env
./build.sh             # rebuild với tên <user>/noc-poc-chipyard
./push.sh <tag>

# Multi-arch một phát (build + push cả amd64+arm64, cần buildx + qemu):
./build.sh --arch multi

# 4. Dùng ở máy khác / CI: chỉ cần pull
docker pull <user>/noc-poc-chipyard:<tag>

# 5. Dev hằng ngày
docker compose run --rm chipyard
```

## Quan hệ với Chipyard

Image KHÔNG chứa Chipyard source (giữ image nhẹ + tách version: đổi Chipyard không cần rebuild image). Chipyard clone vào volume `chipyard-vol` (persist), elaborate bằng sbt/firtool/verilator của image — **bỏ qua conda flow** của `build-setup.sh`. Các bước thay thế (xác nhận chính xác ở P0 bước 3):

```bash
cd /work
git clone https://github.com/ucb-bar/chipyard.git && cd chipyard
git checkout <PINNED>            # docs/00 mục 6
# init submodules cần thiết, KHÔNG chạy conda — flags chính xác chốt ở P0:
./build-setup.sh --skip-conda-env -s 6 -s 7 -s 8 -s 9   # hoặc git submodule update thủ công
```

Nếu flow không-conda bế tắc (ghi vào `changes.md` của P0): fallback = image variant có conda (nặng nhưng chạy chắc chắn), vẫn giữ nguyên tắc root-of-trust.

## Vivado (nhắc lại)

Vivado KHÔNG nằm trong image — chỉ chạy x86 Linux/Windows, cài trực tiếp trên host x86. Image chỉ phục vụ Verilator flow + build benchmark. Kết quả đo bằng cycle count nên không phụ thuộc tốc độ máy chạy sim.

## Files

| File | Vai trò |
|---|---|
| `Dockerfile` | Multi-stage (fetcher → runtime), ARG `BASE_IMAGE`/`FIRTOOL_VERSION`/`SBT_VERSION`, multi-arch qua `TARGETARCH` |
| `build.sh` | Build: native / `--arch amd64\|arm64` / `--arch multi` (build+push) |
| `push.sh` | Login bằng env token (qua stdin, không lộ trong argv/ps), push, in digest để pin |
| `.env.example` | Template secrets — copy thành `.env` (gitignored), hoặc export trong shell |
| `docker-compose.yml` | Dev hằng ngày: mount repo + volume chipyard |
