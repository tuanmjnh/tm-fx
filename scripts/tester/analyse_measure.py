"""Summarise WonderwhalesXAU2ModeEA measurement journals (task B harness).

Reads the 18-column journals written by the ``ww2_meas_scalp_*`` tester
scenarios (one file per arm) and reports, per arm:

  trades, winrate, net P&L, expectancy in R and in account currency,
  profit factor, max drawdown from the equity column, the exit-kind mix,
  an R histogram and (when the sibling telemetry CSV exists) the trail mix.

Every measurement run has parity OFF because Pine<->MT5 parity is unproven,
so the output is labelled NOT_STRATEGY_RESULT and must never be read as a
strategy result. An arm with fewer than MIN_SAMPLE closed trades is labelled
INSUFFICIENT_SAMPLE: with ~19 signals/year the in/out-of-sample windows are
expected to be small, and a percentage on 5 trades is noise.

Usage:
  .venv\\Scripts\\python.exe scripts\\tester\\analyse_measure.py <journal.csv> [...]
  .venv\\Scripts\\python.exe scripts\\tester\\analyse_measure.py <directory>

Exit codes: 0 ok, 2 unreadable/empty input.
"""
from __future__ import annotations

import argparse
import collections
import csv
import re
import sys
from pathlib import Path

MIN_SAMPLE = 30
PNL_RE = re.compile(r"\|pnl=(-?\d+(?:\.\d+)?)\|")
R_RE = re.compile(r"\|r=(-?\d+(?:\.\d+)?|NA)")
BUCKETS = (
    ("<=-0.9", lambda r: r <= -0.9),
    ("-0.9..-0.1", lambda r: -0.9 < r < -0.1),
    ("-0.1..0.1", lambda r: -0.1 <= r <= 0.1),
    ("0.1..0.9", lambda r: 0.1 < r < 0.9),
    (">=0.9", lambda r: r >= 0.9),
)


def pct(part: int, whole: int) -> str:
    return f"{100.0 * part / whole:.2f}%" if whole else "n/a"


def ratio(num: float, den: float) -> str:
    return f"{num / den:.2f}" if den else "n/a"


def journal_files(target: Path) -> list[Path]:
    if target.is_dir():
        #--- run_tester.ps1 archives each scenario into its own subdirectory
        #--- (reports/build/tester-reports/<scenario>/sim_<scenario>.csv), so
        #--- a directory argument must search recursively.
        return sorted(p for p in target.rglob("sim_ww2_meas_*.csv")
                      if "_telemetry" not in p.name and "_census" not in p.name)
    return [target]


def analyse(path: Path) -> dict:
    with path.open(encoding="utf-8", newline="") as fh:
        rows = list(csv.DictReader(fh))
    if not rows:
        raise ValueError(f"empty journal: {path}")

    exits = [r for r in rows if r.get("event") == "EXIT"]
    pnls: list[float] = []
    rs: list[float] = []
    pnl_missing = 0
    r_na = 0
    exit_kinds: collections.Counter[str] = collections.Counter()
    for row in exits:
        reason = row.get("reason", "")
        exit_kinds[reason.split("|", 1)[0] or "UNKNOWN"] += 1
        match = PNL_RE.search(reason)
        if not match:
            pnl_missing += 1
            pnls.append(0.0)
        else:
            pnls.append(float(match.group(1)))
        rmatch = R_RE.search(reason)
        if not rmatch or rmatch.group(1) == "NA":
            r_na += 1
        else:
            rs.append(float(rmatch.group(1)))

    wins = sum(1 for p in pnls if p > 0.0)
    losses = sum(1 for p in pnls if p < 0.0)
    flats = len(pnls) - wins - losses
    net = sum(pnls)
    gross_win = sum(p for p in pnls if p > 0.0)
    gross_loss = -sum(p for p in pnls if p < 0.0)
    expectancy_r = sum(rs) / len(rs) if rs else 0.0
    expectancy_usd = net / len(pnls) if pnls else 0.0

    #--- Equity column: peak-to-trough over the observed curve. No deposit is
    #--- assumed, so this is a drawdown of the sampled equity, not of a fixed
    #--- starting balance.
    peak = 0.0
    max_dd = 0.0
    peak_at = 0.0
    trough_at = 0.0
    for row in rows:
        try:
            equity = float(row.get("equity", "0"))
        except ValueError:
            continue
        if equity <= 0.0:
            continue
        if equity > peak:
            peak = equity
            peak_at = equity
        elif peak > 0.0:
            dd = (peak - equity) / peak * 100.0
            if dd > max_dd:
                max_dd = dd
                trough_at = equity

    buckets = collections.Counter()
    for r in rs:
        for label, test in BUCKETS:
            if test(r):
                buckets[label] += 1
                break

    telemetry = path.with_name(path.stem + "_telemetry.csv")
    trail: collections.Counter[str] = collections.Counter()
    if telemetry.is_file():
        with telemetry.open(encoding="utf-8", newline="") as fh:
            for row in csv.DictReader(fh):
                reason = (row.get("trail_reason") or "").strip()
                if reason and reason != "ENTRY":
                    trail[reason] += 1

    return {
        "path": path,
        "trades": len(exits),
        "wins": wins,
        "losses": losses,
        "flats": flats,
        "net": net,
        "gross_win": gross_win,
        "gross_loss": gross_loss,
        "expectancy_r": expectancy_r,
        "expectancy_usd": expectancy_usd,
        "r_known": len(rs),
        "r_na": r_na,
        "pnl_missing": pnl_missing,
        "max_dd": max_dd,
        "peak": peak_at,
        "trough": trough_at,
        "exit_kinds": exit_kinds,
        "buckets": buckets,
        "trail": trail,
        "telemetry": telemetry.is_file(),
    }


