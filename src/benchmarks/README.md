# Benchmarks

Bare-metal C, đo bằng `rdcycle`. Spec đầy đủ: `docs/03-spec-benchmarks.md`.

| File | Bench | Trạng thái |
|---|---|---|
| `src/zeroload_latency.c` | B1 — pointer-chase latency | Skeleton — cần test trên Verilator |
| `src/stream_bw.c` | B2 — single-core STREAM | TODO (P1) — rút gọn từ B3 với NCORES=1 |
| `src/contention_bw.c` | B3 — aggregate BW under contention | Skeleton — cần test |
| `src/loaded_latency.c` | B4 — latency dưới tải nền | TODO (P1) — ghép B1 (core 0) + B3 (core 1..N-1) |
| `src/core2core.c` | B5 — ping-pong NxN | TODO (P1) |

Build: dựa vào hạ tầng `chipyard/tests/` (crt0 + HTIF printf cho multi-hart). Xem `Makefile` target `install`. Lưu ý: kiểm tra cách `tests/` của version Chipyard đã pin xử lý hart != 0 (một số version park các hart phụ trong crt0 — khi đó cần sửa crt0 hoặc dùng cách riêng để release các hart).
