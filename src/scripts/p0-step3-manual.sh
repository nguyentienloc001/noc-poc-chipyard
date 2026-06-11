#!/usr/bin/env bash
# NoC-PoC P0 step 3 — manual completion of chipyard toolchain collateral.
#
# WHY THIS EXISTS (see phases/P0-environment/actual.md 2026-06-10):
#   build-setup.sh step 3 fails with the apt picolibc toolchain: riscv configure
#   tests need CFLAGS="--specs=picolibc.specs", but a GLOBAL CFLAGS breaks
#   host-gcc builds (spike). Solution: per-component scoped flags.
#   Spike + libfesvr were already installed by the earlier partial run.
#
# REQUIRED components (hard fail): espresso (Constellation), libgloss (bare-metal link)
# Best-effort (warn only): pk, riscv-tests, DRAMSim2, uart_tsi, spike-devices, libgemmini
#
# Run inside the container:
#   bash /project/src/scripts/p0-step3-manual.sh 2>&1 | tee /project/results/raw/p0-step3d-manual.log
set -uo pipefail

RISCV="${RISCV:?export RISCV first (e.g. /work/riscv)}"
CYDIR="${CYDIR:-/work/chipyard}"
SPECS="--specs=picolibc.specs"
NPROC="$(nproc)"
PASS=(); FAIL=(); FAIL_REQ=0

run_component() { # <name> <required:yes|no> <fn>
  local name="$1" required="$2" fn="$3"
  echo ""
  echo "########## ${name} ##########"
  if "$fn"; then
    PASS+=("$name")
  else
    FAIL+=("$name ($([ "$required" = yes ] && echo REQUIRED || echo optional))")
    [ "$required" = yes ] && FAIL_REQ=1
  fi
}

# --- sanity: spike already installed by earlier run ---
sanity() {
  [ -x "$RISCV/bin/spike" ] || { echo "WARNING: spike not found in $RISCV/bin — earlier install missing?"; }
  command -v cmake >/dev/null || {
    echo "cmake missing — installing via apt (also added to Dockerfile for next image rebuild)"
    sudo apt-get update -qq && sudo apt-get install -y -qq cmake || return 1
  }
  return 0
}

do_espresso() (  # REQUIRED — Constellation elaboration needs espresso binary
  set -e
  cd "$CYDIR"
  git submodule update --init --checkout generators/constellation
  cd generators/constellation
  scripts/install-espresso.sh "$RISCV"
)

do_libgloss() (  # REQUIRED — htif crt0/specs for bare-metal tests
  set -e
  cd "$CYDIR"
  git submodule update --init --recursive toolchains/libgloss
  cd toolchains/libgloss
  # Upstream bug: __boot_sync lacks .balign -> store-misaligned trap at boot
  # when picolibc's 1-byte mutex lands before it (actual.md 2026-06-11)
  if git apply --check /project/src/patches/0001-libgloss-htif-balign-boot_sync.patch 2>/dev/null; then
    git apply /project/src/patches/0001-libgloss-htif-balign-boot_sync.patch
  fi
  rm -rf build && mkdir -p build && cd build
  # --disable-multilib: apt toolchain multilib list includes rv32e variants
  # that crt0.S cannot assemble (no x16-x31, zicsr not implied)
  CFLAGS="$SPECS" ../configure --prefix="$RISCV/riscv64-unknown-elf" --host=riscv64-unknown-elf --disable-multilib
  make -j"$NPROC"
  # 'make install' copies all artifacts, THEN fails an assert that libdir is in
  # gcc's search path (never true for the apt toolchain; link with -B instead)
  make install || true
  test -f "$RISCV/riscv64-unknown-elf/lib/libgloss_htif.a"
  test -f "$RISCV/riscv64-unknown-elf/lib/htif.ld"
)

do_pk() (  # optional — only needed for spike user-mode runs
  set -e
  cd "$CYDIR"
  git submodule update --init --recursive toolchains/riscv-tools/riscv-pk
  cd toolchains/riscv-tools/riscv-pk
  rm -rf build && mkdir -p build && cd build
  CFLAGS="$SPECS" ../configure --prefix="$RISCV" --host=riscv64-unknown-elf --with-arch=rv64gc_zifencei
  make -j"$NPROC"
  make install
)

do_riscv_tests() (  # optional — ISA smoke tests (rv64ui-p-*)
  set -e
  cd "$CYDIR"
  git submodule update --init --recursive toolchains/riscv-tools/riscv-tests
  cd toolchains/riscv-tools/riscv-tests
  rm -rf build && mkdir -p build && cd build
  CFLAGS="$SPECS" ../configure --prefix="$RISCV/riscv64-unknown-elf" --with-xlen=64
  make -j"$NPROC"
  make install
)

do_dramsim2() (  # optional — host .so for dramsim-backed sims
  set -e
  cd "$CYDIR"
  git submodule update --init tools/DRAMSim2
  cd tools/DRAMSim2
  make clean
  make libdramsim.so -j"$NPROC"
  cp libdramsim.so "$RISCV/lib/"
)

do_uart_tsi() (  # optional now, NEEDED for VC707 bringup in P3
  set -e
  cd "$CYDIR"
  git submodule update --init generators/testchipip
  cd generators/testchipip/uart_tsi
  make
  cp uart_tsi "$RISCV/bin"
)

do_spike_devices() (  # optional — spike plugin
  set -e
  cd "$CYDIR"
  git submodule update --init toolchains/riscv-tools/riscv-spike-devices
  cd toolchains/riscv-tools/riscv-spike-devices
  make install
)

do_libgemmini() (  # optional — gemmini spike extension (not used by this PoC)
  set -e
  cd "$CYDIR"
  git submodule update --init generators/gemmini
  cd generators/gemmini
  git submodule update --init software/libgemmini
  make -C software/libgemmini install
)

sanity || { echo "sanity/cmake failed"; exit 1; }
run_component "espresso"      yes do_espresso
run_component "libgloss"      yes do_libgloss
run_component "riscv-pk"      no  do_pk
run_component "riscv-tests"   no  do_riscv_tests
run_component "DRAMSim2"      no  do_dramsim2
run_component "uart_tsi"      no  do_uart_tsi
run_component "spike-devices" no  do_spike_devices
run_component "libgemmini"    no  do_libgemmini

echo ""
echo "================ SUMMARY ================"
echo "PASS: ${PASS[*]:-none}"
echo "FAIL: ${FAIL[*]:-none}"
if [ "$FAIL_REQ" -eq 1 ]; then
  echo "REQUIRED component failed — P0 blocked, dán log cho Claude."
  exit 1
fi
echo "Step 3 collateral hoàn tất (optional fails chấp nhận được — ghi actual.md)."