def print_arm(result: dict) -> None:
    trades = result["trades"]
    label = "INSUFFICIENT_SAMPLE" if trades < MIN_SAMPLE else "OK"
    print(f"MEASURE {result['path']}")
    print(f"  trades={trades} wins={result['wins']} losses={result['losses']} "
          f"flat={result['flats']} winrate={pct(result['wins'], trades)}")
    print(f"  net={result['net']:.2f} expectancy_usd={result['expectancy_usd']:.2f} "
          f"expectancy_r={result['expectancy_r']:.2f} "
          f"profit_factor={ratio(result['gross_win'], result['gross_loss'])}")
    print(f"  max_drawdown_pct={result['max_dd']:.2f} "
          f"peak_equity={result['peak']:.2f} trough_equity={result['trough']:.2f}")
    print(f"  r_known={result['r_known']} r_na={result['r_na']} "
          f"pnl_missing={result['pnl_missing']}")
    if result["exit_kinds"]:
        print("  exit_kinds " + " ".join(
            f"{k}={v}" for k, v in sorted(result["exit_kinds"].items())))
    if result["buckets"]:
        print("  r_buckets " + " ".join(
            f"{label}={result['buckets'][label]}" for label, _ in BUCKETS))
    if result["telemetry"]:
        if result["trail"]:
            print("  trail " + " ".join(
                f"{k}={v}" for k, v in sorted(result["trail"].items())))
        else:
            print("  trail none")
    else:
        print("  trail no_telemetry_file")
    print(f"  sample={label} (min={MIN_SAMPLE})")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", nargs="+",
                        help="journal CSV(s) or a directory of sim_ww2_meas_*.csv")
    args = parser.parse_args()

    paths: list[Path] = []
    for item in args.target:
        target = Path(item)
        if not target.exists():
            print(f"ERROR: not found: {target}", file=sys.stderr)
            return 2
        paths.extend(journal_files(target))
    if not paths:
        print("ERROR: no journal matched", file=sys.stderr)
        return 2

    print("LABEL: NOT_STRATEGY_RESULT (parity unproven; parity-off measurement only)")
    results = []
    for path in paths:
        try:
            result = analyse(path)
        except (OSError, ValueError) as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
        results.append(result)
        print_arm(result)
        print()

    print("SUMMARY")
    print(f"{'scenario':34s} {'trades':>6s} {'winrate':>8s} {'net':>10s} "
          f"{'exp_r':>7s} {'exp_usd':>9s} {'pf':>6s} {'maxdd%':>7s}  sample")
    for result in results:
        trades = result["trades"]
        print(f"{result['path'].stem[:34]:34s} {trades:6d} "
              f"{pct(result['wins'], trades):>8s} {result['net']:10.2f} "
              f"{result['expectancy_r']:7.2f} {result['expectancy_usd']:9.2f} "
              f"{ratio(result['gross_win'], result['gross_loss']):>6s} "
              f"{result['max_dd']:7.2f}  "
              f"{'INSUFFICIENT_SAMPLE' if trades < MIN_SAMPLE else 'OK'}")

    #--- Guard against the failure mode found on 2026-11-05: two "different"
    #--- arms that closed every trade identically mean the switch under test
    #--- either never fired or never changed an exit. Either way the comparison
    #--- is uninformative and must be called out, not read as "no effect".
    outcomes: dict[tuple, list[str]] = collections.defaultdict(list)
    for result in results:
        key = (result["trades"], round(result["net"], 2),
               result["wins"], result["losses"])
        outcomes[key].append(result["path"].stem)
    for key, names in outcomes.items():
        if len(names) > 1:
            print(f"WARNING: identical closed-trade outcome across "
                  f"{len(names)} arms (check the trail mix: the differing "
                  f"switch may not have fired or changed any exit): "
                  f"{', '.join(names)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
