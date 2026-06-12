# P1 — Baseline + benchmarks: Changes

> Ghi TRUOC khi thuc hien thay doi so voi `plan.md`/`expectations.md`.

| Ngay | Thay doi | Ly do | Anh huong |
|---|---|---|---|
| 2026-06-11 | Plan bước 2: "parse_results.py enforce >=3 runs" đổi thành **flag/warn thay vì hard-fail**, thêm cơ chế đánh dấu smoke run (N_RUNS<3) tách khỏi data chính thức | Smoke flow (P0 bước 7, P1 bước 7) cố ý chạy N_RUNS=1; hard-fail sẽ vỡ smoke. Rule 4 CLAUDE.md áp cho data point CHÍNH THỨC | Gate "mỗi data point chính thức >=3 runs" giữ nguyên; parser phân biệt official vs smoke thay vì từ chối parse |
| 2026-06-13 | Tham số đo chính thức B2/B3: `ITERS=1` (qua DEFS, ghi trong param bytes của CSV) thay vì default 4 trong source | docs/03 §3 pin buffer 2MB + "cycle đo mỗi run 10^5–10^7" nhưng KHÔNG pin ITERS; ITERS=4 đẩy measured region vượt 10^7 cycles và 3 runs vượt giới hạn 6h/job CI. ITERS=1 với buffer 2MB DRAM-bound ≈ 10–16M cycles — đúng khoảng spec | Mọi config (baseline + NoC P2) dùng CÙNG ITERS=1 — so sánh công bằng giữ nguyên; param bytes trong CSV tự ghi nhận giá trị thật |

