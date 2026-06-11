# P0 — Môi trường: Actual (nhật ký append-only)

> CHỈ APPEND. Mỗi entry: ngày giờ, ai (Loc/Claude/agent), việc, kết quả. Lỗi cũng ghi — lỗi là data.

---

## [2026-06-10] Claude

- Lệnh/việc: Khởi tạo phase P0 (plan + expectations). Chưa chạy lệnh build nào.
- Kết quả: Phase sẵn sàng bắt đầu từ bước 1 (docker compose build trên M1).
- Ghi chú: —

## [2026-06-10] Claude + Loc

- Lệnh/việc: Redesign chiến lược Docker trước khi bắt đầu (yêu cầu Loc): apt-first, multi-arch, root-of-trust trên Docker Hub, build.sh/push.sh, secrets qua env. Viết lại Dockerfile (ubuntu:24.04, gcc-riscv64-unknown-elf + verilator + sbt + firtool), plan.md + expectations.md v2.
- Kết quả: Ghi nhận từ conda-reqs của Chipyard 1.13.0: verilator pin 5.022, gcc 13.2, openjdk 20 — dùng làm chuẩn audit ở bước 2. Chưa build.
- Ghi chú: Rủi ro mở: E7 (verilator 5.020 vs 5.022), E8 (firtool aarch64), E9 (flow không-conda). Xem changes.md entry 2026-06-10.

## [2026-06-10] Claude + Loc

- Lệnh/việc: Refactor Dockerfile sang multi-stage (yêu cầu Loc, tối ưu size): stage `fetcher` tải firtool + sbt tgz; image cuối nhận artifact qua COPY --from. Đổi sbt từ apt-repo scala-sbt sang tgz GitHub releases → loại gnupg/keyring/sources.list phụ khỏi image cuối. PATH: /opt/sbt/bin:/opt/firtool/bin.
- Kết quả: Chưa build — verify ở P0 bước 1–2 như cũ.
- Ghi chú: SBT_VERSION=1.10.7 pin bằng ARG (cùng FIRTOOL_VERSION=1.62.1 — cả hai cần xác nhận khớp Chipyard 1.13.0 ở bước 2).

## [2026-06-10] Claude — P0 bước 0 (verify online trước build)

- Lệnh/việc: Verify asset URLs + version pins qua GitHub API và packages.ubuntu.com (chạy từ sandbox, chưa đụng máy Loc).
- Kết quả:
  - **Chipyard 1.13.0 pin firtool-1.75.0** (`conda-reqs/circt.json`) — KHÔNG phải 1.62.1 như đoán ban đầu → đã sửa `FIRTOOL_VERSION=1.75.0` trong Dockerfile.
  - firtool 1.75.0 assets: có `firrtl-bin-linux-x64.tar.gz` (URL pattern Dockerfile đúng), **không có linux-aarch64** → E8 xác nhận: arm64 image sẽ thiếu firtool, đi đường fallback.
  - sbt 1.10.7 tgz: HTTP 302 (tồn tại) ✓.
  - apt Ubuntu 24.04 (noble): verilator `5.020-1` (E7: vs pin 5.022), `gcc-riscv64-unknown-elf 13.2.0` (**khớp chính xác gcc 13.2 của Chipyard**), `picolibc-riscv64-unknown-elf 1.8.6` có, dtc `1.7.0`, default-jdk-headless = JDK 21 (Chipyard pin openjdk 20; 21 dự kiến OK với sbt — verify bước 4).
  - Chipyard 1.13.0 build.sbt: chisel6Version = 6.5.0.
- Ghi chú: Còn lại phải verify trên máy thật: build image (bước 1), versions audit (bước 2), elaborate không-conda (bước 3, E9).

## [2026-06-10] Loc (build trên Mac M1) + Claude (phân tích)

