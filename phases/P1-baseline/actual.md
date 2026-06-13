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

## [2026-06-11 ~22:25] Claude Code — bước 6 ĐÓNG: cả 3 baseline build PASS; march small-core xác nhận (E8)

- `Baseline4CoreConfig`: PASS 1m35s, sim 14.3MB. dts: core = **rv64imafdc** (big, có FPU) → benchmark giữ MARCH=rv64gc MABI=lp64d.
- `Baseline8CoreConfig`: PASS, sim 16.6MB. dts: core = **rv64imac** (small, KHÔNG FPU) → **expectations E8 ĐÚNG**: benchmark cho 8-core phải build MARCH=rv64imac MABI=lp64, và cần libgloss multilib `rv64imac/lp64` (P0 report bài học #5: `configure --enable-multilib="rv64imac/lp64"`). Việc này nằm trong bước chuẩn bị đo 8-core, CHƯA làm.
- Gate "Baseline2/4/8 elaborate/build Verilator pass": ✅ cả 3. Log `p1-step6-baseline48-build.log`.
- Còn lại P1: (a) build libgloss rv64imac/lp64 + benchmark rv64imac cho Baseline8; (b) smoke nhanh B3 NCORES=4 trên Baseline4 (xác nhận barrier với 4 hart); (c) bước 8 đo chính thức — cần chốt với Loc chạy ở đâu (M1 ~3-4h/run B1 full vs GitHub CI x86; private repo có 2000 phút/tháng); (d) report.md.

## [2026-06-12 ~06:40] Loc + Claude Code — quyết định: repo PUBLIC + CI đo chính thức; libgloss rv64imac xong

- **Quyết định của Loc**: phương án 3 — repo public để CI không giới hạn phút. Pre-publish: quét secret toàn git history (token patterns + lịch sử .env) → SẠCH. Repo đã PUBLIC: https://github.com/nguyentienloc001/noc-poc-chipyard
- **libgloss multilib rv64imac/lp64** (cho Baseline8, E8): 2 vòng debug —
  1. `--enable-multilib="rv64imac/lp64"` FAIL: binutils đòi `_zicsr` trong -march (crt0.S csrr).
  2. Fix: build với `rv64imac_zicsr_zifencei/lp64` rồi **mv thư mục install về `rv64imac/`** (tên multilib dir mà gcc tìm — verify bằng `-print-multi-directory`). PASS, `lib/rv64imac/lp64/libgloss_htif.a` ✓.
- Benchmark 8-core: build với `MARCH=rv64imac_zicsr_zifencei MABI=lp64` (perf.h csrr cũng cần zicsr; gcc map multilib về rv64imac/lp64 ✓). Spike run: 2 false-alarm do isa string spike (thiếu zicsr rồi thiếu **zicntr** — counters tách extension riêng; trace `csrr a4, cycle` illegal) → isa đúng cho spike test imac: `rv64imac_zicsr_zifencei_zicntr`. B1 imac chạy đúng, số khớp y hệt rv64gc (15005 instret). Log: `p1-step8-libgloss-imac.log`. LƯU Ý: Rocket thật có counters (dts: zihpm) — artifact này chỉ của spike.
- CI infra đo chính thức: `src/scripts/p1-ci-measure.sh` (bootstrap từ image pinned → build sim+bench → run_sim.sh full provenance, tự build libgloss imac khi MARCH=rv64imac*) + workflow `p1-measure.yml` (dispatch theo config×bench, IMAGE_DIGEST set → meta đạt chuẩn official docs/04 §3, raw artifact → parse local).
- Smoke B3 NCORES=4 trên Baseline4 đang chạy nền.

## [2026-06-12 ~07:00] Claude Code — smoke B3 4-hart PASS: barrier/multi-hart OK ở 4 core, sublinear scaling lộ diện

- B3 NCORES=4 trên Baseline4CoreConfig: `CSV:contention_bw,4,1048576,277779,80839` — percore đủ 4 dòng (273555/267475/258586/277779, spread 7.4% = contention thật giữa các core trên crossbar).
- So sánh smoke (params nhỏ, KHÔNG chính thức): aggregate 2-core 2.66 B/c → 4-core 3.77 B/c (+42% khi gấp đôi core); per-core 1.33 → 0.94 B/c → **sublinear scaling đúng expectations E5**. Đây là dấu hiệu tốt: thí nghiệm chính (RQ1) sẽ có tín hiệu rõ.
- Multi-hart verified: 2-hart (spike+Verilator), 4-hart (Verilator). 8-hart sẽ verify khi đo Baseline8 (binary rv64imac).
- Pilot CI (Baseline2 × B1 full × 3 runs) đang chạy — run 27384517360.

## [2026-06-12 ~07:3x] Claude Code — pilot CI lần 1 fail (2 bug workflow), đã fix + re-dispatch

- Pilot run 27384517360: job XANH GIẢ trong 14m48s — (a) `docker run | tee` nuốt exit code (đúng pattern tee-masking của P0); (b) script chết thật ở `mkdir build: Permission denied` (checkout uid 1001 vs container dev uid 1000 — chmod thiếu `src/benchmarks`). Artifact không có raw dir/CSV nào.
- **Số quý từ lần fail**: bootstrap chipyard + build sim Baseline2 trên CI runner = **~14 phút** (so 25m của P0 verify; runner nhanh).
- Fix: workflow thêm `set -o pipefail` + chmod `results results/raw src/benchmarks`; script thêm `git safe.directory /project` (meta ghi đúng project_commit) + **hard assert mỗi run phải có dòng CSV** (job xanh không data = tệ hơn job đỏ).
- Re-dispatch pilot.

## [2026-06-13 ~00:00] Claude Code — pilot v2 THÀNH CÔNG: data point chính thức ĐẦU TIÊN

- Run 27416365222 success sau **3h58'** (bootstrap+build 14', sim ~75'/run × 3): **B1/Baseline2 = 53.4137 cycles/load** (median 3 runs, spread 0.00% — E3 đúng, Verilator deterministic; instret 300005 chuẩn). Meta đủ provenance (image_digest pinned, binary sha256, chipyard+project commit). Row KHÔNG flag trong summary.csv — data point chính thức đầu tiên của luận văn. Raw: `results/raw/ci-20260612-r27416365222-...`
- Sim speed CI runner ≈ **11–12 kHz** (~3× M1). Ước job 3-runs: B1@2/4-core ~4h ✓ fit; combo 8-core (~2–3× chậm) sẽ vượt 6h/job → đã thêm `RUN_OFFSET` vào run_sim.sh + p1-ci-measure.sh + workflow (tách 3 runs thành 3 jobs song song n_runs=1, run_idx phân biệt — không bị parser dedup).
- Fix nhỏ provenance: `-dirty` trong meta do file untracked → `--untracked-files=no`.
- changes.md: official B2/B3 dùng `-DITERS=1` (spec không pin ITERS; giữ measured region trong khoảng 10^5–10^7 cycles của docs/03; cùng giá trị cho mọi config kể cả NoC P2).

## [2026-06-13 ~01:00] Claude Code — E1 Baseline2: 4/5 data point chính thức (B2 re-run)

- Đợt dispatch Baseline2: 1 job stream_bw bị cancel do bug word-splitting (zsh không tách `"$3"` unquoted như bash — dispatch lại tường minh từng lệnh). 3 job kia (B3/B4/B5) PASS, cộng B1 pilot = 4/5 official.
- **4 data point chính thức (N_RUNS=3, full provenance, KHÔNG flag)**:
  - B1 zeroload: 53.41 c/load
  - B3 contention_bw: 1.581 B/c aggregate (2 core, 8MB total)
  - B4 loaded_latency: 56.27 c/load (= +5.4% vs B1 zero-load → 1 background loader đã làm latency tăng, đúng thiết kế)
  - B5 core2core: 109.4 c/round-trip
- B2 stream_bw đang chạy lại (run 27460560855).
- **QUAN SÁT KHOA HỌC quan trọng (cho report + đề xuất với Loc)**: mọi data point spread = **0.00%** — Verilator fully deterministic (cùng binary + config → cycle count y hệt mọi run). Hệ quả: quy tắc "≥3 runs báo median" của CLAUDE.md/AGENTS rule 4 với Verilator chỉ là **reproducibility check** (xác nhận harness ổn định), KHÔNG đo được variance thật — variance thật chỉ xuất hiện ở FPGA (P3, có jitter tần số/DRAM refresh). → Đề xuất: Verilator có thể N_RUNS=1 (tiết kiệm 3× CI time) + giữ 1 run xác nhận; N_RUNS≥3 dành cho FPGA. CHƯA áp dụng — cần Loc quyết (đổi protocol phải ghi changes.md).
- Fix workflow: artifact upload scope về `${TAG}-*` (trước đó kéo theo mọi dir ci-* đã commit → phình artifact).
- docs/04: E1 tick B1/B3/B4/B5 ✅, B2 ⏳.
