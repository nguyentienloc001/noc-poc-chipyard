# P1 — Baseline + benchmarks: Plan

> Viet truoc khi bat dau do baseline. Input chinh: `phases/P0-environment/report.md`, `docs/02`, `docs/03`, `docs/04`.

## Muc tieu

Hoan thien baseline crossbar 2/4/8 core va benchmark suite B1-B5 sao cho moi data point Verilator co raw log, provenance, >=3 runs, median va variance check. P1 chua do NoC; output la baseline sach de P2 so sanh cong bang.

## Input tu phase truoc

- Docker image root-of-trust da pin: `locnguyen96/noc-poc-chipyard@sha256:5744085506b9d7dedff92fa89e786083586cccec14af6461c03e62da34190c14`.
- Chipyard 1.13.0 commit `69eba860a352343e4ac6b6df0f3638a79a86ec78`.
- Link recipe bare-metal chot o P0: `-O2 --specs=picolibc.specs -B$RISCV/riscv64-unknown-elf/lib --specs=htif.specs --specs=htif_wrap.specs -T$RISCV/riscv64-unknown-elf/lib/htif.ld`.
- P0 smoke da chung minh `LOADMEM=1` va `TIMEOUT_CYCLES` la bat buoc cho benchmark co `.bss` lon.
- Sim speed M1 tham chieu: ~4-5 kHz; B1 full-spec uoc tinh 3-4h/run tren M1.
- Can sua `idx[N_NODES]` trong `zeroload_latency.c` truoc khi do that.
- Khong dung lai huong `chipyard/tests/Makefile`; Chipyard 1.13 tests dung CMake va `htif_nano.specs` khong hop image nay.

## Cac buoc

| # | Buoc | Output | Uoc luong |
|---|---|---|---|
| 1 | Sua spec/docs cho P1: build benchmark standalone, khong `tests/Makefile`; cap nhat README/docs/03/docs/04 neu lech P0 | docs khong con huong dan sai | 1-2h |
| 2 | Harden automation truoc khi do: `run_sim.sh` resolve binary path tuyet doi, ghi them image digest/project commit/binary sha256/N_RUNS/LOADMEM/TIMEOUT/seed; `parse_results.py` idempotent, enforce >=3 runs, median/min/max/variance flag | script khong lam hong provenance | 0.5-1 ngay |
| 3 | Hoan thien benchmark build infra standalone trong `src/benchmarks/`: build B1-B5 bang recipe P0, output `.riscv`, param/seed qua `-D`, build log vao `results/raw/` | build duoc B1-B5 khong sua Chipyard source | 0.5-1 ngay |
| 4 | Sua/hoan thien benchmark: B1 static `idx`; B2 stream_bw; B3 validate multi-hart; B4 loaded_latency; B5 core2core | source B1-B5 pass compile | 1-3 ngay |
| 5 | Giai quyet startup multi-hart: verify libgloss/crt0 co dua hart phu vao `main` hay khong; neu khong, them startup/link path rieng co ghi ro trong docs/03 | B3-B5 khong deadlock, moi hart that su tham gia | 0.5-2 ngay |
| 6 | Copy/install `NoCResearchConfigs.scala` vao Chipyard va build smoke `Baseline2CoreConfig`, `Baseline4CoreConfig`, `Baseline8CoreConfig`; voi 8-core small, build them libgloss `rv64imac/lp64` neu can | Verilator sim baseline build pass | 0.5-1 ngay |
| 7 | Smoke B1-B5 tren `Baseline2CoreConfig` voi param giam, 1 run/bench, parse CSV vao raw test dir rieng | pipeline moi pass nhanh truoc khi do dai | 0.5-1 ngay |
| 8 | Do baseline chinh thuc Verilator: Baseline2/4/8 x B1-B5, `N_RUNS>=3`, ghi raw log, parse, tick docs/04 | `results/csv/results.csv` co baseline data point hop le | nhieu ngay tuy CI/M1 |
| 9 | Viet `report.md` P1: median, variance, loi/bo qua co ly do; input cho P2 NoC | P1 dong duoc phase gate | 0.5 ngay |

## Dieu kien hoan thanh (phase gate)

- [ ] `plan.md` va `expectations.md` da viet truoc khi co so lieu P1.
- [ ] Benchmark build standalone dung recipe P0; khong con phu thuoc `chipyard/tests/Makefile`.
- [ ] B1-B5 compile va smoke pass tren `Baseline2CoreConfig`.
- [ ] `Baseline2CoreConfig`, `Baseline4CoreConfig`, `Baseline8CoreConfig` elaborate/build Verilator pass.
- [ ] Moi data point baseline chinh thuc co >=3 runs, median, min/max, variance check; variance >5% thi co entry dieu tra trong `actual.md`/`changes.md`.
- [ ] Raw logs nam trong `results/raw/<date>-<config>-<bench>/`, co `meta.txt` du provenance: config, chipyard commit, project commit, docker image digest, benchmark params, seed, binary sha256.
- [ ] `docs/04-spec-experiments.md` duoc tick/cap nhat sau moi experiment.
- [ ] P1 `report.md` viet xong, neu bo qua data point nao thi ly do nam trong `changes.md`.

## Rui ro cua phase nay

| Rui ro | Du phong |
|---|---|
| Verilator qua cham cho full matrix tren M1 | Chay smoke local, day full runs sang GitHub Actions/x86 hoac chia nho theo benchmark; khong giam param chinh thuc neu chua ghi `changes.md` |
| Multi-hart benchmark deadlock do crt0/libgloss park hart phu | Verify bang smoke B3 nho; neu can viet startup rieng hoac patch link flow rieng, cap nhat docs/03 truoc |
| `Baseline8CoreConfig` small can `rv64imac/lp64` libgloss | Build them libgloss multilib variant va ghi recipe vao docker README/P1 actual |
| Parser append duplicate lam hong CSV | Them idempotency hoac tach raw rows/summary rows truoc khi parse P1 |
| NoC claim bi thien vi vi baseline chua toi uu | Giu baseline la Chipyard default crossbar, cung cache/core/memory; report ca ket qua bat loi cho NoC ve sau |
