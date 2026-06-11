# P0 — Môi trường: Report

> Đóng phase 2026-06-11. Input chính cho P1 và mục Môi trường của chương luận văn.

## Tóm tắt 3 câu

Docker image root-of-trust (apt-first, multi-arch, 2.39GB) đã nằm trên Docker Hub với digest pinned, và `RocketConfig` hello-world pass trên Verilator **ở cả arm64 (M1, image pull) lẫn x86_64 (GitHub Actions runner, image pull theo digest)** — root-of-trust được chứng minh. Pipeline đo benchmark→sim→CSV chạy thông end-to-end (1 row thật trong `results.csv`). Chi phí chính của phase là 6 root cause không lường trước (đáng kể nhất: bug alignment upstream trong libgloss-htif và JDK21×sbt1.8.2), tất cả đã fix có bằng chứng và tái lập được.

## Expectations vs Actual

| # | Dự đoán | Thực tế | Đúng/Sai | Giải thích |
|---|---|---|---|---|
| E1 | Image 1.5–2GB, build 15–30 phút | 2.39GB, build ~3–5 phút | Gần đúng | Size lệch +20% (chấp nhận); build nhanh hơn nhiều dự kiến |
| E2 | Build sim RocketConfig 30–60 phút native | sbt cold ~25 phút + verilate/g++ ~1 phút (sau khi sửa JDK/firtool); CI x86 trọn gói từ zero: 25m15s | Đúng | — |
| E3 | Sim speed 1–10 kHz | ~4–5 kHz (đo từ timeout 10M cycles ≈ 40 phút) | Đúng | 1 data point B1 full-spec ≈ 3–4h/run trên M1 — input quan trọng cho khối lượng P1 |
| E4 | hello pass không sửa code Chipyard | Đúng — không sửa dòng Chipyard nào (chỉ patch submodule libgloss, có patch file) | Đúng | — |
| E5 | Benchmark build qua tests/ cần chỉnh Makefile | SAI hướng khác: chipyard 1.13 tests/ dùng **CMake** chứ không phải Makefile; và htif_nano.specs không dùng được với picolibc | Sai | P1 dùng link recipe standalone đã chốt (actual.md 2026-06-11) thay vì tests/ infra |
| E6 | crt0 park hart phụ | Đúng theo thiết kế libgloss (`_start_secondary` chờ barrier) + **bonus phát hiện bug**: `__boot_sync` thiếu `.balign` → trap với picolibc | Đúng+ | Patch `src/patches/0001-...`; bug tiềm ẩn cả trên FPGA |
| E7 | verilator 5.020 OK dù pin 5.022 | Verilate + compile + sim pass | Đúng | Không cần build verilator từ source |
| E8 | firtool thiếu aarch64 → fallback | Đúng; fallback chốt: binary linux-x64 qua qemu binfmt + amd64 libs trong image — ~30–60s cho RocketConfig, không phải bottleneck | Đúng | Binary identical 2 arch → Verilog reproducible; KHÔNG cần build CIRCT |
| E9 | Không-conda khả thi, tốn công thử | Đúng, tốn hơn dự kiến (3 vòng build-setup + script manual + 2 fix image) | Đúng | Quy trình chốt trong src/docker/README.md |
| E10 | sbt cold fetch 20–40 phút | ~25 phút (gộp trong lần compile đầu), cache vào home-vol | Đúng | — |

**Ngoài dự đoán (không có expectation nào cover):** (1) JDK 21 không dùng được với sbt 1.8.2 của chipyard → image phải pin openjdk-17; (2) TSI serial load treo `wfi` với benchmark bss lớn → bắt buộc `LOADMEM=1`; (3) chipyard default `+max-cycles=10M` quá thấp → `TIMEOUT_CYCLES` trong run_sim.sh.

## Điều kiện hoàn thành — kiểm lại

