# P1 — Baseline + benchmarks: Changes

> Ghi TRUOC khi thuc hien thay doi so voi `plan.md`/`expectations.md`.

| Ngay | Thay doi | Ly do | Anh huong |
|---|---|---|---|
| 2026-06-11 | Plan bước 2: "parse_results.py enforce >=3 runs" đổi thành **flag/warn thay vì hard-fail**, thêm cơ chế đánh dấu smoke run (N_RUNS<3) tách khỏi data chính thức | Smoke flow (P0 bước 7, P1 bước 7) cố ý chạy N_RUNS=1; hard-fail sẽ vỡ smoke. Rule 4 CLAUDE.md áp cho data point CHÍNH THỨC | Gate "mỗi data point chính thức >=3 runs" giữ nguyên; parser phân biệt official vs smoke thay vì từ chối parse |
| 2026-06-13 | Tham số đo chính thức B2/B3: `ITERS=1` (qua DEFS, ghi trong param bytes của CSV) thay vì default 4 trong source | docs/03 §3 pin buffer 2MB + "cycle đo mỗi run 10^5–10^7" nhưng KHÔNG pin ITERS; ITERS=4 đẩy measured region vượt 10^7 cycles và 3 runs vượt giới hạn 6h/job CI. ITERS=1 với buffer 2MB DRAM-bound ≈ 10–16M cycles — đúng khoảng spec | Mọi config (baseline + NoC P2) dùng CÙNG ITERS=1 — so sánh công bằng giữ nguyên; param bytes trong CSV tự ghi nhận giá trị thật |
| 2026-06-14 | **N_RUNS=1 cho mọi data point Verilator** (thay vì ≥3). Định kỳ chạy lẻ 1 bench với N_RUNS=2 để xác nhận spread=0 | Verilator fully deterministic — đã xác nhận spread=0.00% trên 4 data point đầu (B1/B3/B4/B5 Baseline2). Rule 4 (≥3 runs/median) ở Verilator chỉ là reproducibility check, KHÔNG đo variance; variance thật chỉ ở FPGA. 3 runs = 3× CI time cho 0 thông tin thêm | Quyết định của Loc 2026-06-14. CLAUDE.md/AGENTS rule 4 + docs/04 §3 cập nhật: Verilator N_RUNS=1, **FPGA (P3) giữ N_RUNS≥3** (có jitter thật). Data point Verilator cũ (B1/B3/B4/B5 đã chạy 3 runs) giữ nguyên, không cần đo lại |
| 2026-06-14 | stream_bw (B2): buffer/array **2MB → 1MB** (working set 6MB → 3MB, vẫn > L2 512KB → vẫn DRAM-bound) | 3 runs stream_bw 2MB chạm timeout 350'/job CI (benchmark 4 kernel × 3 array nặng). B3 contention_bw giữ 2MB/core (chạy fit, khác thí nghiệm) | Quyết định của Loc 2026-06-14. Áp cho MỌI config (baseline + NoC P2) → so sánh công bằng trong thí nghiệm B2 giữ nguyên. docs/03 §3 cập nhật. Chưa có data B2 chính thức nào nên không ảnh hưởng số cũ |

