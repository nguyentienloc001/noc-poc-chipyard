# PROGRESS — nguồn sự thật duy nhất về trạng thái project

> AI agent: ĐỌC FILE NÀY ĐẦU TIÊN sau CLAUDE.md. Cập nhật trước khi kết thúc mọi phiên làm việc. Không bao giờ để file này outdated — thà ghi "đang dở X" còn hơn ghi thiếu.

## Snapshot

```yaml
current_phase: P0
phase_status: in_progress        # not_started | planning | in_progress | blocked | done
last_updated: 2026-06-11
last_session: "P0 bước 3,4,5,7,8 XONG trong 1 phiên. Step 3: libgloss debug 3 tầng (multilib rv32e; install assert; bug upstream __boot_sync thiếu .balign → patch src/patches/, verify spike 3/3). Step 4: JDK21×sbt1.8.2 → image openjdk-17; E8 firtool → linux-x64 qua qemu binfmt bake vào image; sim RocketConfig PASS. Step 5: hello PASS (9.5s). Step 7: 3 lần chạy — lần 1 thiếu timeout_cycles, lần 2 lộ TSI-load treo ở wfi (benchmark bss lớn) → LOADMEM=1; lần 3 PASS, row đầu trong results.csv (52.6 cycles/load smoke). Step 8: sim speed ~4–5 kHz → 1 data point B1 full ≈ 3–4h. run_sim.sh đã default LOADMEM=1 + TIMEOUT_CYCLES=200M. Image: 20260611-a998101."
next_action: "P0 bước 6b — verify root-of-trust trên máy x86 (CẦN LOC có máy x86): docker pull locnguyen96/noc-poc-chipyard@sha256:5744085506b9d7dedff92fa89e786083586cccec14af6461c03e62da34190c14; clone repo này; cd src/docker && docker compose run --rm chipyard; trong container: clone chipyard + checkout 69eba860 + quy trình src/docker/README.md (build-setup skip-conda + p0-step3-manual.sh) rồi make CONFIG=RocketConfig trong sims/verilator + chạy hello → PASS là root-of-trust xác nhận. Sau đó: tick gates trong plan.md, viết report.md, đóng P0, viết plan.md + expectations.md P1 (input từ P0: link recipe benchmark actual.md 2026-06-11, LOADMEM=1 bắt buộc, sim 4–5 kHz → 1 point B1 ≈ 3–4h, sửa idx[] stack 128KB trong zeroload, benchmark infra phải theo CMake-flow chipyard tests hoặc standalone recipe)."
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
| P0 — Môi trường | `phases/P0-environment/` | in_progress (bước 1–5,7,8 ✅; còn 6 + report) | ✅ | ✅ | — |
| P1 — Baseline + benchmarks | `phases/P1-baseline/` | — | chưa viết | chưa viết | — |
| P2 — NoC sweep | `phases/P2-noc-sweep/` | — | chưa viết | chưa viết | — |
| P3 — VC707 | `phases/P3-vc707/` | — | chưa viết | chưa viết | — |
| P4 — Phân tích & viết | `phases/P4-analysis/` | — | chưa viết | chưa viết | — |

## Nhật ký phiên làm việc (mới nhất trên cùng)

| Ngày | Ai | Việc đã làm | Kết quả |
|---|---|---|---|
| 2026-06-11 | Claude Code | P0 bước 3,4,5,7,8: debug libgloss (multilib rv32e, install assert, bug upstream __boot_sync .balign → patch + verify spike 3/3); fix JDK21→17 + E8 firtool (x64 qua qemu binfmt, bake vào image); sim RocketConfig PASS; hello PASS (9.5s); step 7 ba lần (timeout_cycles → TSI-load treo wfi → LOADMEM=1) → row đầu results.csv; sim speed 4–5 kHz; cập nhật run_sim.sh/Dockerfile/compose/README/docs-04 | Còn bước 6 (cần Loc: Docker Hub token + máy x86) → report.md → đóng P0 |
| 2026-06-10 (3) | Claude (Cowork) + Loc | P0 bước 1–3: image build, versions audit, chipyard pin 69eba860, 3 vòng debug build-setup step 3 (RISCV/picolibc/CFLAGS scope), viết p0-step3-manual.sh, thêm cmake+RISCV vào docker files | Bàn giao cho Claude Code chạy tiếp từ next_action |
| 2026-06-10 (2) | Claude + Loc | Redesign Docker: apt-first, multi-arch, Docker Hub root-of-trust, build/push scripts, .env secrets, .gitignore; viết lại plan+expectations P0 (v2) | P0 sẵn sàng, chờ build đầu tiên trên M1 |
| 2026-06-10 | Claude + Loc | Survey, research plan, project structure, agent rules | Repo khởi tạo, P0 sẵn sàng bắt đầu |