- Lệnh/việc: P0 bước 1+2: `./build.sh` trên M1 (arm64 native) + `docker images` + `versions.sh`.
- Kết quả:
  - Build PASS. Image `local/noc-poc-chipyard:20260610-nogit` = `sha256:613b3a62ad2c...`. Layer apt 52.1s, fetcher 70.7s, COPY firtool 0.0s (rỗng — đúng E8).
  - **Size 2.39GB** — lệch nhẹ E1 (dự đoán 1.5–2GB), chấp nhận, tối ưu sau nếu cần.
  - Versions: riscv64-unknown-elf-gcc **13.2.0 (khớp chuẩn CY)**, verilator 5.020 (E7 mở), sbt 1.10.7 OK, dtc 1.7.0, java 21 (>20 OK), host gcc 13.3, **firtool: not found trên arm64 (E8 xác nhận)**.
  - Tag `-nogit`: repo chưa git init — đã nhắc Loc init để tag có commit hash.
- Ghi chú: build-setup.sh 1.13.0 có flags `--skip-conda --skip-ctags --skip-firesim --skip-marshal --skip-circt` (đã đọc source script, không đoán). Bước 3 sẽ thử KHÔNG skip circt trước (install-circt có thể fail trên arm64 → khi đó thêm --skip-circt và dùng fallback). sbt fetch launcher mỗi lần chạy --rm → thêm volume /home/dev vào compose.

## [2026-06-10] Loc (M1, trong container) + Claude

- Lệnh/việc: P0 bước 3: clone chipyard, checkout 1.13.0 → commit `69eba860a352343e4ac6b6df0f3638a79a86ec78` (đã pin vào docs/00 + PROGRESS.md). Chạy build-setup lần 1 với --skip-conda --skip-ctags --skip-firesim --skip-marshal.
- Kết quả: Step 2 (submodules) PASS toàn bộ. Step 3 FAIL ngay: `ERROR: If conda initialization skipped, $RISCV variable must be defined` — E9 dạng nhẹ: script cần $RISCV làm install prefix cho spike/pk/riscv-tests/libgloss (xác nhận bằng cách đọc source build-setup.sh dòng 230–243).
- Fix: `export RISCV=/work/riscv` (persist trong volume), chạy lại thêm `--skip-submodules`. Log: results/raw/p0-step3-build-setup.log + p0-step3b-build-setup.log.
- Ghi chú: Lệnh export RISCV phải đưa vào quy trình chuẩn trong src/docker/README.md khi đóng phase (điều kiện gate: "quy trình setup không-conda ghi thành lệnh chính xác"). RISCV cũng đã thêm vào environment của docker-compose.yml.

## [2026-06-10] Loc (M1, container) + Claude — step 3 tiếp: spike PASS, pk FAIL, đã chẩn đoán

- Lệnh/việc: build-setup lần 2 (có RISCV): spike + libfesvr build & install PASS. riscv-pk configure FAIL: "C compiler cannot create executables" (exit 77).
- Chẩn đoán (test trực tiếp trong container):
  - `riscv64-unknown-elf-gcc t.c` → FAIL `cannot find -lc / -lgloss` — **toolchain apt Ubuntu chỉ có picolibc, KHÔNG có newlib**, link mặc định không có libc.
  - Với `--specs=picolibc.specs` → PASS, kể cả `-march=rv64gc_zifencei -mabi=lp64d` (default multilib "." của Ubuntu = rv64gc).
- Fix: rerun build-setup với env `CFLAGS="--specs=picolibc.specs" CXXFLAGS=...` (configure của pk/libgloss đọc CFLAGS từ env; build thật của pk là -nostdlib nên specs vô hại). Log: p0-step3c-build-setup.log.
- **Finding quan trọng cho P1/E5**: mọi bare-metal build với toolchain này cần specs flag tường minh (picolibc) hoặc dùng specs riêng của libgloss-htif (toolchains/libgloss của chipyard). Tương tác picolibc × htif specs sẽ lộ ở step 7 — theo dõi.
- Còn lại trong step 3 sau pk: riscv-tests, **espresso (Constellation cần — bắt buộc pass)**, libgloss.

## [2026-06-10] Claude — step 3 lần 3: global CFLAGS phản tác dụng → script manual

