#!/usr/bin/env bash
# NoC-PoC: build & run Verilator simulation for a given config.
# Usage:
#   ./run_sim.sh <ConfigName> --build-only
#   ./run_sim.sh <ConfigName> <binary.riscv> [run_tag]
set -euo pipefail

CHIPYARD_DIR="${CHIPYARD_DIR:-/work/chipyard}"
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"   # repo root (script lives in src/scripts/)
RESULTS_DIR="$PROJECT_DIR/results/raw"

CONFIG="${1:?Usage: run_sim.sh <ConfigName> (--build-only | <binary.riscv>) [tag]}"
ARG2="${2:?Missing second arg: --build-only or path to .riscv binary}"

cd "$CHIPYARD_DIR/sims/verilator"

if [[ "$ARG2" == "--build-only" ]]; then
  make CONFIG="$CONFIG" -j"$(nproc)"
  echo "Built simulator for $CONFIG"
  exit 0
fi

BINARY="$ARG2"
TAG="${3:-$(date +%Y%m%d-%H%M%S)}"
OUT_DIR="$RESULTS_DIR/${TAG}-${CONFIG}-$(basename "$BINARY" .riscv)"
mkdir -p "$OUT_DIR"

# Provenance for reproducibility (CLAUDE.md rule 2)
{
  echo "date: $(date -Iseconds)"
  echo "config: $CONFIG"
  echo "binary: $BINARY"
  echo "chipyard_commit: $(git -C "$CHIPYARD_DIR" rev-parse HEAD)"
} > "$OUT_DIR/meta.txt"

# Chipyard default +max-cycles is 10M — too low for DRAM-bound benchmarks
# (zeroload 100K loads needs ~50M; measured sim speed ~4-5 kHz on M1, P0 step 7)
TIMEOUT_CYCLES="${TIMEOUT_CYCLES:-200000000}"

# LOADMEM=1: preload ELF into simulated DRAM via backdoor. Without it the TSI
# serial loader writes every bss byte through simulated SerialTL — a 2MB-bss
# benchmark never finished loading within 50M cycles (P0 step 7, actual.md)
LOADMEM="${LOADMEM:-1}"

N_RUNS="${N_RUNS:-3}"
for i in $(seq 1 "$N_RUNS"); do
  echo ">> Run $i/$N_RUNS"
  make CONFIG="$CONFIG" BINARY="$BINARY" LOADMEM="$LOADMEM" timeout_cycles="$TIMEOUT_CYCLES" run-binary 2>&1 | tee "$OUT_DIR/run${i}.log"
done

echo "Logs: $OUT_DIR"
echo "Next: src/scripts/parse_results.py $OUT_DIR"
