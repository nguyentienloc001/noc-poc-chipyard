# P1 — Baseline + benchmarks: Actual

> Append-only. Moi entry co ngay + gio, lenh chay/chinh sua, ket qua, loi neu co.

## [2026-06-11 12:17 +07] Codex — review toan bo project + tao artifact P1

- Lenh/kiem tra: doc `AGENTS.md` -> `PROGRESS.md` -> P0 report/actual; quet tree bang `rg --files`/`find`; doc docs/00-05, scripts, Docker, benchmark source, Scala config; chay `bash -n` cho shell scripts va `python3 -m py_compile src/scripts/parse_results.py`; `git grep` secret-ish trong tracked files.
- Ket qua: scripts khong loi cu phap; khong thay secret that trong tracked files; worktree ban dau chi co `AGENTS.md` untracked. Review phat hien cac improve can lam truoc P1: benchmark Makefile/docs con lech P0 (dang noi `tests/Makefile`), `run_sim.sh` can resolve binary path/provenance day du hon, `parse_results.py` can enforce >=3 runs/median/idempotency, B1 `idx[]` con nam tren stack, B3-B5 can verify multi-hart startup.
- Da lam: tao `phases/P1-baseline/plan.md` va `expectations.md` theo `next_action` trong PROGRESS; tao `actual.md`/`changes.md` cho P1.
- Chua lam: chua sua source benchmark/scripts, chua chay build/sim P1, chua tao so lieu P1.