- Vấn đề: rerun với CFLAGS global làm **host build** chết (spike reconfigure bằng gcc aarch64 + picolibc.specs → "cannot create executables"). May: spike + libfesvr đã install vào /work/riscv từ lần trước, không mất.
- Phát hiện thêm: `install-espresso.sh` của Constellation cần **cmake** — image chưa có → đã thêm cmake vào Dockerfile (rebuild trước khi push), container hiện tại cài qua sudo apt.
- Fix: viết `src/scripts/p0-step3-manual.sh` — hoàn thành nốt collateral với flags scope TỪNG component: riscv targets (pk/riscv-tests/libgloss) có CFLAGS specs, host builds (espresso/DRAMSim2/uart_tsi...) không. Required: espresso + libgloss; còn lại best-effort.
- Ghi chú: uart_tsi tiện thể build luôn — P3 (VC707 bringup) sẽ cần.

## [2026-06-10] Claude (Cowork) — kết phiên, bàn giao Claude Code

- Trạng thái: p0-step3-manual.sh ĐÃ VIẾT, CHƯA CHẠY. Spike+libfesvr installed. Container/volume state ghi trong PROGRESS.md mục "Trạng thái môi trường".
- Việc kế: chạy script manual → bước 4 (verilator sim RocketConfig, sẽ đụng E8 firtool trên arm64) → bước 5 (hello). Agent tiếp theo đọc CLAUDE.md → PROGRESS.md → plan.md + actual.md này rồi làm tiếp.

## [2026-06-11 ~05:45–06:00] Claude Code — step 3 hoàn tất: libgloss root-cause + fix (REQUIRED pass đủ)

- Bối cảnh: p0-step3-manual.sh đã được chạy trước phiên này (log `p0-step3d-manual.log`, PROGRESS.md chưa kịp cập nhật): PASS espresso + DRAMSim2 + uart_tsi + spike-devices + libgemmini; FAIL libgloss (REQUIRED), riscv-pk + riscv-tests (optional).
- Chẩn đoán libgloss (toàn bộ trong `results/raw/p0-step3e-libgloss.log`), 3 tầng lỗi:
  1. **Multilib**: apt toolchain `--print-multi-lib` chứa rv32e/ilp32e... mà crt0.S không assemble được (rv32e không có x16–x31; binutils mới đòi `_zicsr` tường minh). Default rv64gc build PASS từ trước. Fix: `configure --disable-multilib`.
  2. **make install**: copy đủ artifacts rồi MỚI fail ở assert "libdir is not in gcc library search path" (gcc apt prefix /usr không bao giờ search `$RISCV`) → chấp nhận `|| true` + verify file tường minh. Hệ quả: mọi lệnh link phải có `-B$RISCV/riscv64-unknown-elf/lib`.
  3. **Bug upstream libgloss-htif** (nghiêm trọng nhất): `__boot_sync` trong `misc/crtmain.S` khai báo `.bss` KHÔNG có `.balign` → section align=1; picolibc đặt `__lock___libc_recursive_mutex` (1 byte) ngay trước → `__boot_sync` rơi vào 0x800005a1 (lẻ) → `sw` trong BARRIER_PASS trap store-misaligned (mcause=6) → handle_trap → `_exit(6)` → spike báo `tohost = 6`. Trace bằng `spike -l`. Bug tiềm ẩn cả với newlib (chỉ thoát nhờ link-order may mắn), sẽ trap cả trên Rocket thật.
- Fix: `src/patches/0001-libgloss-htif-balign-boot_sync.patch` (`.balign 4` trước `__boot_sync` trong crtmain.S + crtmain-argv.S), apply bằng `git apply` vào submodule. Rebuild + install OK.
- **Verify trên spike (3/3 PASS, exit=0)**: empty-main; puts; printf đều chạy đúng, in đúng output. `__boot_sync` → 0x800005a4 (aligned). libgloss REQUIRED **PASS** → step 3 collateral hoàn tất.
- **Link recipe chuẩn cho flow picolibc này** (quan trọng cho P1, src/benchmarks):
  `riscv64-unknown-elf-gcc -O2 --specs=picolibc.specs -B$RISCV/riscv64-unknown-elf/lib --specs=htif.specs --specs=htif_wrap.specs -T$RISCV/riscv64-unknown-elf/lib/htif.ld prog.c -o prog.riscv`
  Lý do từng flag: picolibc.specs (libc paths), -B (tìm specs/lib/ld trong $RISCV), htif.specs (libgloss + medany), htif_wrap.specs (--wrap printf/puts/sprintf/snprintf → stdio đi thẳng HTIF, né `stdout` của picolibc), -T tường minh (thắng -Tpicolibc.ld do picolibc.specs chèn; upstream chipyard/tests cũng dùng -T tường minh).
