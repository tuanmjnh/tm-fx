"""Summarise a WonderwhalesXAU2ModeEA signal census CSV.

The census is written when the EA runs with ``InpDebug=true`` (the
``ww2_scalp_census`` tester scenario does). One row per evaluated chart bar,
with one reason per row: the first gate of the bias/setup/trigger chain that
did not pass.

Usage:
  .venv\\Scripts\\python.exe scripts\\tester\\analyse_census.py <census.csv>

Exit codes: 0 ok, 2 unreadable/empty file.
"""
from __future__ import annotations

import argparse
import collections
import csv
import sys
from datetime import datetime
from pathlib import Path

FUNNEL_REASONS = (
    "bias_invalid",
    "no_m15_bias",
    "no_w1_bias",
    "setup_invalid",
    "no_m5_flip",
    "no_d1_align",
    "trigger_invalid",
    "no_m1_confirm",
    "no_h1_trigger",
    "signal",
)


def pct(part: int, whole: int) -> str:
    return f"{100.0 * part / whole:.2f}%" if whole else "n/a"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("census", help="path to <journal>_census.csv")
    args = parser.parse_args()

    path = Path(args.census)
    if not path.is_file():
        print(f"ERROR: not a file: {path}", file=sys.stderr)
        return 2
    with path.open(encoding="utf-8", newline="") as fh:
        rows = list(csv.DictReader(fh))
    if not rows:
        print(f"ERROR: empty census: {path}", file=sys.stderr)
        return 2

    def flag(row: dict[str, str], name: str) -> bool:
        return row.get(name) == "1"

    reasons = collections.Counter(row["reason"] for row in rows)
    unknown = sorted(set(reasons) - set(FUNNEL_REASONS))
    bars = len(rows)
    bias_long = sum(1 for r in rows if flag(r, "bias_buy"))
    bias_short = sum(1 for r in rows if flag(r, "bias_sell"))
    #--- Only a setup that agrees with the bias side is a funnel pass; a flip
    #--- against the bias is a counter-trend setup, reported separately.
    setup_long = sum(1 for r in rows if flag(r, "bias_buy") and flag(r, "setup_buy"))
    setup_short = sum(1 for r in rows if flag(r, "bias_sell") and flag(r, "setup_sell"))
    signals = sum(1 for r in rows if flag(r, "signal"))
    bias_any = bias_long + bias_short
    setup_any = setup_long + setup_short
    #--- In SAR_EMA mode the indicator already gates a flip on fast>slow, so the
    #--- EA's own alignment re-check must never reject a passed setup. A zero
    #--- here means the two layers disagree.
    align_missing = sum(
        1
        for r in rows
        if (flag(r, "bias_buy") and flag(r, "setup_buy") and not flag(r, "setup_align"))
        or (flag(r, "bias_sell") and flag(r, "setup_sell") and not flag(r, "setup_align"))
    )
    counter_long_bias = sum(1 for r in rows if flag(r, "bias_buy") and flag(r, "setup_sell"))
    counter_short_bias = sum(1 for r in rows if flag(r, "bias_sell") and flag(r, "setup_buy"))
    years = collections.Counter(r["bar_time"][:4] for r in rows if flag(r, "signal"))
    signal_rows = [r for r in rows if flag(r, "signal")]
    first = rows[0]["bar_time"]
    last = rows[-1]["bar_time"]
    fmt = "%Y.%m.%d %H:%M"
    span_years = max(
        (datetime.strptime(last, fmt) - datetime.strptime(first, fmt)).days / 365.25,
        0.0,
    )

    print(f"CENSUS {path}")
    print(f"mode={rows[0].get('mode', '?')} bars={bars} first={first} last={last}")
    print("FUNNEL")
    print(f"  bars          {bars:8d}  100.00%")
    print(f"  bias          {bias_any:8d}  {pct(bias_any, bars):>7}  "
          f"(long={bias_long} short={bias_short})")
    print(f"  setup         {setup_any:8d}  {pct(setup_any, bars):>7}  "
          f"(long={setup_long} short={setup_short}; {pct(setup_any, bias_any)} of bias bars)")
    print(f"  signal        {signals:8d}  {pct(signals, bars):>7}  "
          f"({pct(signals, setup_any)} of setup bars)")
    if span_years > 0.0:
        print(f"  signals/year  {signals / span_years:8.1f}  over {span_years:.2f} years")
    print("REASONS")
    for reason in FUNNEL_REASONS:
        if reasons.get(reason):
            print(f"  {reason:18s} {reasons[reason]:8d}  {pct(reasons[reason], bars):>7}")
    if unknown:
        print(f"  {'UNKNOWN':18s} {sum(reasons[r] for r in unknown):8d}  {unknown}")
    print("CROSS-CHECKS")
    print(f"  counter_trend_setup_long_bias={counter_long_bias} "
          f"short_bias={counter_short_bias}")
    print(f"  setup_pass_without_align={align_missing} (must be 0 in SAR_EMA mode)")
    if years:
        print("SIGNAL_YEARS " + " ".join(f"{y}={years[y]}" for y in sorted(years)))
        print(f"signal_first={signal_rows[0]['bar_time']} signal_last={signal_rows[-1]['bar_time']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
