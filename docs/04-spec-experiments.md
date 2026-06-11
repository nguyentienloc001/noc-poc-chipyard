# 04 — Spec: Ma trận thí nghiệm & quy trình

## 1. Ma trận chính (Verilator — toàn bộ)

| # | Config | B1 | B2 | B3 | B4 | B5 | B6 |
|---|---|---|---|---|---|---|---|
| E1 | Baseline2CoreConfig | ☐ | ☐ | ☐ | ☐ | ☐ | — |
| E2 | Baseline4CoreConfig | ☐ | ☐ | ☐ | ☐ | ☐ | — |
| E3 | Baseline8CoreConfig | ☐ | ☐ | ☐ | ☐ | ☐ | — |
| E4 | NoCMesh2x2_4CoreConfig | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| E5 | NoCMesh3x3_8CoreConfig | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| E6 | NoCRing8CoreConfig (phụ) | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

Cặp so sánh chính: **E2↔E4** (4 core) và **E3↔E5** (8 core).

## 2. Ma trận FPGA VC707 (tập con xác nhận)

| # | Config | Synthesis (LUT/FF/BRAM/Fmax) | B1 | B3 | B4 |
|---|---|---|---|---|---|
| F1 | Baseline4CoreConfig | ☐ | ☐ | ☐ | ☐ |
| F2 | NoCMesh2x2_4CoreConfig | ☐ | ☐ | ☐ | ☐ |
| F3 | Baseline8CoreConfig (nếu fit) | ☐ | ☐ | ☐ | ☐ |
| F4 | NoCMesh3x3_8CoreConfig (nếu fit) | ☐ | ☐ | ☐ | ☐ |

Synthesis report là deliverable bắt buộc kể cả khi board không chạy được (trả lời RQ2).

## 3. Quy trình một thí nghiệm (chuẩn hóa)

1. Checkout đúng commit Chipyard đã pin; ghi `git rev-parse HEAD`.
2. Build sim: `src/scripts/run_sim.sh <Config> --build-only`; lưu log build.
3. Build benchmark (standalone, xem `src/benchmarks/README.md`): `make -C src/benchmarks all NCORES=<N> MARCH=<march> MABI=<mabi>`.
4. Chạy ≥3 lần: `src/scripts/run_sim.sh <Config> <bench.riscv>` (script default `N_RUNS=3`, `LOADMEM=1`, `TIMEOUT_CYCLES=200M`; ghi `meta.txt` provenance: config, chipyard commit, project commit, binary sha256, image, n_runs, loadmem, timeout). Data chính thức: chạy từ image đã pin và export `IMAGE_DIGEST` để vào meta.
5. Parse: `src/scripts/parse_results.py results/raw/<dir>` → append `results/csv/results.csv` (idempotent — re-parse cùng dir không tạo duplicate) + regenerate `results/csv/summary.csv` (median/min/max/spread theo nhóm; nhóm <3 runs bị flag `smoke` — không dùng làm data point chính thức).
6. Tick ô tương ứng ở ma trận trên + ghi ngày, commit hash vào mục 5.

Schema `results/csv/summary.csv` (sinh tự động từ results.csv, không sửa tay):
`platform,config,benchmark,n_active_cores,param,n_runs,median_cycles,min_cycles,max_cycles,spread_pct,median_derived,flag`
(`flag` = `smoke` nếu n_runs<3, `HIGH-VARIANCE` nếu spread>5% — cả hai đều phải điều tra/ghi chú trước khi dùng).

## 4. Phân tích (P4)

- Biểu đồ chính: (a) aggregate BW vs N core, 2 đường crossbar/NoC — break-even là giao điểm; (b) loaded latency vs background load; (c) bảng tài nguyên & Fmax; (d) scatter Verilator vs FPGA cùng benchmark (RQ3).
- Thống kê: median ± min/max của ≥3 runs; không dùng mean nếu có outlier.
- Mọi biểu đồ sinh bằng script (matplotlib) từ `results.csv` — reproducible.

## 5. Nhật ký thí nghiệm

| Ngày | Thí nghiệm | Commit chipyard | Ghi chú |
|---|---|---|---|
| 2026-06-11 | Pipeline smoke (P1 bước 7): B1–B5 trên Baseline2CoreConfig, param GIẢM, 1 run/bench | 69eba860 | KHÔNG phải data point chính thức (flag smoke trong summary.csv). 5/5 PASS: multi-hart verified trên RTL (B3 percore đủ 2 hart), B4 đo được +17.6% latency dưới tải, B5 106 c/RT. Log: `p1-step7-smoke-*` |
| 2026-06-11 | Pipeline smoke (P0 bước 7): B1 zeroload_latency trên RocketConfig, param GIẢM (-DFOOTPRINT=2MB -DN_LOADS=20000), 1 run | 69eba860 | KHÔNG phải data point chính thức (config/param ngoài ma trận). Pipeline benchmark→sim→CSV verified; 52.6 cycles/load; row trong results.csv giữ làm bằng chứng smoke. LƯU Ý P1: chạy benchmark lớn cần LOADMEM=1 + TIMEOUT_CYCLES (đã default trong run_sim.sh); sửa idx[] 128KB stack trong zeroload trước khi đo thật |