- Findings khác cho P1/P2:
  - chipyard 1.13 `tests/` build bằng **CMake** (htif_nano.specs + -T htif.ld), KHÔNG phải Makefile như `src/benchmarks/Makefile` đang giả định → P1 phải sửa benchmark build infra; htif_nano.specs cũng sẽ fail trên image này (không có newlib-nano) → dùng recipe trên.
  - apt toolchain CÓ multilib rv64imac/lp64 → khi P2 cần 8-core small (rv64imac), build thêm libgloss variant: `configure --enable-multilib="rv64imac/lp64"`.
- Optional vẫn fail (chấp nhận, không chặn gate, không debug thêm): riscv-pk (Makefile không kế thừa CFLAGS specs từ configure env → thiếu header libc; chỉ cần cho spike user-mode, PoC không dùng), riscv-tests (configure dùng host gcc nhưng dính CFLAGS specs → "cannot create executables"; ISA smoke không bắt buộc).
- Script `p0-step3-manual.sh` đã cập nhật `do_libgloss` (patch + --disable-multilib + verify); patch lưu tại `src/patches/`.

## [2026-06-11 ~06:05] Claude Code — step 4 lần 1: FAIL vì JDK 21 × sbt 1.8.2 → rebuild image với JDK 17

- Lệnh: `make CONFIG=RocketConfig` trong sims/verilator (log `p0-step4-verilator-rocketconfig.log` bản cũ, đã bị ghi đè bởi lần retry — stack trace đầy đủ trong entry này).
- Kết quả: FAIL ngay ở sbt project loading: `scala.reflect.internal.FatalError: ClassfileParser errorBadIndex` → `NoClassDefFoundError: sbt.internal.parser.SbtParser$` → `common.mk:118 Error 1`. KHÔNG phải E8 firtool — chưa chạy tới đó.
- Root cause: chipyard 1.13.0 pin **sbt 1.8.2** (`project/build.properties`), parser dùng Scala 2.12.17 — không đọc được classfile **JDK 21** (image dùng `default-jdk-headless` = 21 trên noble). Đây là lý do conda-reqs upstream pin openjdk 20. Rủi ro này đã được flag ở bước 2 ("java 21 dự kiến OK — verify bước 4") → verify xong: KHÔNG OK.
- Fix (apt-first): Dockerfile đổi `default-jdk-headless` → `openjdk-17-jdk-headless` (LTS, sbt 1.8.2/scala 2.12.17 hỗ trợ đầy đủ). Rebuild image: `local/noc-poc-chipyard:20260611-a998101` (= `:latest`, sha256:1c0a42c7...). Audit: java 17.0.19 ✓. Volumes (chipyard-vol, home-vol) không ảnh hưởng.
- Retry step 4 đang chạy từ image mới.

## [2026-06-11 ~06:10] Claude Code — step 4 PASS (E8 giải quyết bằng firtool x64 qua qemu binfmt)

- Retry với JDK 17: sbt project loading OK, compile rocket-chip/firrtl2/chipyard OK, elaborate RocketConfig → `.fir` sinh ra. FAIL đúng E8: `firtool: command not found` (arm64).
- Khảo sát fallback E8 (log `p0-step4b-verilator-rocketconfig.log`):
  - llvm-firtool maven jar 1.75.0: chỉ có macos-x64/linux-x64/windows-x64 — KHÔNG có aarch64 → loại.
  - firtool linux-x64 chạy qua **binfmt_misc qemu-x86_64** (Docker Desktop có sẵn): cần `libc6:amd64 libstdc++6:amd64 zlib1g:amd64` (dpkg multiarch). `firtool --version` → CIRCT firtool-1.75.0 OK.
  - Chọn đường này vì: **binary giống hệt x86 → Verilog output giống hệt → reproducible giữa arch** (root-of-trust); build CIRCT arm64 từ source để dành nếu elaborate thành bottleneck ở P2.
