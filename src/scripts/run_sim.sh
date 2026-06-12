#!/usr/bin/env bash
# NoC-PoC: build & run Verilator simulation for a given config.
# Usage:
#   ./run_sim.sh <ConfigName> --build-only
#   ./run_sim.sh <ConfigName> <binary.riscv> [run_tag]
# Env: N_RUNS(3) LOADMEM(1) TIMEOUT_CYCLES(200M) CHIPYARD_DIR(/work/chipyard)
#      IMAGE_DIGEST — REQUIRED for official data points (pinned digest, docs/00 §6)
set -euo pipefail

CHIPYARD_DIR="${CHIPYARD_DIR:-/work/chipyard}"
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"   # repo root (script lives in src/scripts/)
RESULTS_DIR="$PROJECT_DIR/results/raw"

CONFIG="${1:?Usage: run_sim.sh <ConfigName> (--build-only | <binary.riscv>) [tag]}"
ARG2="${2:?Missing second arg: --build-only or path to .riscv binary}"

if [[ "$ARG2" == "--build-only" ]]; then
  cd "$CHIPYARD_DIR/sims/verilator"
  make CONFIG="$CONFIG" -j"$(nproc)"
  echo "Built simulator for $CONFIG"
  exit 0
fi

# Resolve binary to an ABSOLUTE path before any cd (P1 review finding:
# make runs from sims/verilator, a relative path would silently break)
[[ -f "$ARG2" ]] || { echo "ERROR: binary not found: $ARG2" >&2; exit 1; }
BINARY="$(cd "$(dirname "$ARG2")" && pwd)/$(basename "$ARG2")"

TAG="${3:-$(date +%Y%m%d-%H%M%S)}"
OUT_DIR="$RESULTS_DIR/${TAG}-${CONFIG}-$(basename "$BINARY" .riscv)"
mkdir -p "$OUT_DIR"

# Chipyard default +max-cycles is 10M — too low for DRAM-bound benchmarks
# (zeroload 100K loads needs ~50M; measured sim speed ~4-5 kHz on M1, P0 step 7)
TIMEOUT_CYCLES="${TIMEOUT_CYCLES:-200000000}"

# LOADMEM=1: preload ELF into simulated DRAM via backdoor. Without it the TSI
# serial loader writes every bss byte through simulated SerialTL — a 2MB-bss
# benchmark never finished loading within 50M cycles (P0 step 7, actual.md)
LOADMEM="${LOADMEM:-1}"

N_RUNS="${N_RUNS:-3}"
# RUN_OFFSET: heavy combos (8-core, hours/run) split 3 official runs across
# parallel CI jobs — run files get distinct indices so the parser keeps all 3
RUN_OFFSET="${RUN_OFFSET:-0}"

# Provenance for reproducibility (CLAUDE.md rules 1-2; fields per docs/04 §3)
PROJECT_COMMIT="$(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
# untracked files (fresh results/) are not "dirty" — only tracked modifications are
[[ -n "$(git -C "$PROJECT_DIR" status --porcelain --untracked-files=no 2>/dev/null)" ]] && PROJECT_COMMIT="${PROJECT_COMMIT}-dirty"
{
  echo "date: $(date -Iseconds)"
  echo "platform: verilator"
  echo "config: $CONFIG"
  echo "binary: $BINARY"
  echo "binary_sha256: $(sha256sum "$BINARY" | cut -d' ' -f1)"
  echo "chipyard_commit: $(git -C "$CHIPYARD_DIR" rev-parse HEAD)"
  echo "project_commit: $PROJECT_COMMIT"
  echo "image: ${DOCKER_IMAGE:-unknown}:${DOCKER_TAG:-unknown}"
  echo "image_digest: ${IMAGE_DIGEST:-UNSET-not-official}"
  echo "n_runs: $N_RUNS"
  echo "loadmem: $LOADMEM"
  echo "timeout_cycles: $TIMEOUT_CYCLES"
} > "$OUT_DIR/meta.txt"

if [[ "${IMAGE_DIGEST:-}" == "" ]]; then
  echo "WARNING: IMAGE_DIGEST unset — run is NOT a valid official data point (docs/04 §3)" >&2
fi

cd "$CHIPYARD_DIR/sims/verilator"
for i in $(seq 1 "$N_RUNS"); do
  idx=$((RUN_OFFSET + i))
  echo ">> Run $i/$N_RUNS (run_idx=$idx)"
  make CONFIG="$CONFIG" BINARY="$BINARY" LOADMEM="$LOADMEM" timeout_cycles="$TIMEOUT_CYCLES" run-binary 2>&1 | tee "$OUT_DIR/run${idx}.log"
done

echo "Logs: $OUT_DIR"
echo "Next: src/scripts/parse_results.py $OUT_DIR"
