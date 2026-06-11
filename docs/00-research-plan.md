# 00 — Research Plan

## 1. Câu hỏi nghiên cứu

**RQ1.** Trong SoC RISC-V multi-core sinh bởi Chipyard, NoC (Constellation) vượt crossbar TileLink ở metric nào, từ quy mô/mức contention nào (break-even point)?

**RQ2.** Trade-off chi phí (tài nguyên FPGA, Fmax, zero-load latency) của NoC so với crossbar là bao nhiêu, và có đáng không tại các quy mô đó?

**RQ3.** Kết quả Verilator simulation có nhất quán với đo đạc trên FPGA VC707 không (cross-validation)?

## 2. Phương pháp

So sánh **cặp đối chứng**: các SoC config chỉ khác interconnect (System Bus + Memory Bus: crossbar vs Constellation NoC), giữ nguyên core, cache, memory. Đo bằng benchmark C/C++ bare-metal (rdcycle), bổ sung synthetic traffic bằng framework đo có sẵn của Constellation. Chạy trên Verilator (toàn bộ ma trận) và VC707 (tập con để xác nhận).

Lý do chọn baseline crossbar (không phải shared bus): crossbar là mặc định của Chipyard và là đối thủ mạnh nhất ở quy mô nhỏ — thắng được crossbar mới có ý nghĩa. Shared bus có thể thêm như điểm tham chiếu phụ nếu còn thời gian.

## 3. Quy mô — ước lượng capacity

### VC707 (Virtex-7 XC7VX485T)

Tài nguyên: ~303.600 LUT, ~607.200 FF, 1.030 BRAM36, 2.800 DSP, 1GB DDR3.

Ước lượng (cần xác nhận lại bằng synthesis thực tế ở Phase 3):

| Thành phần | LUT ước lượng | Nguồn |
|---|---|---|
| Rocket tile nhỏ nhất (no FPU) | ~11K | thảo luận riscv hw-dev |
| Rocket tile đầy đủ (FPU, L1 16K+16K) | ~30–40K | ngoại suy, cần đo |
| Uncore (DDR3 MIG, UART, L2 512K) | ~30–50K | ngoại suy, cần đo |
| Router Constellation/node | ~2–5K | ngoại suy từ paper, cần đo |

→ **Khả thi trên VC707**: tối đa ~4 core Rocket đầy đủ + NoC, hoặc ~8 core nhỏ (no FPU). Kế hoạch: **8 core cấu hình nhỏ** làm điểm đo lớn nhất trên FPGA; nếu không fit, lùi về 4+4 hoặc giảm L1. Mục tiêu Fmax: 50–100 MHz (chuẩn cho SoC Chipyard trên 7-series).

### Verilator

Tốc độ ~1–10 kHz cho SoC multi-core → benchmark phải ngắn (10⁵–10⁷ cycle đo). 8 core mesh 3×3 chạy được nhưng build + run tính bằng giờ. Toàn bộ ma trận thí nghiệm chạy Verilator; FPGA chỉ chạy tập con.

### Ma trận quy mô

- Số core: **2, 4, 8** (8 = điểm dự kiến NoC thắng rõ).
- Topology NoC: **mesh 2×2, mesh 3×3** (chính), ring (phụ, nếu còn thời gian).

## 4. Phases & milestones

| Phase | Nội dung | Thời lượng | Deliverable / điều kiện hoàn thành |
|---|---|---|---|
| **P0 — Môi trường** | Docker (M1 + x86), clone & build Chipyard, chạy được `RocketConfig` hello-world trên Verilator ở cả 2 máy | 2 tuần | Sim chạy pass; pin Chipyard version + commit hash vào mục 6 |
| **P1 — Baseline + benchmarks** | Viết 5 benchmark (spec 03), config Baseline 2/4/8 core, đo full trên Verilator | 3 tuần | CSV kết quả baseline; benchmark có kết quả ổn định (variance <5%) |
| **P2 — NoC sweep** | Config Constellation (spec 02), đo cùng benchmark, thêm synthetic traffic Constellation; phân tích sơ bộ break-even | 4 tuần | CSV NoC + biểu đồ so sánh; trả lời sơ bộ RQ1 |
| **P3 — VC707** | Port harness VC707 (doc 05), synthesis lấy LUT/Fmax, chạy tập con benchmark trên board | 6 tuần | Bitstream boot được; bảng tài nguyên; CSV FPGA; trả lời RQ2, RQ3 |
| **P4 — Phân tích & viết** | Thống kê, biểu đồ cuối, viết chương thực nghiệm luận văn | 4 tuần | Chương Evaluation hoàn chỉnh |

