# 05 — Kế hoạch port VC707

## 1. Hiện trạng (theo survey 06/2026 — xác nhận lại khi bắt đầu P3)

- Chipyard chính thức chỉ hỗ trợ harness cho **VCU118** và **Arty A7** trong prototyping flow.
- `fpga-shells` (submodule SiFive) **có sẵn `VC707Shell.scala`** với overlay: DDR3 MIG, UART, JTAG, SPI/SD.
- Có port cộng đồng chạy bare-metal trên VC707 (thread Google Groups chipyard, issue #1195) — emulation flow boot bare-metal OK, chưa có Linux. → Bare-metal là đủ cho benchmark của ta.

## 2. Việc phải làm

1. Tạo `fpga/src/main/scala/vc707/` trong chipyard (mirror cấu trúc `vcu118/`): `Harness.scala` (VC707FPGATestHarness), `HarnessBinders.scala`, `IOBinders.scala`, `Configs.scala` (clock 50MHz khởi điểm, DDR3 1GB).
2. Map overlay từ VC707Shell: DDR3 (MIG 7-series), UART (console + xuất kết quả benchmark), JTAG (nạp/debug qua BScan), SD/SPI (nạp binary nếu cần, hoặc dùng TSI qua FTDI nếu port được).
3. Cách nạp + chạy benchmark: phương án chính là **SD card boot** (như VCU118), dự phòng JTAG + GDB load.
4. Build flow: `make SUB_PROJECT=vc707 CONFIG=<Config> bitstream` trên máy x86 có Vivado (VC707 = Virtex-7, được hỗ trợ tới Vivado 2024.x dòng standard edition — cần license vì XC7VX485T không thuộc WebPACK ⚠).
5. Đọc timing/utilization report sau `route_design` → bảng cho RQ2.

## 3. Trình tự kiểm chứng (incremental)

1. `TinyRocketConfig` 1 core — bitstream + LED/UART hello → xác nhận shell, clock, DDR calibration.
2. `Baseline4CoreConfig` — boot + chạy B1.
3. NoC config — boot + full tập F.

## 4. Rủi ro riêng của phase này

| Rủi ro | Dự phòng |
|---|---|
| Vivado license cho XC7VX485T | Xin license trường/lab; hoặc dùng synthesis-only report từ bản eval |
| DDR3 MIG calibration fail | Hạ clock; dùng config MIG mẫu từ ví dụ fpga-shells/freedom |
| Harness build lỗi do API Chipyard đổi | Pin Chipyard version từ P0, đối chiếu code vcu118 cùng version |
| 8-core không fit / timing fail | Giảm core nhỏ, hạ clock 25MHz, hoặc dừng ở 4 core trên FPGA |

## 5. Quy ước code

- Code port để trong chipyard fork riêng, branch `vc707-harness`; mọi file mới có header `// NoC-PoC: VC707 port`.
- Mỗi patch ngoài thư mục `fpga/` (nếu buộc phải sửa) ghi lại tại đây kèm lý do.

## 6. Patch log

| Ngày | File | Lý do |
|---|---|---|
| — | — | — |
