# P1 — Baseline + benchmarks: Plan

> Viết trước khi bắt đầu đo baseline. Input chính: `phases/P0-environment/report.md`, `docs/02`, `docs/03`, `docs/04`. (Bản gốc Codex 2026-06-11; normalize chính tả cùng ngày, trước khi có bất kỳ số liệu P1 nào. Nội dung giữ nguyên TRỪ 2 chỗ sync theo changes.md 2026-06-11: bước 2 "enforce ≥3 runs" → "flag <3 runs", và risk parser ghi nhận idempotency đã làm.)

## Mục tiêu

Hoàn thiện baseline crossbar 2/4/8 core và benchmark suite B1–B5 sao cho mỗi data point Verilator có raw log, provenance, ≥3 runs, median và variance check. P1 chưa đo NoC; output là baseline sạch để P2 so sánh công bằng.

## Input từ phase trước

- Docker image root-of-trust đã pin: `locnguyen96/noc-poc-chipyard@sha256:5744085506b9d7dedff92fa89e786083586cccec14af6461c03e62da34190c14`.
- Chipyard 1.13.0 commit `69eba860a352343e4ac6b6df0f3638a79a86ec78`.
- Link recipe bare-metal chốt ở P0: `-O2 --specs=picolibc.specs -B$RISCV/riscv64-unknown-elf/lib --specs=htif.specs --specs=htif_wrap.specs -T$RISCV/riscv64-unknown-elf/lib/htif.ld`.
- P0 smoke đã chứng minh `LOADMEM=1` và `TIMEOUT_CYCLES` là bắt buộc cho benchmark có `.bss` lớn.
- Sim speed M1 tham chiếu: ~4–5 kHz; B1 full-spec ước tính 3–4h/run trên M1.
- Cần sửa `idx[N_NODES]` trong `zeroload_latency.c` trước khi đo thật.
- Không dùng lại hướng `chipyard/tests/Makefile`; Chipyard 1.13 tests dùng CMake và `htif_nano.specs` không hợp image này.

## Các bước

| # | Bước | Output | Ước lượng |
|---|---|---|---|
| 1 | Sửa spec/docs cho P1: build benchmark standalone, không `tests/Makefile`; cập nhật README/docs/03/docs/04 nếu lệch P0 | docs không còn hướng dẫn sai | 1–2h |
| 2 | Harden automation trước khi đo: `run_sim.sh` resolve binary path tuyệt đối, ghi thêm image digest/project commit/binary sha256/N_RUNS/LOADMEM/TIMEOUT/seed; `parse_results.py` idempotent, flag <3 runs (xem changes.md 2026-06-11), median/min/max/variance flag | script không làm hỏng provenance | 0.5–1 ngày |
| 3 | Hoàn thiện benchmark build infra standalone trong `src/benchmarks/`: build B1–B5 bằng recipe P0, output `.riscv`, param/seed qua `-D`, build log vào `results/raw/` | build được B1–B5 không sửa Chipyard source | 0.5–1 ngày |
| 4 | Sửa/hoàn thiện benchmark: B1 static `idx`; B2 stream_bw; B3 validate multi-hart; B4 loaded_latency; B5 core2core | source B1–B5 pass compile | 1–3 ngày |
| 5 | Giải quyết startup multi-hart: verify libgloss/crt0 có đưa hart phụ vào `main` hay không; nếu không, thêm startup/link path riêng có ghi rõ trong docs/03 | B3–B5 không deadlock, mỗi hart thật sự tham gia | 0.5–2 ngày |
| 6 | Copy/install `NoCResearchConfigs.scala` vào Chipyard và build smoke `Baseline2CoreConfig`, `Baseline4CoreConfig`, `Baseline8CoreConfig`; với 8-core small, build thêm libgloss `rv64imac/lp64` nếu cần | Verilator sim baseline build pass | 0.5–1 ngày |
| 7 | Smoke B1–B5 trên `Baseline2CoreConfig` với param giảm, 1 run/bench, parse CSV vào raw test dir riêng | pipeline mới pass nhanh trước khi đo dài | 0.5–1 ngày |
| 8 | Đo baseline chính thức Verilator: Baseline2/4/8 × B1–B5, `N_RUNS≥3`, ghi raw log, parse, tick docs/04 | `results/csv/results.csv` có baseline data point hợp lệ | nhiều ngày tùy CI/M1 |
| 9 | Viết `report.md` P1: median, variance, lỗi/bỏ qua có lý do; input cho P2 NoC | P1 đóng được phase gate | 0.5 ngày |

## Điều kiện hoàn thành (phase gate)

- [ ] `plan.md` và `expectations.md` đã viết trước khi có số liệu P1.
- [ ] Benchmark build standalone dùng recipe P0; không còn phụ thuộc `chipyard/tests/Makefile`.
- [ ] B1–B5 compile và smoke pass trên `Baseline2CoreConfig`.
- [ ] `Baseline2CoreConfig`, `Baseline4CoreConfig`, `Baseline8CoreConfig` elaborate/build Verilator pass.
- [ ] Mỗi data point baseline chính thức có ≥3 runs, median, min/max, variance check; variance >5% thì có entry điều tra trong `actual.md`/`changes.md`.
- [ ] Raw logs nằm trong `results/raw/<date>-<config>-<bench>/`, có `meta.txt` đủ provenance: config, chipyard commit, project commit, docker image digest, benchmark params, seed, binary sha256.
- [ ] `docs/04-spec-experiments.md` được tick/cập nhật sau mỗi experiment.
- [ ] P1 `report.md` viết xong, nếu bỏ qua data point nào thì lý do nằm trong `changes.md`.

## Rủi ro của phase này

| Rủi ro | Dự phòng |
|---|---|
| Verilator quá chậm cho full matrix trên M1 | Chạy smoke local, đẩy full runs sang GitHub Actions/x86 hoặc chia nhỏ theo benchmark; không giảm param chính thức nếu chưa ghi `changes.md` |
| Multi-hart benchmark deadlock do crt0/libgloss park hart phụ | Verify bằng smoke B3 nhỏ; nếu cần viết startup riêng hoặc patch link flow riêng, cập nhật docs/03 trước |
| `Baseline8CoreConfig` small cần `rv64imac/lp64` libgloss | Build thêm libgloss multilib variant và ghi recipe vào docker README/P1 actual |
| Parser append duplicate làm hỏng CSV | Đã thêm idempotency ở bước 2; raw rows tách khỏi summary rows |
| NoC claim bị thiên vị vì baseline chưa tối ưu | Giữ baseline là Chipyard default crossbar, cùng cache/core/memory; report cả kết quả bất lợi cho NoC về sau |
