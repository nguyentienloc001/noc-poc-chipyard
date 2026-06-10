# NoC-PoC: Chứng minh thực nghiệm ưu thế của Network-on-Chip trên Chipyard

PoC nghiên cứu khoa học (tầm luận văn thạc sĩ): so sánh thực nghiệm **Constellation NoC** với **TileLink crossbar/bus** trong SoC RISC-V sinh bởi Chipyard, đo bằng benchmark C/C++ trên 2 mức: **Verilator simulation** và **FPGA VC707**.

## Luận điểm nghiên cứu

> Khi số core và mức độ tranh chấp (contention) tăng, interconnect dạng NoC cho **aggregate throughput cao hơn, latency ổn định hơn và scale tốt hơn** so với crossbar/bus, đổi lại chi phí tài nguyên (LUT/FF) cao hơn — và trade-off này có lợi từ ngưỡng ~4–8 core.

## Cấu trúc thư mục

```
.
├── CLAUDE.md                  # Rules cho Claude/AI agent (kèm agent workflow)
├── PROGRESS.md                # Trạng thái hiện tại — AI agent đọc để resume
├── phases/                    # Artifact mỗi phase: plan/expectations/actual/changes/report
│   ├── _template/             # Template 5 file cho phase mới
│   └── P0-environment/        # P0 đã khởi tạo
├── docs/
│   ├── 00-research-plan.md    # Plan tổng thể: phases, milestones, rủi ro
│   ├── 01-survey.md           # Survey nghiên cứu liên quan + citations
│   ├── 02-spec-soc-configs.md # Spec các cấu hình SoC (baseline vs NoC)
│   ├── 03-spec-benchmarks.md  # Spec benchmark C/C++ và metrics
│   ├── 04-spec-experiments.md # Ma trận thí nghiệm, quy trình đo
│   └── 05-vc707-port.md       # Kế hoạch port VC707 harness + rủi ro
├── src/
│   ├── benchmarks/            # Benchmark C/C++ bare-metal (rdcycle)
│   ├── chipyard-configs/      # Scala configs để copy vào chipyard
│   ├── docker/                # Môi trường build (Mac M1 + x86)
│   └── scripts/               # Build/run/parse automation
└── results/                   # Kết quả đo (CSV + raw logs)
```

## Quick start

0. **AI agent resume**: đọc `CLAUDE.md` → `PROGRESS.md` → làm theo `next_action`.
1. Đọc `docs/00-research-plan.md` để nắm tổng thể.
2. Setup môi trường: `src/docker/README.md`.
3. Build SoC config đầu tiên: `src/scripts/run_sim.sh Baseline4CoreConfig --build-only`.

## Trạng thái

- [x] Survey + plan
- [ ] Phase 0: Môi trường (Docker + Chipyard build)
- [ ] Phase 1: Baseline crossbar + benchmark suite (Verilator)
- [ ] Phase 2: Cấu hình NoC Constellation + sweep (Verilator)
- [ ] Phase 3: FPGA VC707
- [ ] Phase 4: Phân tích + viết luận văn
