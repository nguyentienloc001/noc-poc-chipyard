# P0 — Môi trường: Plan

> Bản v2 (2026-06-10): đổi chiến lược Docker sang apt-first/multi-arch/Docker Hub root-of-trust — xem changes.md.

## Mục tiêu

Docker image **root of trust** nằm trên Docker Hub (multi-arch, apt-first, ≤2GB), từ đó môi trường build/sim tái lập được ở mọi nơi (M1, x86, GitHub CI). Chipyard build và chạy hello-world trên Verilator từ chính image này. Pin image digest + Chipyard version.

## Input từ phase trước

Dockerfile + build.sh/push.sh/.env.example trong `src/docker/` (đã viết, chưa verify). Chipyard 1.13.0 reference: verilator 5.022, gcc 13.2, openjdk 20 (từ conda-reqs — dùng làm chuẩn so sánh cho apt versions).

## Các bước

| # | Bước | Output | Ước lượng |
|---|---|---|---|
| 1 | Build image native arm64 trên M1: `cd src/docker && ./build.sh` | image local, size ghi nhận | 15–30 phút |
| 2 | Audit tools: `docker run --rm <image> /home/dev/versions.sh` — so với chuẩn Chipyard 1.13.0 (verilator 5.022, gcc 13.2). Lệch → quyết định giữ/build-from-source, ghi actual.md | bảng version trong actual.md | 30 phút |
| 3 | Trong container: clone Chipyard, checkout 1.13.0, ghi commit hash; init submodules **không conda** (thử `--skip-conda-env`, không được thì submodule thủ công) | chipyard sẵn sàng elaborate; quy trình chốt ghi vào src/docker/README.md | 1–3 giờ |
| 4 | Build Verilator sim cho `RocketConfig` bằng tools của image | sim binary | 30–60 phút |
| 5 | Chạy `hello.riscv`, xác nhận pass | log pass trong actual.md | 15 phút |
| 6 | Push: `./build.sh --arch multi` (hoặc build amd64 trên x86 + push từng arch) → Docker Hub; **pull về máy x86, lặp lại bước 4–5 từ image pull** (chứng minh root-of-trust) | image multi-arch trên Hub, digest pinned, hello pass cả 2 arch | 0.5–1 ngày |
| 7 | Smoke test pipeline đo: build `zeroload_latency.c` qua `src/benchmarks/Makefile install`, chạy trên RocketConfig, parse bằng `parse_results.py` | dòng `CSV:` trong log; 1 row trong results.csv | 1–2 giờ |
| 8 | Ghi thời gian build/sim thực tế từng máy vào actual.md | baseline tốc độ cho plan P1 | — |

## Điều kiện hoàn thành (phase gate)

- [ ] Image multi-arch (amd64+arm64) nằm trên Docker Hub; **digest pin** vào `docs/00-research-plan.md` mục 6 + PROGRESS.md.
- [ ] `RocketConfig` hello-world pass trên Verilator ở cả M1 (arm64) và x86 (amd64), **chạy từ image pull về** chứ không phải build local.
- [ ] Chipyard version + commit hash pinned; quy trình setup không-conda ghi thành lệnh chính xác trong `src/docker/README.md`.
- [ ] Pipeline benchmark→CSV chạy thông (1 row thật trong results.csv).
- [ ] Không có secret nào trong repo: `git grep -iE '(token|password|secret)' -- ':!*.example' ':!*.md'` sạch.
- [ ] Thời gian build/sim thực tế ghi nhận.

## Rủi ro của phase này

| Rủi ro | Dự phòng |
|---|---|
| apt verilator 5.020 ≠ pin 5.022 của Chipyard → lỗi tinh vi | Test bước 4–5 sẽ lộ; nếu lỗi: build verilator v5.022 từ source trong Dockerfile (ngoại lệ apt-first có ghi lý do, ~15 phút build) |
| firtool không có prebuilt aarch64 | Dockerfile đã cho phép thiếu firtool trên arm64; fallback: chisel firtool-resolver tự tải / chạy firtool x64 qua qemu / build CIRCT (nặng — phương án cuối) |
| Chipyard flow không-conda thất bại (script bám chặt conda) | Fallback: image variant có conda (ghi changes.md), root-of-trust giữ nguyên |
| sbt cần fetch dependencies lần đầu (~GB, chậm) | Cache vào volume `chipyard-vol` (ivy/coursier cache nằm trong /work hoặc mount thêm volume $HOME/.cache) |
| buildx/qemu chưa có trên máy | `docker buildx create --use` + cài qemu binfmt; hoặc build từng arch trên đúng máy native rồi push manifest |
