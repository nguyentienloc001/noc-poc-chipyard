# 03 — Spec: Benchmarks & Metrics

## 1. Nguyên tắc đo

- **Bare-metal** (không OS) để loại nhiễu: crt0 + linker script + HTIF syscalls lấy từ **libgloss-htif** (chipyard submodule, đã patch + install vào `$RISCV` ở P0); headers đo nằm trong `src/benchmarks/common/`. Build standalone bằng `src/benchmarks/Makefile` theo link recipe pin ở `phases/P0-environment/report.md` — KHÔNG dùng `chipyard/tests/` (1.13 là CMake + htif_nano.specs, không hợp toolchain picolibc của image).
- Đếm cycle bằng CSR `rdcycle` (và `rdinstret` để sanity-check), wrap trong `src/benchmarks/common/perf.h`. printf đi qua `htif_wrap.specs` (`--wrap=printf/puts/...` → HTIF console trực tiếp).
- Mỗi benchmark: warm-up 1 lần (nạp cache/predictor) rồi đo; in kết quả qua UART/HTIF dạng `CSV:<bench>,<n_active_cores>,<param>,<cycles>,<instret>` (macro `REPORT` trong `perf.h`; config/platform lấy từ `meta.txt` do `run_sim.sh` ghi).
- Multi-core: libgloss-htif đưa hart 0 vào `main()`, hart phụ vào `__main()` (default = wfi loop) — benchmark multi-hart override bằng macro `SECONDARY_ENTRY(fn)` trong `common/sync.h` (verified spike -p2, P1 actual.md 2026-06-11). Core 0 điều phối qua biến shared + barrier (atomic AMO); binary phải build với `-DNCORES` = đúng số core của config.
- Vòng lặp đo lặp ITERS lần phải có compiler barrier giữa các iteration (`asm volatile("" ::: "memory")`) — gcc -O2 elide pass idempotent lặp lại (phát hiện trên spike: copy chạy 1/2 ITERS → bytes/cycle bị thổi phồng).
- Cùng một binary chạy trên cả Verilator và FPGA (chỉ khác tần số — kết quả báo theo **cycle**, không theo giây).

## 2. Danh sách benchmark

### B1 — `zeroload_latency` (NoC dự kiến THUA — đo trade-off)

1 core chạy pointer-chase (linked list ngẫu nhiên, stride > cache line, footprint > L2) → load-to-use latency tới DRAM khi mạng rỗi. Metric: cycles/load.

### B2 — `stream_bw` (single-core bandwidth)

STREAM triad rút gọn (copy/scale/add/triad) trên buffer > L2. Metric: bytes/cycle của 1 core khi không contention.

### B3 — `contention_bw` (metric CHÍNH — NoC dự kiến thắng)

N core đồng thời chạy STREAM trên buffer riêng (không share data, chỉ share interconnect + DRAM). Sweep N = 1→tổng số core. Metric: aggregate bytes/cycle và đường scale theo N. Đây là thí nghiệm trả lời RQ1 trực tiếp.

### B4 — `loaded_latency` (metric CHÍNH)

Core 0 chạy pointer-chase (như B1) trong khi N-1 core bơm tải STREAM. Sweep N. Metric: cycles/load của core 0 theo mức tải nền → cho thấy crossbar nghẽn, NoC giữ latency ổn định; xác định saturation point.

### B5 — `core2core` (giao tiếp core-core)

Ping-pong qua shared memory: core A ghi flag+payload, core B đọc và đáp. Đo round-trip giữa **mọi cặp core** → ma trận latency NxN. Trên mesh, latency phụ thuộc khoảng cách hop (kết quả đặc trưng của NoC); trên crossbar, đồng đều nhưng nghẽn khi nhiều cặp song song. Biến thể: tất cả các cặp cùng lúc (all-to-all) → aggregate msg/cycle.

### B6 (phụ) — Synthetic traffic bằng Constellation

Dùng traffic injection framework có sẵn của Constellation (uniform random, tornado...) để có đường latency-vs-injection-rate chuẩn academic. Chỉ chạy được phía NoC (không có cho crossbar) — dùng làm characterization, không phải so sánh.

## 3. Tham số chuẩn

| Tham số | Giá trị | Ghi chú |
|---|---|---|
| Footprint pointer-chase | 4 MB | > L2 512KB, ép ra DRAM |
| STREAM buffer/core | 2 MB | |
| Số lần lặp đo | ≥ 3 runs, báo median | variance > 5% → điều tra |
| Cycle đo mỗi run | 10⁵–10⁷ | đủ ngắn cho Verilator |
| Compiler | riscv64-unknown-elf-gcc -O2 -march=rv64gc (big) / rv64imac (small) | |

## 4. Schema kết quả

```
results/csv/results.csv:
date,platform,config,benchmark,n_active_cores,param,run_idx,cycles,instret,derived_metric
```

`platform` ∈ {verilator, vc707}. `derived_metric` = bytes/cycle hoặc cycles/load tùy benchmark. Raw stdout giữ tại `results/raw/<date>-<config>-<bench>/run<i>.log`.

## 5. Điều kiện hoàn thành

- [ ] B1–B5 chạy pass trên `Baseline2CoreConfig` Verilator, variance < 5%.
- [ ] Kết quả B2 đối chiếu hợp lý với lý thuyết (bandwidth ≤ DRAM model).
- [ ] `instret` ổn định giữa các run (chứng tỏ đo đúng đoạn code).
