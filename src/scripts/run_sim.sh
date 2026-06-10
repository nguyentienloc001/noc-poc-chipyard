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

N_RUNS="${N_RUNS:-3}"
for i in $(seq 1 "$N_RUNS"); do
  echo ">> Run $i/$N_RUNS"
  make CONFIG="$CONFIG" BINARY="$BINARY" run-binary 2>&1 | tee "$OUT_DIR/run${i}.log"
done

echo "Logs: $OUT_DIR"
echo "Next: src/scripts/parse_results.py $OUT_DIR"