- [x] Image multi-arch (amd64+arm64) trên Docker Hub, digest pin vào docs/00 §6 + PROGRESS.md — `locnguyen96/noc-poc-chipyard:20260611-a998101` @ `sha256:57440855...` (manifest inspect: 2 platforms)
- [x] RocketConfig hello pass cả 2 arch **từ image pull**: x86_64 = CI run 27315807639 (log `results/raw/p0-step6-ci/`, "X86 ROOT-OF-TRUST VERIFY: PASS"); arm64 = pull theo digest + hello pass (`results/raw/p0-step6-arm64-pulled.log`). Lưu ý trung thực: arm64 dùng sim binary build sẵn trong volume (build bởi image local cùng Dockerfile); x86 build từ zero hoàn toàn trong CI
- [x] Chipyard 1.13.0 @ `69eba860` pinned; quy trình không-conda thành lệnh chính xác trong `src/docker/README.md` (+ script `p0-step3-manual.sh`, `p0-step6-x86-verify.sh` chạy lại được)
- [x] Pipeline benchmark→CSV: 1 row thật trong `results/csv/results.csv` (smoke, ghi chú docs/04 §5)
- [x] Secrets check: `git grep` chỉ match tên biến env trong push.sh/gitignore (cơ chế, không phải giá trị); `.env` gitignored, token không vào log
- [x] Thời gian build/sim ghi nhận (actual.md entry "step 8")

## Bài học & quyết định cho phase sau

1. **Link recipe bare-metal chuẩn** (mọi benchmark P1): `riscv64-unknown-elf-gcc -O2 --specs=picolibc.specs -B$RISCV/riscv64-unknown-elf/lib --specs=htif.specs --specs=htif_wrap.specs -T$RISCV/riscv64-unknown-elf/lib/htif.ld` — KHÔNG dùng htif_nano.specs (cần newlib-nano, image không có), KHÔNG dựa tests/Makefile (1.13 là CMake).
2. **Chạy sim**: luôn qua `run_sim.sh` (đã default `LOADMEM=1` + `TIMEOUT_CYCLES=200M`). Triệu chứng quên LOADMEM: trace chỉ có bootrom + `wfi`.
3. **Khối lượng P1**: sim 4–5 kHz → mỗi data point B1 full-spec 3–4h × 3 runs × số config — phải budget thời gian theo con số này; cân nhắc chạy CI/x86 song song (CI x86 build sạch chỉ 25 phút, nhanh hơn M1 đáng kể).
4. **Sửa trước khi đo thật**: `idx[N_NODES]` trong zeroload_latency.c = 128KB stack > 24K htif.ld → chuyển sang static/bss hoặc tăng `__stack_size_min`.
5. **8-core small config (P2)**: cần build thêm libgloss multilib `rv64imac/lp64` (`configure --enable-multilib="rv64imac/lp64"`).
6. Mọi component build collateral phải **scope flags theo từng target** (riscv vs host) — CFLAGS global đã phá host build 1 lần.
7. CI đã có sẵn (`p0-x86-verify` workflow) — P1 nên thêm workflow build+smoke config mới mỗi lần đổi Scala config.

## Artifact bàn giao

- Image pinned: `locnguyen96/noc-poc-chipyard@sha256:5744085506b9d7dedff92fa89e786083586cccec14af6461c03e62da34190c14` (docs/00 §6)
- Volume `chipyard-vol` (M1): chipyard 1.13.0 @ 69eba860 + đầy đủ collateral + sim RocketConfig đã build
- `src/patches/0001-libgloss-htif-balign-boot_sync.patch` — bắt buộc áp khi setup mới (p0-step3-manual.sh tự áp)
- Scripts tái lập: `p0-step3-manual.sh`, `p0-step6-x86-verify.sh`, `run_sim.sh` (LOADMEM/TIMEOUT_CYCLES), `parse_results.py`
- `.github/workflows/p0-x86-verify.yml` — mẫu CI cho P1
- `results/csv/results.csv` (1 smoke row) + toàn bộ raw logs `results/raw/p0-*`
- GitHub repo: `nguyentienloc001/noc-poc-chipyard` (private)
