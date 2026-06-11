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

## [2026-06-11 ~22:10] Claude Code — P1 bước 4 XONG + bước 5 trả lời sớm trên spike (E7)

- **E7 xác nhận ở mức source rồi giải quyết**: crtmain.S libgloss đưa hart 0 vào `main`, hart phụ chờ `__boot_sync` rồi vào `__main` — default là weak wfi-loop ("Multi-threaded programs should provide their own implementation", misc/main.c). B3 bản skeleton cũ sẽ deadlock. Fix: macro `SECONDARY_ENTRY(fn)` trong `common/sync.h` (override `__main`, chạy fn() trên hart phụ rồi park wfi để hart 0 exit() kết thúc sim sạch).
- Sources hoàn thiện (build `make all` pass, `-Wall` sạch):
  - B1: `idx[]` chuyển static (fix tràn stack 128KB > 24K htif.ld), bỏ biến thừa.
  - B2 `stream_bw.c` (mới): copy/scale/add/triad, 3 array 2MB; REPORT = triad, kernel khác ra `info:` lines (tránh trộn nhóm trong summary vì khác param bytes).
  - B3: chuyển sang SECONDARY_ENTRY, BUF_WORDS/ITERS overridable, instret hart 0 vào REPORT.
  - B4 `loaded_latency.c` (mới): hart 0 pointer-chase + harts 1..ACTIVE_LOADERS bơm STREAM tới khi done (poll mỗi 4096 words); sweep bằng `-DACTIVE_LOADERS`; REPORT ncores = 1+loaders.
  - B5 `core2core.c` (mới): ping-pong mailbox (ping/pong tách cache line) mọi cặp có thứ tự (i,j), warmup 10%, ma trận ra `c2c:i,j,cycles` lines; REPORT = cặp (0,1), param=N_RT.
- **Smoke spike** (log `results/raw/p1-step4-spike-smoke.log`; NCORES=2, params giảm qua DEFS):
  - B1/B2 single-hart pass; B3/B4/B5 **spike -p2 pass — cả 2 hart thật sự chạy** (percore đủ 2 dòng, c2c đủ 2 chiều, không deadlock) → cơ chế multi-hart VERIFIED ở mức spike; còn verify trên Verilator multi-core ở bước 7.
  - **Bug đo bị bắt nhờ smoke**: gcc -O2 elide pass idempotent lặp lại (copy chạy 1/2 ITERS: 22536 vs scale 114700 cùng access count) → bytes/cycle sẽ bị thổi phồng. Fix compiler barrier `asm volatile("" ::: "memory")` giữa iterations (B2 KERNEL + B3); verify: copy 22536 → 45068 (~2×) ✓. Ghi vào docs/03 §1 thành quy tắc.
  - Lưu ý đã ghi README: số spike là functional-only (B5 ra đúng 1,000,000 = artifact interleaving quantum spike; B4 cycles y hệt B1 vì spike không model contention). Số thật chờ Verilator.
- Trạng thái plan: bước 3 ✅ (Makefile + build log nằm trong spike-smoke log), bước 4 ✅, bước 5 ✅ phần cơ chế (libgloss contract + SECONDARY_ENTRY, docs/03 đã ghi; xác nhận cuối trên Verilator gộp vào bước 7). Kế: bước 6 — copy NoCResearchConfigs.scala vào chipyard, build Baseline2/4/8.

## [2026-06-11 ~22:15] Claude Code — P1 bước 6 lần 1: 9 lỗi compile → fix API theo example trong cây

- `make CONFIG=Baseline2CoreConfig` FAIL 9 lỗi compile (log `p1-step6-baseline2-build.log` bản cũ): (1) `WithNBigCores/WithNSmallCores` không còn ở `freechips.rocketchip.subsystem` — chipyard 1.13 chuyển sang `freechips.rocketchip.rocket` (rocket/Configs.scala:61,131); (2) `TLNoCParams` là trait, class đúng là `constellation.protocol.SimpleTLNoCParams`; import `constellation.protocol.TLNoCParams` sai.
- Đối chiếu example chuẩn trong cây (`NoCConfigs.scala` — MultiNoCConfig): idiom 1.13 là `SimpleTLNoCParams(DiplomaticNetworkNodeMapping(...), NoCParams(topology = TerminalRouter(<topo>), routingRelation = ...(TerminalRouterRouting(<routing>), ...)))`; mesh dùng `Mesh2DEscapeRouting`, ring (BidirectionalTorus1D) dùng `BidirectionalTorus1DShortestRouting` + 10 VC + depth 2.
- `NoCResearchConfigs.scala` viết lại theo idiom đó (baselines + 3 NoC configs typecheck-được; thêm `serial_tl` vào inNodeMapping — example cho thấy fbus serial_tl cũng đi qua sbus NoC). Node mappings vẫn PROVISIONAL — finalize P2 theo tên TileLink edge thật khi elaborate.
- Retry build Baseline2CoreConfig đang chạy.

## [2026-06-11 ~22:40] Claude Code — bước 6 (Baseline2) PASS + bước 7 smoke 5/5 PASS: multi-hart VERIFIED trên RTL

- Bước 6 retry (API fix): `Baseline2CoreConfig` build PASS 1m39s, 0 lỗi — cả 3 NoC config typecheck OK (log `p1-step6-baseline2-build.log`). Baseline4/8 đang build (log `p1-step6-baseline48-build.log`).
- **Bước 7 smoke 5/5 PASS** trên Baseline2CoreConfig Verilator (params giảm: BUF_WORDS=8192, FOOTPRINT=256KB, N_LOADS=5000, N_RT=200, ITERS=2; N_RUNS=1; log driver `p1-step7-smoke-driver.log`, raw từng bench `p1-step7-smoke-Baseline2CoreConfig-*/`):
  - B1: 19.17 cycles/load (smoke 256KB < L2 → chủ yếu L2 hit, hợp lý); instret 15005 KHỚP spike → deterministic, đo đúng đoạn code.
  - B2: triad 1.16 bytes/cycle; instret khớp spike.
  - B3: aggregate 2.66 B/c trên 2 core; percore 196784/191640 (lệch 2.7%) → **cả 2 hart thật sự chạy song song trên RTL** — E7 ĐÓNG hoàn toàn (spike + Verilator).
  - B4: 22.58 c/load có tải nền vs 19.17 không tải = **+17.6%** → benchmark đo được contention thật trên crossbar (đúng thiết kế thí nghiệm).
  - B5: 106.2 cycles/round-trip, 2 chiều đối xứng (21234/21206, 0.13%) — artifact interleaving của spike biến mất như dự đoán.
- Parse OK: 5 rows mới vào results.csv (tổng 6), summary.csv flag `smoke` toàn bộ — đúng thiết kế (không phải data chính thức: 1 run, params giảm).
- Phase gates tick được đến giờ: benchmark standalone ✅, B1–B5 compile + smoke pass trên Baseline2CoreConfig ✅. Còn: Baseline4/8 build (đang chạy), đo chính thức (bước 8), report.
