# Benchmarks

Bare-metal C, đo bằng `rdcycle`. Spec đầy đủ: `docs/03-spec-benchmarks.md`.

| File | Bench | Trạng thái |
|---|---|---|
| `src/zeroload_latency.c` | B1 — pointer-chase latency | Smoke pass (P0 bước 7). TODO P1: chuyển `idx[]` khỏi stack (128KB > 24K stack htif.ld) |
| `src/stream_bw.c` | B2 — single-core STREAM | TODO (P1) — rút gọn từ B3 với NCORES=1 |
| `src/contention_bw.c` | B3 — aggregate BW under contention | Skeleton — cần test |
| `src/loaded_latency.c` | B4 — latency dưới tải nền | TODO (P1) — ghép B1 (core 0) + B3 (core 1..N-1) |
| `src/core2core.c` | B5 — ping-pong NxN | TODO (P1) |

## Build (standalone — KHÔNG dùng chipyard/tests)

Chipyard 1.13 `tests/` dùng CMake + `htif_nano.specs` (cần newlib-nano, image này
dùng picolibc) → build trực tiếp bằng libgloss-htif đã install vào `$RISCV` ở P0:

```bash
# trong container
make -C /project/src/benchmarks all NCORES=4        # → build/*.riscv
make -C /project/src/benchmarks all DEFS='-DFOOTPRINT=2097152 -DN_LOADS=20000'  # smoke
```

Link recipe (pin tại `phases/P0-environment/report.md`, lý do từng flag trong
`phases/P0-environment/actual.md` 2026-06-11):
`-O2 --specs=picolibc.specs -B$RISCV/riscv64-unknown-elf/lib --specs=htif.specs --specs=htif_wrap.specs -T$RISCV/riscv64-unknown-elf/lib/htif.ld`

## Multi-hart (B3–B5)

crt0 của libgloss-htif đưa hart 0 vào `main`, các hart phụ chờ barrier
`__boot_sync` rồi vào `__main` (xem `misc/crtmain.S`). Hành vi chính xác với
NCORES>1 **chưa verify thực nghiệm** — đó là P1 bước 5 (rủi ro cao nhất của
B3–B5, xem `phases/P1-baseline/expectations.md` E7). KHÔNG đo multi-core trước
khi bước 5 xong.

Lưu ý chạy sim: benchmark có `.bss` lớn (arena MB) **bắt buộc** `LOADMEM=1`
(run_sim.sh đã default) — không có nó TSI serial load treo ở `wfi` (P0 bước 7).
