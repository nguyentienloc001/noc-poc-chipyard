# PROGRESS — nguồn sự thật duy nhất về trạng thái project

> AI agent: ĐỌC FILE NÀY ĐẦU TIÊN sau CLAUDE.md. Cập nhật trước khi kết thúc mọi phiên làm việc. Không bao giờ để file này outdated — thà ghi "đang dở X" còn hơn ghi thiếu.

## Snapshot

```yaml
current_phase: P1
phase_status: in_progress        # not_started | planning | in_progress | blocked | done
last_updated: 2026-06-11
last_session: "Audit review Codex (5/5 findings đúng, commit f84dc3d) + P1 bước 1-2 XONG: Makefile benchmark standalone (recipe P0, build B1+B3 pass trong container), docs/03+04+README+CLAUDE.md hết hướng dẫn sai, AGENTS.md → thin pointer, run_sim.sh harden (abs path + meta provenance đầy đủ + IMAGE_DIGEST warning), parse_results.py idempotent + summary.csv (median/spread/flag smoke) — verified trên dir smoke P0. changes.md: enforce>=3runs → flag. plan/expectations P1 normalize có dấu."
next_action: "P1 bước 4: sửa/viết benchmark sources trong src/benchmarks/src/ — (a) B1 zeroload_latency.c: chuyển idx[N_NODES] từ stack sang static (128KB > 24K stack htif.ld, xem P0 report); (b) viết B2 stream_bw.c (STREAM triad 1 core, buffer 2MB, từ spec docs/03); (c) review B3 contention_bw.c (đã compile pass nhưng là skeleton — kiểm tra logic barrier/sync.h); (d) viết B4 loaded_latency.c + B5 core2core.c theo docs/03. Sau đó bước 5: verify multi-hart startup (build B3 NCORES=2, chạy trên RocketConfig 1-core sẽ không đủ — cần đợi bước 6 build Baseline2CoreConfig, hoặc test sớm hành vi _start_secondary/__main của libgloss bằng binary nhỏ trên spike -p2). Build: make -C src/benchmarks all NCORES=<N>; chạy: run_sim.sh (LOADMEM=1 default)."
blockers: []
chipyard_pinned: {version: "1.13.0", commit: "69eba860a352343e4ac6b6df0f3638a79a86ec78"}
docker_image_pinned: {image: "locnguyen96/noc-poc-chipyard", tag: "20260611-a998101", digest: "sha256:5744085506b9d7dedff92fa89e786083586cccec14af6461c03e62da34190c14"}  # multi-arch amd64+arm64, pushed 2026-06-11
```

## Resume protocol (cho AI agent)

1. Đọc `CLAUDE.md` (rules) → `PROGRESS.md` (file này) → `phases/<current_phase>-*/plan.md` và `actual.md` (3–5 entry cuối).
2. Nếu `phase_status: blocked` → đọc blocker, xử lý blocker trước, không nhảy bước.
3. Làm tiếp từ `next_action`. Không bắt đầu việc ngoài plan của phase hiện tại; muốn đổi → ghi `changes.md` trước (xem CLAUDE.md mục Agent workflow).
4. Trong lúc làm: append vào `phases/<phase>/actual.md` mỗi khi có kết quả/lỗi đáng ghi.
5. Trước khi kết thúc phiên: cập nhật Snapshot ở trên (last_session, next_action, blockers, last_updated).

## Trạng thái môi trường (cho agent tiếp quản — cập nhật khi đổi)

