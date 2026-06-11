# P1 — Baseline + benchmarks: Actual

> Append-only. Moi entry co ngay + gio, lenh chay/chinh sua, ket qua, loi neu co.

## [2026-06-11 12:17 +07] Codex — review toan bo project + tao artifact P1

- Lenh/kiem tra: doc `AGENTS.md` -> `PROGRESS.md` -> P0 report/actual; quet tree bang `rg --files`/`find`; doc docs/00-05, scripts, Docker, benchmark source, Scala config; chay `bash -n` cho shell scripts va `python3 -m py_compile src/scripts/parse_results.py`; `git grep` secret-ish trong tracked files.
- Ket qua: scripts khong loi cu phap; khong thay secret that trong tracked files; worktree ban dau chi co `AGENTS.md` untracked. Review phat hien cac improve can lam truoc P1: benchmark Makefile/docs con lech P0 (dang noi `tests/Makefile`), `run_sim.sh` can resolve binary path/provenance day du hon, `parse_results.py` can enforce >=3 runs/median/idempotency, B1 `idx[]` con nam tren stack, B3-B5 can verify multi-hart startup.
- Da lam: tao `phases/P1-baseline/plan.md` va `expectations.md` theo `next_action` trong PROGRESS; tao `actual.md`/`changes.md` cho P1.
- Chua lam: chua sua source benchmark/scripts, chua chay build/sim P1, chua tao so lieu P1.

## [2026-06-11 ~13:00] Claude Code — P1 bước 1+2 XONG (sau khi audit review của Codex)

- Audit review Codex: 5/5 findings verified đúng (tự kiểm tra source: run_sim.sh cd-trước-resolve, parser không idempotent/không median, docs còn trỏ tests/Makefile). Commit nguyên trạng artifact Codex: `f84dc3d`.
- 3 điều chỉnh đã thống nhất với Loc:
  1. AGENTS.md từ bản copy CLAUDE.md → **thin pointer** (1 nguồn sự thật, tránh drift).
  2. "Enforce ≥3 runs" → flag/warn + cột `flag` trong summary (smoke vs official) — ghi changes.md TRƯỚC khi code.
  3. plan/expectations P1 normalize tiếng Việt có dấu (trước khi có số liệu; 2 ô sync theo changes.md, ghi rõ trong header).
- **Bước 1** (docs/build infra): `src/benchmarks/Makefile` viết lại standalone (recipe P0, build/*.riscv, NCORES/MARCH/MABI/DEFS); README benchmark cập nhật (build + multi-hart caveat + LOADMEM); docs/03 §1 (libgloss-htif thay vì "crt0 trong common/"); docs/04 §3 (lệnh build mới, meta provenance, schema summary.csv); CLAUDE.md sửa 3 chỗ dạy sai (Commands benchmark, data flow, quy ước link).
- **Bước 2** (harden): `run_sim.sh` — resolve BINARY tuyệt đối trước cd + validate tồn tại; meta.txt thêm platform/binary_sha256/project_commit(-dirty)/image/image_digest/n_runs/loadmem/timeout_cycles; warning khi IMAGE_DIGEST unset (không phải official run). `parse_results.py` — idempotent (skip exact-duplicate, identity = 9 trường trừ derived), sinh `results/csv/summary.csv` (median/min/max/spread%, flag smoke|HIGH-VARIANCE), warn nhóm <3 runs. compose passthrough DOCKER_IMAGE/DOCKER_TAG/IMAGE_DIGEST.
- **Verify**: `bash -n` + `py_compile` pass; parser chạy lại trên dir smoke P0 → "Appended 0 rows (skipped 1 duplicates)" + summary.csv đúng schema, flag smoke ✓; Makefile build B1 + B3 pass trong container (B1 size khớp bản P0: text 4304, bss 4MB) ✓.
- Việc kế: bước 3 đã gần xong nhờ Makefile (build infra), thực chất còn build-log-vào-results; nhảy trọng tâm sang bước 4 (sửa B1 idx[] static, viết B2/B4/B5) + bước 5 (verify multi-hart).
