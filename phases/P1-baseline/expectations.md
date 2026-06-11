# P1 — Baseline + benchmarks: Expectations

> Viet truoc khi chay so lieu P1. Cac con so ben duoi la uoc luong/ky vong de lap ke hoach, KHONG phai ket qua performance cua luan van.

## Du doan

| # | Du doan | Dinh luong / dau hieu | Can cu |
|---|---|---|---|
| E1 | Harden infra se phat hien loi truoc khi do dai | 1-2 loi nho o path/provenance/parser truoc khi co data that | Review 2026-06-11 thay `run_sim.sh`/`parse_results.py` con toi thieu |
| E2 | Build baseline Verilator khong kho hon RocketConfig nhieu, nhung 8-core cham hon | Clean x86 tham chieu P0 RocketConfig 25m15s; 4/8 core la uoc luong co the len hang chuc phut | P0 CI x86 log + build incremental se reuse sbt cache |
| E3 | B1 zero-load latency cua baseline se on dinh giua cac run | variance cycle/load ky vong <1%; >5% la bug measurement/provenance | Verilator deterministic; P0 smoke instret on dinh |
| E4 | B1 full-spec rat ton wall-clock tren M1 | uoc tinh 3-4h/run tren M1 cho B1 4MB/100K loads | P0 report: sim ~4-5 kHz, timeout 10M cycles ~40 phut |
| E5 | B3 aggregate bandwidth baseline tang sublinear khi tang active cores | qualitative: 4/8 core bi contention DRAM/SBus ro hon 1/2 core | Mo hinh crossbar + 1 DRAM channel; chua phai so lieu |
| E6 | B4 loaded latency baseline tang khi co background STREAM | qualitative: latency core 0 tang theo N active | Benchmark design: pointer-chase canh tranh voi STREAM tren shared interconnect/DRAM |
| E7 | Multi-hart startup la rui ro cao nhat cua benchmark B3-B5 | neu hart phu khong vao `main`, B3/B4/B5 se deadlock hoac chi do 1 core | P0 report E6: libgloss co path `_start_secondary`; can verify thuc nghiem |
| E8 | `Baseline8CoreConfig` co the dung `rv64imac/lp64`, khong link bang libgloss default hien tai | dau hieu fail: missing multilib/specs/libgloss khi build benchmark small-core | P0 report muc bai hoc cho phase sau ve `rv64imac/lp64` |
| E9 | Variance >5% neu xay ra nhieu kha nang do benchmark bug hon la do hardware model | instret khac nhau, hart sync sai, parser duplicate, hoac workload qua ngan | Verilator deterministic va khong co OS noise |

## Neu du doan sai thi co nghia la gi

- E2 sai theo huong build qua lau: tach CI build cache, giam so config smoke moi PR, nhung khong doi Chipyard/tool version.
- E3/E9 sai: dung lai viec do chinh thuc, dieu tra raw log/instret/seed truoc khi them data point.
- E4 sai theo huong qua cham: ghi `changes.md` truoc khi giam `N_LOADS`/`FOOTPRINT`; moi so lieu giam param phai co tag rieng, khong tron voi matrix chinh.
- E7 sai theo huong tot: ghi ro libgloss da release hart phu nhu the nao trong docs/03 de P2/FPGA dung lai.
- E8 sai theo huong tot: neu `rv64gc/lp64d` du cho 8-core small, van ghi lai march/mabi that trong `meta.txt` de tranh nham voi spec.
