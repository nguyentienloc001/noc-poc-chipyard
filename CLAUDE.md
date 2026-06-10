# CLAUDE.md — Rules cho project NoC-PoC

## Bối cảnh

Project PoC luận văn thạc sĩ: chứng minh thực nghiệm NoC (Constellation) tối ưu hơn crossbar/bus trong SoC Chipyard. Đo bằng benchmark C/C++ trên Verilator và FPGA VC707. Người dùng: Loc.

## Ngôn ngữ & văn phong

- Tài liệu: **tiếng Việt, giữ nguyên thuật ngữ kỹ thuật tiếng Anh** (latency, throughput, crossbar, flit...). Không dịch thuật ngữ.
- Code comment: tiếng Anh.
- Trả lời ngắn gọn, đi thẳng vào vấn đề.

## Nguyên tắc khoa học (QUAN TRỌNG NHẤT)

1. **Không bịa số liệu.** Mọi con số performance phải đến từ lần chạy thực tế, có log trong `results/raw/`. Số ước lượng phải ghi rõ "ước lượng" kèm nguồn.
2. **Mọi thí nghiệm phải tái lập được**: ghi rõ config name, commit hash của chipyard, tham số benchmark, seed.
3. **So sánh công bằng**: baseline và NoC config chỉ khác nhau ở interconnect — cùng số core, cùng cache, cùng tần số (FPGA) hoặc cùng đơn vị cycle (Verilator).
4. Mỗi data point chạy **tối thiểu 3 lần**, báo cáo median; nếu variance > 5% phải điều tra.
5. Kết quả bất lợi cho NoC (vd. zero-load latency cao hơn crossbar) **vẫn phải báo cáo** — luận văn cần trung thực, trade-off là một phần của kết luận.

## Quy ước kỹ thuật

- Chipyard version: pin tại `docs/00-research-plan.md` (mục Môi trường). Không tự ý nâng version.
- Scala configs đặt trong `src/chipyard-configs/NoCResearchConfigs.scala`, naming: `Baseline<N>CoreConfig`, `NoCMesh<RxC><N>CoreConfig`, `NoCRing<N>CoreConfig`.
- Benchmark: C/C++ **bare-metal**, đo bằng `rdcycle`/`rdinstret` (CSR), build bằng `riscv64-unknown-elf-gcc` với `-O2`, link theo `src/benchmarks/common/`.
- Kết quả: CSV theo schema trong `docs/04-spec-experiments.md`, raw log giữ nguyên trong `results/raw/<date>-<config>-<bench>/`.
- Script shell: bash, `set -euo pipefail`.

## Ràng buộc môi trường (không được quên)

- **Docker image là root of trust** cho toàn project: build bằng `src/docker/build.sh`, push bằng `push.sh` lên Docker Hub, dùng chung cho M1/x86/CI. Image + digest pin tại `docs/00-research-plan.md` mục 6 — mọi kết quả đo phải chạy từ image đã pin.
- Dockerfile theo nguyên tắc **apt-first**: tool lấy từ apt khi có gói; prebuilt binary khi không (sbt, firtool); build-from-source là phương án cuối và phải ghi lý do vào `src/docker/README.md`. Image giữ nhẹ (mục tiêu ≤2GB, không conda), multi-arch arm64+amd64.
- **Secrets (Docker Hub token...) CHỈ qua env var** (`.env` gitignored, theo `src/docker/.env.example`; CI dùng repository secrets). KHÔNG hardcode, không commit, không echo token vào log.
- **Vivado chỉ chạy x86 Linux/Windows** → bitstream VC707 build trên máy x86, KHÔNG nằm trong Docker image.
- VC707 **không được Chipyard hỗ trợ chính thức** (chỉ VCU118/Arty) — harness VC707 là code tự port, nằm riêng, đánh dấu rõ. Xem `docs/05-vc707-port.md`.

## Agent workflow (BẮT BUỘC — để project tự chạy được bằng AI agent)

### Bắt đầu phiên làm việc

1. Đọc theo thứ tự: `CLAUDE.md` → `PROGRESS.md` → `phases/<current_phase>-*/plan.md` + `actual.md` (các entry cuối).
2. Làm tiếp từ `next_action` trong PROGRESS.md. Không tự ý làm việc ngoài plan của phase hiện tại.

### Phase lifecycle & artifacts (mỗi phase 1 thư mục trong `phases/`)

| File | Viết khi nào | Nội dung | Quy tắc |
|---|---|---|---|
| `plan.md` | TRƯỚC khi bắt đầu phase | Mục tiêu, các bước, điều kiện hoàn thành | Phase chưa có plan.md = chưa được làm |
| `expectations.md` | TRƯỚC khi bắt đầu phase | Dự đoán kết quả (định lượng nếu được) + căn cứ | Viết trước khi thấy số thật — đây là tính khoa học |
| `actual.md` | TRONG khi làm | Nhật ký append-only: lệnh chạy, kết quả, lỗi, số liệu | CHỈ APPEND, không sửa/xóa entry cũ. Mỗi entry có ngày + giờ |
| `changes.md` | Khi lệch khỏi plan | Thay đổi gì, vì sao, ảnh hưởng đến expectations | Ghi TRƯỚC khi thực hiện thay đổi |
| `report.md` | Khi kết thúc phase | So sánh expect vs actual, bài học, input cho phase sau | Điều kiện đóng phase |

### Phase gates (không được vi phạm)

- KHÔNG bắt đầu phase khi `plan.md` + `expectations.md` chưa tồn tại (copy từ `phases/_template/`).
- KHÔNG đóng phase khi: điều kiện hoàn thành trong plan.md chưa tick hết (hoặc chưa ghi rõ lý do bỏ qua trong changes.md), `report.md` chưa viết.
- KHÔNG sửa `expectations.md` sau khi đã có số liệu thật — mọi điều chỉnh ghi vào `changes.md`.

### Kết thúc phiên làm việc (kể cả khi dở dang)

1. Append entry cuối vào `actual.md` của phase hiện tại.
2. Cập nhật `PROGRESS.md`: Snapshot (last_session, **next_action cụ thể đến mức agent mới đọc là làm được ngay**, blockers, last_updated) + bảng nhật ký phiên.
3. Nếu phase vừa xong: viết `report.md`, cập nhật bảng phase trong PROGRESS.md, viết `plan.md` + `expectations.md` cho phase kế (hoặc ghi next_action = "viết plan phase kế").

## Khi làm việc trong repo này

- Trước khi viết code/config mới: đọc spec tương ứng trong `docs/`. Nếu spec chưa cover, cập nhật spec trước, code sau.
- Không sửa trực tiếp source chipyard; mọi thay đổi qua file trong `src/chipyard-configs/` hoặc patch có ghi chú trong `docs/05-vc707-port.md`.
- Sau mỗi thí nghiệm: cập nhật bảng trạng thái trong `docs/04-spec-experiments.md`.
- Khi không chắc về hành vi của Chipyard/Constellation: kiểm tra docs chính thức (chipyard.readthedocs.io, constellation.readthedocs.io) thay vì đoán.
