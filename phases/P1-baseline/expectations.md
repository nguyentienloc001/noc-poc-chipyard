# P1 — Baseline + benchmarks: Expectations

> Viết trước khi chạy số liệu P1. Các con số bên dưới là ước lượng/kỳ vọng để lập kế hoạch, KHÔNG phải kết quả performance của luận văn. (Bản gốc Codex 2026-06-11; normalize chính tả cùng ngày, trước khi có số liệu — nội dung không đổi.)

## Dự đoán

| # | Dự đoán | Định lượng / dấu hiệu | Căn cứ |
|---|---|---|---|
| E1 | Harden infra sẽ phát hiện lỗi trước khi đo dài | 1–2 lỗi nhỏ ở path/provenance/parser trước khi có data thật | Review 2026-06-11 thấy `run_sim.sh`/`parse_results.py` còn tối thiểu |
| E2 | Build baseline Verilator không khó hơn RocketConfig nhiều, nhưng 8-core chậm hơn | Clean x86 tham chiếu P0 RocketConfig 25m15s; 4/8 core là ước lượng có thể lên hàng chục phút | P0 CI x86 log + build incremental sẽ reuse sbt cache |
| E3 | B1 zero-load latency của baseline sẽ ổn định giữa các run | variance cycle/load kỳ vọng <1%; >5% là bug measurement/provenance | Verilator deterministic; P0 smoke instret ổn định |
| E4 | B1 full-spec rất tốn wall-clock trên M1 | ước tính 3–4h/run trên M1 cho B1 4MB/100K loads | P0 report: sim ~4–5 kHz, timeout 10M cycles ~40 phút |
| E5 | B3 aggregate bandwidth baseline tăng sublinear khi tăng active cores | qualitative: 4/8 core bị contention DRAM/SBus rõ hơn 1/2 core | Mô hình crossbar + 1 DRAM channel; chưa phải số liệu |
| E6 | B4 loaded latency baseline tăng khi có background STREAM | qualitative: latency core 0 tăng theo N active | Benchmark design: pointer-chase cạnh tranh với STREAM trên shared interconnect/DRAM |
| E7 | Multi-hart startup là rủi ro cao nhất của benchmark B3–B5 | nếu hart phụ không vào `main`, B3/B4/B5 sẽ deadlock hoặc chỉ đo 1 core | P0 report E6: libgloss có path `_start_secondary`; cần verify thực nghiệm |
| E8 | `Baseline8CoreConfig` có thể dùng `rv64imac/lp64`, không link bằng libgloss default hiện tại | dấu hiệu fail: missing multilib/specs/libgloss khi build benchmark small-core | P0 report mục bài học cho phase sau về `rv64imac/lp64` |
| E9 | Variance >5% nếu xảy ra nhiều khả năng do benchmark bug hơn là do hardware model | instret khác nhau, hart sync sai, parser duplicate, hoặc workload quá ngắn | Verilator deterministic và không có OS noise |

## Nếu dự đoán sai thì có nghĩa là gì

- E2 sai theo hướng build quá lâu: tách CI build cache, giảm số config smoke mỗi PR, nhưng không đổi Chipyard/tool version.
- E3/E9 sai: dừng lại việc đo chính thức, điều tra raw log/instret/seed trước khi thêm data point.
- E4 sai theo hướng quá chậm: ghi `changes.md` trước khi giảm `N_LOADS`/`FOOTPRINT`; mọi số liệu giảm param phải có tag riêng, không trộn với matrix chính.
- E7 sai theo hướng tốt: ghi rõ libgloss đã release hart phụ như thế nào trong docs/03 để P2/FPGA dùng lại.
- E8 sai theo hướng tốt: nếu `rv64gc/lp64d` đủ cho 8-core small, vẫn ghi lại march/mabi thật trong `meta.txt` để tránh nhầm với spec.
