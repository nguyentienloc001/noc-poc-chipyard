# P1 — Baseline + benchmarks: Changes

> Ghi TRUOC khi thuc hien thay doi so voi `plan.md`/`expectations.md`.

| Ngay | Thay doi | Ly do | Anh huong |
|---|---|---|---|
| 2026-06-11 | Plan bước 2: "parse_results.py enforce >=3 runs" đổi thành **flag/warn thay vì hard-fail**, thêm cơ chế đánh dấu smoke run (N_RUNS<3) tách khỏi data chính thức | Smoke flow (P0 bước 7, P1 bước 7) cố ý chạy N_RUNS=1; hard-fail sẽ vỡ smoke. Rule 4 CLAUDE.md áp cho data point CHÍNH THỨC | Gate "mỗi data point chính thức >=3 runs" giữ nguyên; parser phân biệt official vs smoke thay vì từ chối parse |
