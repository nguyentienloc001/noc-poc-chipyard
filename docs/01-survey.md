# 01 — Survey: NoC vs crossbar/bus, công cụ và khoảng trống nghiên cứu

## 1. Bối cảnh

Interconnect truyền thống trong SoC là shared bus hoặc crossbar. Bus nghẽn sớm khi số master tăng (1 transaction/lượt); crossbar cho phép song song nhưng diện tích tăng ~O(N²) và wire dài làm giảm Fmax khi scale. NoC (packet-switched, router + link) ra đời để giải quyết scalability: bandwidth tăng theo số link, wire ngắn và có pipeline, độ trễ dự đoán được.

Kết luận nhất quán từ các nghiên cứu gần đây:

- Crossbar và NoC đều vượt shared bus về bandwidth/latency; bus chỉ hợp hệ nhỏ.
- Crossbar tốn ít tài nguyên hơn NoC, đủ tốt cho pattern giao tiếp đơn giản và quy mô nhỏ (≤4 master) — đây là lý do nó là baseline mặc định của Chipyard.
- NoC thắng về scalability, aggregate bandwidth, predictable latency khi số node và contention tăng; trả giá bằng diện tích và zero-load latency (qua nhiều router hop).
- Hướng 2024–2025: hard NoC trên FPGA (Versal), kiến trúc lai (PCCNoC — packet connected circuit đạt throughput cao + latency thấp), chứng tỏ chủ đề so sánh interconnect vẫn active.

## 2. Công cụ: Chipyard + Constellation

**Constellation** (Zhao et al., UC Berkeley) là NoC RTL generator viết bằng Chisel, thiết kế để tích hợp vào SoC dị thể:

- Packet-switched, wormhole-routed, virtual networks, credit-based flow control.
- Topology tùy ý (mesh, ring, torus, irregular, hierarchical), kèm routing-table compiler có verifier đảm bảo deadlock-free.
- Protocol-independent transport layer: chở được TileLink và AXI-4 đúng chuẩn, không deadlock.
- **Drop-in vào Chipyard**: thay bất kỳ TileLink crossbar nào (System Bus, Memory Bus, Control Bus) bằng NoC — private interconnect cho một bus, hoặc shared global interconnect cho nhiều bus.
- Có sẵn framework traffic injection + đo throughput/latency (median, max) cho synthetic traffic.
- Paper đánh giá với SoC giả định 72 core RISC-V, 64 bank LLC, 8 DRAM channel trên 8×8 mesh.

Đây là lựa chọn duy nhất hợp lý cho project: cùng hệ sinh thái Chipyard, baseline (crossbar) và NoC sinh từ cùng codebase → so sánh công bằng.

## 3. Khoảng trống nghiên cứu (gap) mà PoC này nhắm vào

1. Paper Constellation đánh giá chủ yếu bằng **synthetic traffic ở mức RTL sim**; ít số liệu **application-level (code C/C++ thật)** so sánh trực tiếp NoC vs crossbar trong cùng một SoC.
2. Hầu hết so sánh NoC vs bus/crossbar là simulation-only; **xác nhận trên FPGA thật** (VC707) với cùng cấu hình là đóng góp thực nghiệm có giá trị.
3. Chưa có số liệu công bố về **điểm hòa vốn (break-even point)** — từ bao nhiêu core/mức contention nào thì NoC bắt đầu thắng crossbar trong Chipyard SoC — đây là câu hỏi chính của luận văn.

## 4. Metrics nên focus (NoC thể hiện tốt nhất)

Theo literature, NoC vượt trội ở các metric sau — đây là metrics chính của luận văn:

| Metric | Vì sao NoC thắng | Cách đo |
|---|---|---|
| **Aggregate throughput dưới contention** | Nhiều link song song vs 1 điểm tranh chấp | N core cùng chạy STREAM-like, tổng bandwidth |
| **Scalability** (perf vs số core) | Bandwidth tăng theo topology | Sweep 2→4→8 core, vẽ đường scale |
| **Latency dưới tải (loaded latency)** | Crossbar/bus nghẽn → latency tăng vọt sau saturation | Pointer-chase trên 1 core trong khi N-1 core bơm tải |
| **Saturation point** | NoC đẩy điểm bão hòa xa hơn | Tăng injection rate đến khi latency bùng nổ |

Metrics phụ (báo cáo như trade-off, dự kiến NoC **thua**): zero-load latency (1 core, không tải), tài nguyên FPGA (LUT/FF/BRAM), Fmax. Báo cáo cả hai chiều làm luận văn đáng tin.

## 5. Nguồn

- [Constellation: An Open-Source SoC-Capable NoC Generator (Zhao et al.)](https://par.nsf.gov/servlets/purl/10439921)
- [Chipyard docs — Constellation](https://chipyard.readthedocs.io/en/latest/Generators/Constellation.html)
- [Chipyard docs — SoCs with NoC-based Interconnects](https://chipyard.readthedocs.io/en/1.13.0/Customization/NoC-SoCs.html)
- [Constellation docs — Chipyard SoC Integration](https://constellation.readthedocs.io/en/latest/SoCIntegration/index.html)
- [Demystifying FPGA Hard NoC Performance (arXiv 2503.10861)](https://arxiv.org/html/2503.10861v1)
- [PCCNoC: Packet Connected Circuit as NoC (MDPI Micromachines 2023)](https://www.mdpi.com/2072-666X/14/3/501)
- [Chipyard docs — Prototyping Flow](https://chipyard.readthedocs.io/en/stable/Prototyping/index.html)
- [Chipyard issue #1195 — Support for Virtex VC707](https://github.com/ucb-bar/chipyard/issues/1195)
- [Thảo luận Rocket chip FPGA area (riscv hw-dev)](https://groups.google.com/a/groups.riscv.org/g/hw-dev/c/zZxy0iFzrvI/m/LVeFiK2vAQAJ)
- [VC707 Evaluation Board User Guide (UG885)](https://hwlab.fit.cvut.cz/_media/pripravky/fpga/vc707/ug885_vc707_eval_bd.pdf)

> TODO trước khi viết chương Related Work của luận văn: đọc full-text paper Constellation và PCCNoC, bổ sung 5–10 citation từ tham chiếu của chúng (OpenSMART, OpenPiton OpenSoC...).
