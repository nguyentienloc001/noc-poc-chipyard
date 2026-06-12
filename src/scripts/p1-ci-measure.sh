#!/usr/bin/env bash
# NoC-PoC P1 — official measurement job (runs INSIDE the pinned image on CI x86).
# Bootstraps chipyard from scratch (root-of-trust), builds <CONFIG> sim and
# <BENCH>, then runs N_RUNS via run_sim.sh (full provenance in meta.txt).
# Raw logs land in /project/results/raw/<TAG>-<CONFIG>-<BENCH>/ — the workflow
# uploads them as artifacts; parsing into results.csv happens locally (curated).
#
# Env (set by .github/workflows/p1-measure.yml):
#   CONFIG BENCH NCORES MARCH MABI DEFS N_RUNS TIMEOUT_CYCLES TAG IMAGE_DIGEST
set -euo pipefail

CONFIG="${CONFIG:?}"; BENCH="${BENCH:?}"; TAG="${TAG:?}"
NCORES="${NCORES:-2}"; MARCH="${MARCH:-rv64gc}"; MABI="${MABI:-lp64d}"
DEFS="${DEFS:-}"; N_RUNS="${N_RUNS:-3}"; TIMEOUT_CYCLES="${TIMEOUT_CYCLES:-200000000}"
RUN_OFFSET="${RUN_OFFSET:-0}"

export RISCV="${RISCV:-/work/riscv}"
export PATH="$RISCV/bin:$PATH"
CYDIR="${CYDIR:-/work/chipyard}"
CY_COMMIT=69eba860a352343e4ac6b6df0f3638a79a86ec78

echo "== arch: $(uname -m) | config=$CONFIG bench=$BENCH ncores=$NCORES march=$MARCH n_runs=$N_RUNS"
[ "$(uname -m)" = "x86_64" ] || echo "WARNING: not x86_64 — official runs expected on CI x86"

# /project checkout is owned by the runner uid -> avoid git "dubious ownership"
# so meta.txt records the real project commit
git config --global --add safe.directory /project 2>/dev/null || true

echo "== bootstrap chipyard @ $CY_COMMIT (procedure: src/docker/README.md)"
git clone https://github.com/ucb-bar/chipyard.git "$CYDIR"
cd "$CYDIR" && git checkout "$CY_COMMIT"
./build-setup.sh riscv-tools --skip-conda --skip-ctags --skip-firesim --skip-marshal \
  || echo "build-setup nonzero (expected with picolibc) — manual collateral follows"
test -f "$RISCV/lib/libfesvr.a" || test -f "$RISCV/lib/libfesvr.so"
bash /project/src/scripts/p0-step3-manual.sh

if [[ "$MARCH" == rv64imac* ]]; then
  echo "== libgloss multilib rv64imac/lp64 (P1 actual.md 2026-06-12: build with _zicsr march, install dir renamed)"
  cd "$CYDIR/toolchains/libgloss"
  rm -rf build && mkdir -p build && cd build
  CFLAGS="--specs=picolibc.specs" ../configure --prefix="$RISCV/riscv64-unknown-elf" \
    --host=riscv64-unknown-elf --enable-multilib="rv64imac_zicsr_zifencei/lp64"
  make -j"$(nproc)"
  make install || true
  LIBDIR="$RISCV/riscv64-unknown-elf/lib"
  rm -rf "$LIBDIR/rv64imac" && mv "$LIBDIR/rv64imac_zicsr_zifencei" "$LIBDIR/rv64imac"
  test -f "$LIBDIR/rv64imac/lp64/libgloss_htif.a"
fi

echo "== install configs + build sim $CONFIG"
cp /project/src/chipyard-configs/NoCResearchConfigs.scala \
   "$CYDIR/generators/chipyard/src/main/scala/config/"
cd "$CYDIR/sims/verilator"
make CONFIG="$CONFIG" -j"$(nproc)"

echo "== build benchmark $BENCH (NCORES=$NCORES MARCH=$MARCH MABI=$MABI DEFS=$DEFS)"
make -C /project/src/benchmarks "build/$BENCH.riscv" \
  NCORES="$NCORES" MARCH="$MARCH" MABI="$MABI" DEFS="$DEFS"

echo "== measure: $N_RUNS runs (offset $RUN_OFFSET)"
export CHIPYARD_DIR="$CYDIR" N_RUNS TIMEOUT_CYCLES RUN_OFFSET
bash /project/src/scripts/run_sim.sh "$CONFIG" "/project/src/benchmarks/build/$BENCH.riscv" "$TAG"

echo "== done; raw logs:"
OUT="/project/results/raw/${TAG}-${CONFIG}-${BENCH}"
ls -la "$OUT/"
# Hard assertion: every run must have produced a CSV measurement line —
# a green job without data is worse than a red one
for i in $(seq 1 "$N_RUNS"); do
  idx=$((RUN_OFFSET + i))
  grep -q "CSV:" "$OUT/run${idx}.log" || { echo "ERROR: no CSV line in run${idx}.log"; exit 1; }
done
echo "== all $N_RUNS runs have CSV lines — MEASURE OK"
