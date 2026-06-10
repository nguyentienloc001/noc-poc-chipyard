# P0 — Môi trường: Actual (nhật ký append-only)

> CHỈ APPEND. Mỗi entry: ngày giờ, ai (Loc/Claude/agent), việc, kết quả. Lỗi cũng ghi — lỗi là data.

---

## [2026-06-10] Claude

- Lệnh/việc: Khởi tạo phase P0 (plan + expectations). Chưa chạy lệnh build nào.
- Kết quả: Phase sẵn sàng bắt đầu từ bước 1 (docker compose build trên M1).
- Ghi chú: —

## [2026-06-10] Claude + Loc

- Lệnh/việc: Redesign chiến lược Docker trước khi bắt đầu (yêu cầu Loc): apt-first, multi-arch, root-of-trust trên Docker Hub, build.sh/push.sh, secrets qua env. Viết lại Dockerfile (ubuntu:24.04, gcc-riscv64-unknown-elf + verilator + sbt + firtool), plan.md + expectations.md v2.
- Kết quả: Ghi nhận từ conda-reqs của Chipyard 1.13.0: verilator pin 5.022, gcc 13.2, openjdk 20 — dùng làm chuẩn audit ở bước 2. Chưa build.
- Ghi chú: Rủi ro mở: E7 (verilator 5.020 vs 5.022), E8 (firtool aarch64), E9 (flow không-conda). Xem changes.md entry 2026-06-10.

## [2026-06-10] Claude + Loc

- Lệnh/việc: Refactor Dockerfile sang multi-stage (yêu cầu Loc, tối ưu size): stage `fetcher` tải firtool + sbt tgz; image cuối nhận artifact qua COPY --from. Đổi sbt từ apt-repo scala-sbt sang tgz GitHub releases → loại gnupg/keyring/sources.list phụ khỏi image cuối. PATH: /opt/sbt/bin:/opt/firtool/bin.
- Kết quả: Chưa build — verify ở P0 bước 1–2 như cũ.
- Ghi chú: SBT_VERSION=1.10.7 pin bằng ARG (cùng FIRTOOL_VERSION=1.62.1 — cả hai cần xác nhận khớp Chipyard 1.13.0 ở bước 2).

## [2026-06-10] Claude — P0 bước 0 (verify online trước build)

- Lệnh/việc: Verify asset URLs + version pins qua GitHub API và packages.ubuntu.com (chạy từ sandbox, chưa đụng máy Loc).
- Kết quả:
  - **Chipyard 1.13.0 pin firtool-1.75.0** (`conda-reqs/circt.json`) — KHÔNG phải 1.62.1 như đoán ban đầu → đã sửa `FIRTOOL_VERSION=1.75.0` trong Dockerfile.
  - firtool 1.75.0 assets: có `firrtl-bin-linux-x64.tar.gz` (URL pattern Dockerfile đúng), **không có linux-aarch64** → E8 xác nhận: arm64 image sẽ thiếu firtool, đi đường fallback.
  - sbt 1.10.7 tgz: HTTP 302 (tồn tại) ✓.
  - apt Ubuntu 24.04 (noble): verilator `5.020-1` (E7: vs pin 5.022), `gcc-riscv64-unknown-elf 13.2.0` (**khớp chính xác gcc 13.2 của Chipyard**), `picolibc-riscv64-unknown-elf 1.8.6` có, dtc `1.7.0`, default-jdk-headless = JDK 21 (Chipyard pin openjdk 20; 21 dự kiến OK với sbt — verify bước 4).
  - Chipyard 1.13.0 build.sbt: chisel6Version = 6.5.0.
- Ghi chú: Còn lại phải verify trên máy thật: build image (bước 1), versions audit (bước 2), elaborate không-conda (bước 3, E9).