- Máy đang làm: **Mac M1**, Docker Desktop. Image: `local/noc-poc-chipyard:20260611-a998101` (= `:latest`, arm64): openjdk-17 (KHÔNG 21 — sbt 1.8.2 không đọc classfile JDK21), cmake, firtool 1.75.0 linux-x64 chạy qua qemu binfmt (amd64 libs đã có trong image — E8 đã đóng).
- Vào container: `cd "src/docker" && docker compose run --rm chipyard` (compose set `RISCV=/work/riscv`, PATH có `/work/riscv/bin` (spike/spike-dasm/espresso), repo tại `/project`, chipyard tại `/work/chipyard` volume `chipyard-vol`, `$HOME` cache volume `home-vol`).
- Đã có trong `/work`: chipyard 1.13.0 @ `69eba860` (submodules init xong, libgloss ĐÃ patch `.balign __boot_sync` — xem `src/patches/`), spike + libfesvr + espresso + libgloss + DRAMSim2 + uart_tsi installed tại `/work/riscv`; sim `simulator-chipyard.harness-RocketConfig` đã build tại `sims/verilator`; `/work/smoke/` chứa hello/zeroload test binaries; `/work/firtool-x64/` (bản tải tay, image đã tự chứa nên không cần nữa).
- Build benchmark bare-metal: dùng link recipe trong actual.md 2026-06-11 (picolibc.specs + -B + htif.specs + htif_wrap.specs + -T htif.ld). KHÔNG set CFLAGS global (phá host build).
- Quy tắc khi chạy: mọi log tee vào `/project/results/raw/`, append `actual.md` mỗi kết quả/lỗi, cập nhật file này trước khi dừng.

## Trạng thái các phase

| Phase | Thư mục | Status | Plan | Expect | Report |
|---|---|---|---|---|---|
| P0 — Môi trường | `phases/P0-environment/` | **done** (2026-06-11) | ✅ | ✅ | ✅ |
| P1 — Baseline + benchmarks | `phases/P1-baseline/` | **in_progress** | ✅ | ✅ | — |
| P2 — NoC sweep | `phases/P2-noc-sweep/` | — | chưa viết | chưa viết | — |
| P3 — VC707 | `phases/P3-vc707/` | — | chưa viết | chưa viết | — |
| P4 — Phân tích & viết | `phases/P4-analysis/` | — | chưa viết | chưa viết | — |

## Nhật ký phiên làm việc (mới nhất trên cùng)

| Ngày | Ai | Việc đã làm | Kết quả |
|---|---|---|---|
| 2026-06-11 (3) | Codex | Review toàn bộ repo: docs/spec, phase artifacts, Docker, CI, scripts, benchmark, Scala configs; chạy syntax checks nhẹ; tạo P1 plan/expectations/actual/changes | P1 artifacts đã có. Next: sửa docs/build infra + harden `run_sim.sh`/`parse_results.py` trước khi đo |
| 2026-06-11 (2) | Loc + Claude Code | P0 bước 6 + đóng phase: push multi-arch lên Docker Hub (digest pinned docs/00 §6); Loc đề xuất GitHub CI thay máy x86 → repo lên GitHub + workflow p0-x86-verify → CI x86 PASS 25m15s; arm64 verify từ image pull PASS; gate 6/6 tick; report.md viết xong | **P0 DONE.** Next: viết plan + expectations P1 |
| 2026-06-11 | Claude Code | P0 bước 3,4,5,7,8: debug libgloss (multilib rv32e, install assert, bug upstream __boot_sync .balign → patch + verify spike 3/3); fix JDK21→17 + E8 firtool (x64 qua qemu binfmt, bake vào image); sim RocketConfig PASS; hello PASS (9.5s); step 7 ba lần (timeout_cycles → TSI-load treo wfi → LOADMEM=1) → row đầu results.csv; sim speed 4–5 kHz; cập nhật run_sim.sh/Dockerfile/compose/README/docs-04 | Bước 6 bàn giao sang phiên (2) |
| 2026-06-10 (3) | Claude (Cowork) + Loc | P0 bước 1–3: image build, versions audit, chipyard pin 69eba860, 3 vòng debug build-setup step 3 (RISCV/picolibc/CFLAGS scope), viết p0-step3-manual.sh, thêm cmake+RISCV vào docker files | Bàn giao cho Claude Code chạy tiếp từ next_action |
| 2026-06-10 (2) | Claude + Loc | Redesign Docker: apt-first, multi-arch, Docker Hub root-of-trust, build/push scripts, .env secrets, .gitignore; viết lại plan+expectations P0 (v2) | P0 sẵn sàng, chờ build đầu tiên trên M1 |
| 2026-06-10 | Claude + Loc | Survey, research plan, project structure, agent rules | Repo khởi tạo, P0 sẵn sàng bắt đầu |
