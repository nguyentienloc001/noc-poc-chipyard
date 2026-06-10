# P0 — Môi trường: Expectations

> Bản v2 (2026-06-10), viết lại theo chiến lược Docker mới TRƯỚC khi chạy bất kỳ build nào (phase chưa bắt đầu — xem changes.md). KHÔNG sửa sau khi có số liệu thật.

## Dự đoán

| # | Dự đoán | Định lượng | Căn cứ |
|---|---|---|---|
| E1 | Image apt-first build nhanh và nhẹ hơn hẳn conda flow | build 15–30 phút; size 1.5–2GB (vs conda ~10–20GB) | jdk-headless ~300MB, riscv-gcc ~300MB, verilator ~100MB + base |
| E2 | Build Verilator sim RocketConfig trong container native arm64 nhanh hơn flow Rosetta cũ | 30–60 phút trên M1 native | không còn emulation overhead |
| E3 | Sim speed RocketConfig | ~1–10 kHz | con số phổ biến cho Verilator SoC sim |
| E4 | hello.riscv pass không cần sửa code Chipyard | — | RocketConfig là config được CI test |
| E5 | Benchmark build qua tests/ infra cần chỉnh tay Makefile của chipyard/tests | 1–2 giờ debug | tests/Makefile không tự nhận file mới |
| E6 | crt0 của tests/ park các hart phụ | cần workaround ở P1 | hành vi phổ biến của bare-metal crt0 |
| E7 | apt verilator 5.020 (Ubuntu 24.04) hoạt động được với Chipyard 1.13.0 dù pin là 5.022 | không lỗi build/run | 5.020 vs 5.022 là patch-level gap; rủi ro thấp nhưng phải verify |
| E8 | firtool KHÔNG có prebuilt aarch64 → arm64 image thiếu firtool, cần fallback | warning ở build log arm64 | CIRCT releases lịch sử chỉ có linux-x64 |
| E9 | Chipyard setup không-conda khả thi nhưng tốn công thử nghiệm flags | 1–3 giờ thử | build-setup.sh thiết kế quanh conda; cộng đồng đã làm được với system tools |
| E10 | sbt fetch dependencies lần đầu | ~20–40 phút, vài GB cache | cold Ivy/coursier cache |

## Nếu dự đoán sai thì có nghĩa là gì

- E7 sai (verilator 5.020 lỗi): build verilator 5.022 từ source trong Dockerfile — ngoại lệ apt-first thứ 3, ghi lý do vào src/docker/README.md + changes.md.
- E8 sai theo hướng tốt (có aarch64 binary): xóa fallback path, đơn giản hóa Dockerfile.
- E9 sai (không-conda bế tắc hoàn toàn): image variant có conda; mục tiêu "≤2GB" thất bại nhưng root-of-trust + multi-arch giữ nguyên — ghi changes.md, điều chỉnh nguyên tắc 4 trong docker/README.md.
- E1 sai (image >3GB): tìm layer phình to bằng `docker history`, cân nhắc tách image dev/CI.
- E3 sai (<1 kHz): rút tham số benchmark ở P1 (sửa spec 03 qua changes.md của P1).