- Resume make: **PASS**. `simulator-chipyard.harness-RocketConfig` (10.6MB, arm64 native). Tổng resume (firtool qemu + verilate + g++ -j8 + link): **real 1m05.9s** (user 4m38s) — firtool qemu KHÔNG phải bottleneck với config nhỏ. Verilator 5.020 (E7) verilate + compile sạch.
- Thời gian build từ đầu (tham chiếu bước 8): sbt compile toàn bộ generators lần đầu ~25 phút (06:09 trừ thời gian từ ~05:44 retry start, gồm cả fetch deps vào home-vol); các lần sau sẽ nhanh nhờ incremental + cache volume.
- Durable hóa: Dockerfile (fetcher tải linux-x64 cho mọi arch + runtime stage cài amd64 multiarch libs khi TARGETARCH=arm64, có pin Architectures: arm64 cho ubuntu.sources tránh 404 ports), docker-compose.yml (PATH thêm /work/riscv/bin), src/docker/README.md (mục "firtool trên arm64" + quy trình setup không-conda chốt).

## [2026-06-11 ~06:13–07:00] Claude Code — step 5 PASS; step 7 lần 1 timeout 10M cycles → đo được sim speed

- Step 5: `hello.riscv` (build bằng link recipe picolibc+htif của step 3) chạy trên `simulator-chipyard.harness-RocketConfig`: in đúng "Hello HTIF from libgloss+picolibc", `$finish` sạch, **real 9.5s** (log `p0-step5-hello-rocketconfig.log`). PASS.
- Image rebuild `local/noc-poc-chipyard:20260611-a998101` với Dockerfile mới (openjdk-17, firtool x64 + amd64 libs): verify `firtool --version` chạy out-of-box trong image arm64 → E8 đóng bền vững.
- Step 7 lần 1: `zeroload_latency.riscv` (full spec: 4MB/100K loads) qua `run_sim.sh` FAIL: TestDriver assertion ở **+max-cycles=10000000** — default timeout_cycles của chipyard quá thấp cho benchmark DRAM-bound (ước cần ~40–50M cycles: memset 4MB bss + setup 16K nodes + 110K pointer-chase miss). CHƯA có dòng CSV (chương trình chưa tới REPORT).
- **Số liệu cho bước 8 / plan P1**: 10M cycles ≈ ~40 phút wall trên M1 (Docker) → **Verilator RocketConfig ≈ 4–5 kHz**. 1 data point zeroload full-spec ≈ 3–4h. P1 cần tính khối lượng sim theo con số này (hoặc đo trên x86 nhanh hơn).
- Fix: (a) `run_sim.sh` thêm `TIMEOUT_CYCLES` (default 200M) truyền vào `make timeout_cycles=`; (b) `zeroload_latency.c` cho phép override `FOOTPRINT`/`N_LOADS` bằng `-D` (#ifndef guard, default giữ nguyên spec docs/03 — chỉ dùng cho smoke).
- Step 7 lần 2 (đang chạy): smoke build `-DFOOTPRINT=2MB -DN_LOADS=20000` (vẫn > L2 512KB), TIMEOUT_CYCLES=50M → `zeroload_smoke.riscv`, tag `p0-step7-smoke`.
- Finding P1 (đã thấy khi đọc source): `idx[N_NODES]` trong zeroload_latency.c = 128KB stack array (full spec) > `__stack_size_min` 24K của htif.ld → tràn stack vào vùng heap (hiện vô hại vì không dùng malloc, nhưng PHẢI sửa trước khi đo thật — chuyển idx sang static/bss hoặc tăng stack size).

## [2026-06-11 ~07:05] Claude Code — step 7 lần 2 timeout: root cause = TSI serial load, fix = LOADMEM=1

- Smoke 2MB/20K loads vẫn timeout ở 50M cycles. Trace (`+verbose` → spike-dasm `.out`): core chỉ chạy hết **bootrom** (0x10000: mtvec, mideleg, mie=MSIP, mstatus.MIE) rồi đứng ở `wfi` suốt 50M cycles → **chương trình chưa load xong**: loader TSI ghi ~2MB zero-fill (bss arena) qua SerialTL mô phỏng — quá chậm. `hello.riscv` chạy được vì bss nhỏ.
- Fix chuẩn của chipyard: `make run-binary LOADMEM=1` (variables.mk dòng 262, common.mk 295) — preload ELF thẳng vào DRAM mô phỏng. `run_sim.sh` cập nhật: LOADMEM mặc định =1 (env override được).
- Bài học P1: mọi benchmark có arena lớn PHẢI chạy LOADMEM=1; nếu không sẽ "treo ở wfi" — triệu chứng nhận biết: trace chỉ có bootrom + wfi.
- Smoke lần 3 đang chạy: tag `p0-step7-smoke2`, TIMEOUT_CYCLES=50M, LOADMEM=1.

## [2026-06-11 ~07:15] Claude Code — step 7 PASS (pipeline benchmark→CSV thông) + step 8 (timing)

- Step 7 lần 3 (LOADMEM=1, TIMEOUT_CYCLES=50M): **PASS**. `CSV:zeroload_latency,1,20000,1052315,60005` → parse_results.py append row đầu tiên vào `results/csv/results.csv`: derived 52.6157 cycles/load. Sanity: instret 60005 = đúng 3 instr/iteration × 20000 + overhead ✓. Sim tổng ~1.05M cycles + load, wall vài phút. Log: `results/raw/p0-step7-smoke2-RocketConfig-zeroload_smoke/`, meta.txt có commit 69eba860 ✓. Đây là SMOKE (param giảm, config ngoài ma trận E1–E6) — đã ghi chú trong docs/04 mục 5.
- **Step 8 — thời gian thực tế trên Mac M1 (Docker, image 2026-06-11)**:
  - Image build native arm64: ~3–5 phút (apt layer ~52s + fetcher ~71s + multiarch libs).
  - sbt compile toàn bộ generators (lần đầu, cache rỗng): ~25 phút. Incremental sau đó: giây→phút.
  - firtool 1.75.0 x64 qua qemu binfmt trên RocketConfig .fir: **~30–60s** (nằm trong make resume tổng 1m06s gồm cả verilate + g++ -j8 + link) — chấp nhận được, KHÔNG phải bottleneck với config nhỏ.
  - Verilator sim speed RocketConfig: **~4–5 kHz** (đo từ 10M cycles ≈ 40 phút khi treo TSI-load; run thật 1.05M cycles nhanh). → 1 data point B1 full-spec (~50M cycles) ≈ 3–4h/run trên M1; P1 phải lên lịch theo con số này.
  - hello trên sim: 9.5s.
- Trạng thái P0: bước 1–5, 7, 8 ✅. Còn **bước 6** (push multi-arch Docker Hub + verify x86 — cần DOCKERHUB_USER/TOKEN của Loc + máy x86) và gate cuối (digest pin, secrets check, report.md).

## [2026-06-11 ~07:4x] Loc + Claude Code — step 6a: push multi-arch lên Docker Hub, digest PINNED

- Loc cấp Docker Hub credentials → `.env` (gitignored, verify `git check-ignore` OK; login qua `--password-stdin`, token không vào log/argv).
- `./build.sh --arch multi` qua builder `chipyard-builder` (docker-container driver): build từ đầu cả 2 arch (amd64 qua qemu emulation), push thành công.
- **PINNED** (đã ghi docs/00 mục 6 + PROGRESS.md):
  - Image: `locnguyen96/noc-poc-chipyard:20260611-a998101` (= `:latest`)
  - Manifest list digest: `sha256:5744085506b9d7dedff92fa89e786083586cccec14af6461c03e62da34190c14`
  - linux/amd64: `sha256:a78aafb6fa86ed656faca71f092efe37e08c307121dddc51f64eefd92468a280`
  - linux/arm64: `sha256:60720a5baf62247732f89e1d0444efd963a0cf1e492d722b4365d913a2dd7080`
  - Verify: `docker buildx imagetools inspect` xác nhận 2 platform; tag dated và latest cùng digest.
- Còn lại của bước 6 (gate): trên máy x86 pull image theo digest, lặp bước 4–5 (build sim RocketConfig + hello pass) — chứng minh root-of-trust trên arch thứ hai.
