# 02 — Spec: Cấu hình SoC

## 1. Nguyên tắc

Mỗi cặp config (Baseline vs NoC) **chỉ khác interconnect**. Mọi tham số khác giữ nguyên:

- Core: Rocket, RV64GC (cấu hình "big") hoặc RV64IMAC no-FPU (cấu hình "small" cho 8 core FPGA).
- L1: 16KB I$ + 16KB D$ / core. L2 (InclusiveCache): 512KB shared.
- Memory: 1 channel DDR (FPGA: MIG DDR3 của VC707; Verilator: SimDRAM).

## 2. Danh sách config

File: `chipyard-configs/NoCResearchConfigs.scala` (copy vào `chipyard/generators/chipyard/src/main/scala/config/`).

| Config name | Cores | Interconnect | Mục đích |
|---|---|---|---|
| `Baseline2CoreConfig` | 2× Rocket big | Crossbar (mặc định) | Điểm gốc |
| `Baseline4CoreConfig` | 4× Rocket big | Crossbar | Điểm so sánh chính |
| `Baseline8CoreConfig` | 8× Rocket small | Crossbar | Điểm scale lớn nhất |
| `NoCMesh2x2_4CoreConfig` | 4× Rocket big | Constellation mesh 2×2 trên SBus | Đối chứng của Baseline4 |
| `NoCMesh3x3_8CoreConfig` | 8× Rocket small | Constellation mesh 3×3 trên SBus | Đối chứng của Baseline8 |
| `NoCRing8CoreConfig` | 8× Rocket small | Constellation ring | Phụ — so topology |

Quy ước: NoC gắn vào **System Bus** (SBus) bằng `constellation.soc.WithSbusNoC` (private interconnect). Nếu kết quả cho thấy bottleneck nằm ở Memory Bus, thêm biến thể `WithMbusNoC` — quyết định sau P2.

## 3. Khung config (sườn, hoàn thiện ở P1/P2)

```scala
// NoC config: thay SBus crossbar bằng Constellation mesh
class NoCMesh2x2_4CoreConfig extends Config(
  new constellation.soc.WithSbusNoC(constellation.protocol.TLNoCParams(
    constellation.protocol.DiplomaticNetworkNodeMapping(
      inNodeMapping  = ListMap("Core 0" -> 0, "Core 1" -> 1, "Core 2" -> 2, "Core 3" -> 3),
      outNodeMapping = ListMap("system[0]" -> 0, "pbus" -> 1) // L2 banks, peripherals — map chính xác ở P2
    ),
    NoCParams(
      topology        = Mesh2D(2, 2),
      channelParamGen = (a, b) => UserChannelParams(Seq.fill(8) { UserVirtualChannelParams(4) }),
      routingRelation = BlockingVirtualSubnetworksRouting(Mesh2DDimensionOrderedRouting(), 5, 1)
    )
  )) ++
  new freechips.rocketchip.subsystem.WithNBigCores(4) ++
  new chipyard.config.AbstractConfig
)
```

> Số virtual channel, node mapping phải khớp số node TileLink thật — Constellation sẽ báo lỗi elaborate nếu sai. Tham khảo `NoCConfigs.scala` có sẵn trong Chipyard (`MultiNoCConfig`, `SbusRingNoCConfig`) làm mẫu.

## 4. Tham số NoC cố định (để so sánh công bằng giữa các topology)

- Flit width: bằng beat width của SBus (64-bit mặc định — xác nhận ở P2).
- VC per channel: 4; số virtual network: theo yêu cầu TileLink (5 channel A–E).
- Routing: dimension-ordered (mesh), deadlock-free theo routing verifier của Constellation.
- Router: pipeline mặc định của Constellation (không bật tối ưu đặc biệt — đo cấu hình "out-of-the-box").

## 5. Điều kiện hoàn thành spec này

- [ ] Mỗi config elaborate thành công (Verilator build pass).
- [ ] `hello.riscv` chạy pass trên mọi config.
- [ ] Node mapping được vẽ sơ đồ (core nào → node nào) trong file này trước khi đo.
