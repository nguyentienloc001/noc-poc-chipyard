#!/usr/bin/env python3
"""NoC-PoC: parse raw sim/FPGA logs -> results/csv/results.csv + summary.csv

Looks for lines:  CSV:<bench>,<n_active_cores>,<param>,<cycles>,<instret>
Row schema (docs/03 §4): date,platform,config,benchmark,n_active_cores,param,run_idx,cycles,instret,derived_metric
Summary schema (docs/04 §3): platform,config,benchmark,n_active_cores,param,n_runs,median_cycles,min_cycles,max_cycles,spread_pct,median_derived,flag

Idempotent: re-parsing the same dir skips rows already present (exact match on
all fields except derived_metric). Groups with <3 runs are flagged `smoke` in
summary — not valid official data points (CLAUDE.md rule 4; P1 changes.md 2026-06-11).
"""
import csv
import re
import statistics
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

# Official data point = run from the PINNED root-of-trust image (docs/00 §6).
# Verilator is deterministic so N_RUNS=1 is official (changes.md 2026-06-14) —
# "smoke" is no longer about run count but about provenance: reduced-param /
# unpinned exploratory runs have no/UNSET image_digest.
PINNED_DIGEST = "sha256:5744085506b9d7dedff92fa89e786083586cccec14af6461c03e62da34190c14"

HEADER = ["date", "platform", "config", "benchmark", "n_active_cores",
          "param", "run_idx", "cycles", "instret", "derived_metric", "source"]
SUMMARY_HEADER = ["platform", "config", "benchmark", "n_active_cores", "param",
                  "n_runs", "median_cycles", "min_cycles", "max_cycles",
                  "spread_pct", "median_derived", "flag"]


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
    source = "official" if meta.get("image_digest") == PINNED_DIGEST else "smoke"

    rows = []
    for log in sorted(raw_dir.glob("run*.log")):
        run_idx = int(re.search(r"run(\d+)", log.name).group(1))
        for m in CSV_RE.finditer(log.read_text(errors="replace")):
            bench, ncores, param, cycles, instret = (
                m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5)))
            derived = DERIVED.get(bench, lambda p, c: 0)(param, cycles)
            rows.append([date, platform, config, bench, str(ncores), str(param),
                         str(run_idx), str(cycles), str(instret), f"{derived:.6g}", source])
    return rows


def identity(row):
    # all fields except derived_metric (recomputable)
    return tuple(row[:9])


def write_summary(all_rows, out_path: Path):
    groups = {}
    for r in all_rows:
        key = (r[1], r[2], r[3], r[4], r[5])  # platform,config,bench,ncores,param
        groups.setdefault(key, []).append(r)
    with out_path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(SUMMARY_HEADER)
        for key in sorted(groups):
            rs = groups[key]
            cycles = [int(r[7]) for r in rs]
            derived = [float(r[9]) for r in rs]
            spread = (max(cycles) - min(cycles)) / min(cycles) * 100 if min(cycles) else 0.0
            flags = []
            if any(r[10] != "official" for r in rs):  # provenance, not run count
                flags.append("smoke")
            if spread > 5.0:
                flags.append("HIGH-VARIANCE")
            w.writerow(list(key) + [len(rs), int(statistics.median(cycles)),
                                    min(cycles), max(cycles), f"{spread:.2f}",
                                    f"{statistics.median(derived):.6g}",
                                    ";".join(flags)])


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    raw_dir = Path(sys.argv[1])
    csv_dir = Path(__file__).resolve().parents[2] / "results" / "csv"  # repo root = parents[2]
    csv_dir.mkdir(parents=True, exist_ok=True)
    out = csv_dir / "results.csv"

    new_rows = parse_dir(raw_dir)
    if not new_rows:
        sys.exit(f"No CSV: lines found in {raw_dir}")

    existing = []
    if out.exists():
        with out.open() as f:
            rdr = csv.reader(f)
            next(rdr, None)  # header
            existing = [r for r in rdr if r]
    seen = {identity(r) for r in existing}

    appended = [r for r in new_rows if identity(r) not in seen]
    skipped = len(new_rows) - len(appended)
    if appended:
        new_file = not out.exists()
        with out.open("a", newline="") as f:
            w = csv.writer(f)
            if new_file:
                w.writerow(HEADER)
            w.writerows(appended)
    print(f"Appended {len(appended)} rows -> {out}"
          + (f" (skipped {skipped} duplicates — idempotent)" if skipped else ""))

    all_rows = existing + appended
    summary = csv_dir / "summary.csv"
    write_summary(all_rows, summary)
    print(f"Regenerated {summary}")

    # Provenance + variance report for THIS dir (source = official/smoke per meta)
    src = new_rows[0][10]
    by_key = {}
    for r in new_rows:
        by_key.setdefault((r[3], r[4], r[5]), []).append(int(r[7]))
    for key, cycles in by_key.items():
        tag = "OFFICIAL" if src == "official" else "smoke (not official — unpinned/reduced)"
        line = f"  {key}: {len(cycles)} run(s), {tag}"
        if len(cycles) >= 2:
            spread = (max(cycles) - min(cycles)) / min(cycles)
            line += f", spread {spread:.1%}" + ("  <-- VARIANCE >5%, investigate!" if spread > 0.05 else "")
        print(line)


if __name__ == "__main__":
    main()
