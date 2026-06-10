#!/usr/bin/env python3
"""NoC-PoC: parse raw sim/FPGA logs -> append results/csv/results.csv

Looks for lines:  CSV:<bench>,<n_active_cores>,<param>,<cycles>,<instret>
Schema (docs/04): date,platform,config,benchmark,n_active_cores,param,run_idx,cycles,instret,derived_metric
"""
import csv
import re
import sys
from pathlib import Path

CSV_RE = re.compile(r"CSV:([\w-]+),(\d+),(-?\d+),(\d+),(\d+)")

DERIVED = {
    # bench -> fn(param, cycles) -> derived metric
    "zeroload_latency": lambda p, c: c / p if p else 0,        # cycles/load
    "loaded_latency":   lambda p, c: c / p if p else 0,        # cycles/load
    "contention_bw":    lambda p, c: p / c if c else 0,        # bytes/cycle (param=total bytes)
    "stream_bw":        lambda p, c: p / c if c else 0,
    "core2core":        lambda p, c: c / p if p else 0,        # cycles/round-trip
}


def parse_dir(raw_dir: Path):
    meta = {}
    meta_file = raw_dir / "meta.txt"
    if meta_file.exists():
        for line in meta_file.read_text().splitlines():
            k, _, v = line.partition(":")
            meta[k.strip()] = v.strip()
    platform = meta.get("platform", "verilator")
    config = meta.get("config", "unknown")
    date = meta.get("date", "")[:10]

    rows = []
    for log in sorted(raw_dir.glob("run*.log")):
        run_idx = int(re.search(r"run(\d+)", log.name).group(1))
        for m in CSV_RE.finditer(log.read_text(errors="replace")):
            bench, ncores, param, cycles, instret = m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5))
            derived = DERIVED.get(bench, lambda p, c: 0)(param, cycles)
            rows.append([date, platform, config, bench, ncores, param, run_idx, cycles, instret, f"{derived:.6g}"])
    return rows


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    raw_dir = Path(sys.argv[1])
    out = Path(__file__).resolve().parents[2] / "results" / "csv" / "results.csv"  # repo root = parents[2]
    out.parent.mkdir(parents=True, exist_ok=True)

    rows = parse_dir(raw_dir)
    if not rows:
        sys.exit(f"No CSV: lines found in {raw_dir}")

    new_file = not out.exists()
    with out.open("a", newline="") as f:
        w = csv.writer(f)
        if new_file:
            w.writerow(["date", "platform", "config", "benchmark", "n_active_cores",
                        "param", "run_idx", "cycles", "instret", "derived_metric"])
        w.writerows(rows)
    print(f"Appended {len(rows)} rows -> {out}")

    # Variance check (CLAUDE.md rule 4)
    by_key = {}
    for r in rows:
        by_key.setdefault((r[3], r[4], r[5]), []).append(int(r[7]))
    for key, cycles in by_key.items():
        if len(cycles) >= 2:
            spread = (max(cycles) - min(cycles)) / min(cycles)
            flag = "  <-- VARIANCE >5%, investigate!" if spread > 0.05 else ""
            print(f"  {key}: spread {spread:.1%}{flag}")


if __name__ == "__main__":
    main()