Tổng: ~19 tuần. P3 là rủi ro lớn nhất (xem mục 5) — bắt đầu khảo sát harness VC707 song song từ cuối P1.

## 5. Rủi ro & phương án dự phòng

| Rủi ro | Xác suất | Dự phòng |
|---|---|---|
| VC707 không có harness chính thức trong Chipyard (chỉ VCU118/Arty) | **Chắc chắn** — phải tự port | Đã có VC707Shell trong fpga-shells + port cộng đồng (bare-metal). Dự phòng: dùng VCU118 flow làm mẫu; nếu bế tắc, kết quả FPGA giới hạn ở synthesis report (LUT/Fmax) — vẫn trả lời được RQ2 |
| 8 core không fit VC707 | Trung bình | Giảm xuống core nhỏ (no FPU), giảm L1/L2, hoặc lấy 4 core làm điểm FPGA lớn nhất, 8 core chỉ trên Verilator |
| Docker apt-first lệch version so với chuẩn Chipyard (verilator 5.020 vs 5.022, firtool thiếu aarch64, flow không-conda chưa verify) | Trung bình | Xem expectations E7–E9 của P0; fallback theo từng nấc: build tool lẻ từ source → image variant có conda. Root-of-trust + multi-arch giữ nguyên trong mọi trường hợp |
| Verilator quá chậm cho 8 core | Trung bình | Rút ngắn benchmark, đo bằng số cycle cố định; cân nhắc FireSim nếu có FPGA cloud (ngoài scope chính) |
| NoC không thắng ở 8 core | Thấp | Vẫn là kết quả khoa học hợp lệ: báo cáo break-even nằm ngoài 8 core, phân tích nguyên nhân |

## 6. Môi trường (pin sau P0)

- **Docker image (root of trust)**: `locnguyen96/noc-poc-chipyard:20260611-a998101` (= `:latest` tại thời điểm pin), **digest manifest-list `sha256:5744085506b9d7dedff92fa89e786083586cccec14af6461c03e62da34190c14`** (multi-arch: linux/amd64 `sha256:a78aafb6...`, linux/arm64 `sha256:60720a5b...`; pushed 2026-06-11, P0 bước 6). Mọi số liệu Verilator phải chạy từ image này: `docker pull locnguyen96/noc-poc-chipyard@sha256:5744085506b9d7dedff92fa89e786083586cccec14af6461c03e62da34190c14`
- Chipyard version: `1.13.0`, commit `69eba860a352343e4ac6b6df0f3638a79a86ec78` (pinned 2026-06-10, P0 bước 3)
- Constellation: theo submodule của Chipyard
- Verilator: `5.020` từ apt trong image (chuẩn Chipyard 1.13.0 pin 5.022 — E7 đã verify ở P0 bước 4–5: verilate + sim RocketConfig pass)
- Toolchain: `gcc-riscv64-unknown-elf 13.2.0` + `picolibc 1.8.6` từ apt trong image (khớp gcc 13.2 chuẩn CY; picolibc thay newlib — link recipe trong P0 actual.md 2026-06-11)
- JDK: `openjdk-17` (KHÔNG dùng 21 — sbt 1.8.2 của chipyard không đọc classfile JDK21, P0 bước 4)
- firtool: `1.75.0` (khớp `conda-reqs/circt.json` của Chipyard 1.13.0), prebuilt linux-x64 từ CIRCT releases — trên arm64 chạy qua qemu binfmt với amd64 libs trong image (E8 đã đóng, P0 bước 4; binary identical 2 arch → Verilog reproducible)
- Vivado: `2023.1+` trên máy x86 Linux, ngoài Docker (TODO: pin version)

## 7. Tiêu chí thành công của PoC

1. Có số liệu đo thực tế (không simulation giấy) cho ≥ 2 quy mô core × 2 interconnect × ≥ 4 benchmark.
2. Xác định được break-even point hoặc chứng minh nó nằm ngoài phạm vi đo.
3. Ít nhất 1 cấu hình NoC và 1 baseline chạy được trên VC707 thật (hoặc tối thiểu: synthesis report đầy đủ).
4. Kết quả Verilator vs FPGA sai khác có giải thích được.
