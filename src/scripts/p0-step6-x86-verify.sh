#!/usr/bin/env bash
# NoC-PoC P0 step 6b — x86 root-of-trust verification.
# Runs INSIDE the pinned image (see docs/00 §6) on a real x86_64 host
# (GitHub Actions ubuntu-latest). Replicates P0 steps 3–5 from a clean /work:
#   clone chipyard @ pinned commit -> non-conda collateral -> build verilator
#   sim RocketConfig -> build hello with the picolibc+htif recipe -> run -> assert.
# Expects: /project = this repo (read-only OK), /work writable, RISCV set.
set -euo pipefail

echo "== arch check"
[ "$(uname -m)" = "x86_64" ] || { echo "ERROR: expected x86_64, got $(uname -m)"; exit 1; }

export RISCV="${RISCV:-/work/riscv}"
export PATH="$RISCV/bin:$PATH"
CYDIR="${CYDIR:-/work/chipyard}"
CY_COMMIT=69eba860a352343e4ac6b6df0f3638a79a86ec78

echo "== tool versions (image audit)"
/home/dev/versions.sh || true

echo "== clone chipyard @ ${CY_COMMIT} (pin: docs/00 §6)"
git clone https://github.com/ucb-bar/chipyard.git "$CYDIR"
cd "$CYDIR"
git checkout "$CY_COMMIT"

echo "== build-setup non-conda (spike+fesvr; later steps fail with picolibc toolchain - expected)"
./build-setup.sh riscv-tools --skip-conda --skip-ctags --skip-firesim --skip-marshal \
  || echo "WARN: build-setup exited nonzero (expected: riscv-pk needs picolibc specs) — manual collateral follows"
[ -f "$RISCV/lib/libfesvr.a" ] || [ -f "$RISCV/lib/libfesvr.so" ] \
  || { echo "ERROR: libfesvr missing — build-setup died before spike install"; exit 1; }

echo "== manual collateral (espresso + libgloss REQUIRED; applies libgloss patch)"
bash /project/src/scripts/p0-step3-manual.sh

echo "== P0 step 4: build verilator sim RocketConfig"
cd "$CYDIR/sims/verilator"
make CONFIG=RocketConfig

echo "== P0 step 5: hello (picolibc+htif link recipe, actual.md 2026-06-11)"
LIBDIR="$RISCV/riscv64-unknown-elf/lib"
WORKTMP=/work/smoke && mkdir -p "$WORKTMP"
printf '#include <stdio.h>\nint main(void){ printf("Hello HTIF x86 root-of-trust\\n"); return 0; }\n' > "$WORKTMP/hello.c"
riscv64-unknown-elf-gcc -O2 --specs=picolibc.specs -B"$LIBDIR" \
  --specs=htif.specs --specs=htif_wrap.specs -T"$LIBDIR/htif.ld" \
  "$WORKTMP/hello.c" -o "$WORKTMP/hello.riscv"

timeout 600 ./simulator-chipyard.harness-RocketConfig "$WORKTMP/hello.riscv" | tee "$WORKTMP/hello.log"
grep -q "Hello HTIF x86 root-of-trust" "$WORKTMP/hello.log"

echo ""
echo "================ X86 ROOT-OF-TRUST VERIFY: PASS ================"
