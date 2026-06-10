# P0 — Môi trường: Changes (deviation log)

> Ghi TRƯỚC khi thực hiện thay đổi so với plan.md/expectations.md.

| Ngày | Thay đổi | Lý do | Ảnh hưởng (plan/expect/phase sau) |
|---|---|---|---|
| 2026-06-10 | Đổi chiến lược Docker: (1) image là **root of trust** cho toàn project, push lên Docker Hub, dùng lại được ở GitHub CI; (2) **apt-first** cho RISC-V tools (gcc-riscv64-unknown-elf, verilator...) thay vì conda/build-from-source — chỉ build từ source khi không có gói; (3) multi-arch (arm64 + amd64) chọn được lúc build; (4) thêm `build.sh`/`push.sh`, secrets chỉ qua env var; (5) tối ưu image nhẹ | Yêu cầu của Loc trước khi bắt đầu P0: reproducibility + dùng được nhiều nơi (CI), tránh conda nặng và chậm trên M1 | Viết lại plan.md + expectations.md của P0 (phase chưa bắt đầu, chưa có số liệu thật nên được phép sửa trực tiếp — entry này là bản ghi). Rủi ro mới: apt verilator có thể quá cũ so với yêu cầu Chipyard, firtool có thể thiếu binary arm64, Chipyard flow không-conda chưa được verify — đưa vào expectations E7–E9 |
