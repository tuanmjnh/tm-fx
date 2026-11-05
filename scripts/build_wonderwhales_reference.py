"""Build a Pine-schema signal reference from dumped bars (cross-implementation).

This produces the *Python* side of a cross-implementation check: it runs an
independent port of the documented Wonderwhales spec over bars dumped by
``BarDumpTesterEA`` and writes a CSV in the schema
``scripts/compare_pine_exports.py`` expects.

It is **not** Pine parity. Only a CSV exported by TradingView itself can
establish that. The output is labelled CROSS_IMPLEMENTATION wherever it is used,
and it must not be used to unblock the 2-mode EA's ``InpRequireParity`` gate.

Both sides of the comparison are broker server time (the dump and the MQL5 log
come from the same tester run), so the comparator is invoked with
``--mql5-offset-minutes 0``.

Usage:
  .venv\\Scripts\\python.exe scripts\\build_wonderwhales_reference.py ^
      --bars reports\\portref\\bars_M5.csv ^
      --out reports\\portref\\wonderwhales_ref_M5.csv

Exit codes: 0 ok, 2 unreadable/empty/invalid input.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

from mt5_ea_ai_lab.signals.wonderwhales import (  # noqa: E402
    MODE_EMA,
    MODE_SAR,
    MODE_SAR_EMA,
    MODE_SAR_EMA_ATR,
    WonderwhalesConfig,
    signal_rows,
)

MODES = {
    "sar": MODE_SAR,
    "ema": MODE_EMA,
    "sar_ema": MODE_SAR_EMA,
    "sar_ema_atr": MODE_SAR_EMA_ATR,
}

REFERENCE_COLUMNS = (
    "bar_open_time", "symbol", "timeframe", "signal_id", "side",
    "sar_dir", "psar", "fast", "slow", "atr_pct",
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bars", required=True, help="bar CSV from BarDumpTesterEA")
    parser.add_argument("--out", required=True, help="reference CSV to write")
    parser.add_argument("--mode", choices=sorted(MODES), default="sar_ema")
    parser.add_argument("--psar-start", type=float, default=0.02)
    parser.add_argument("--psar-inc", type=float, default=0.02)
    parser.add_argument("--psar-max", type=float, default=0.20)
    parser.add_argument("--fast", type=int, default=20)
    parser.add_argument("--slow", type=int, default=50)
    parser.add_argument("--ema200", type=int, default=200)
    parser.add_argument("--atr-len", type=int, default=14)
    parser.add_argument("--min-atr-pct", type=float, default=0.5)
    parser.add_argument("--vol-ma-len", type=int, default=20)
    parser.add_argument("--rsi-len", type=int, default=14)
    parser.add_argument("--bb-len", type=int, default=20)
    parser.add_argument("--bb-mult", type=float, default=2.0)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    bars_path = Path(args.bars)
    if not bars_path.is_file():
        print(f"ERROR: not a file: {bars_path}", file=sys.stderr)
        return 2
    try:
        bars = pd.read_csv(bars_path, dtype={"bar_open_time": str})
    except (OSError, pd.errors.ParserError, pd.errors.EmptyDataError) as exc:
        print(f"ERROR: cannot read bars: {exc}", file=sys.stderr)
        return 2
    if bars.empty:
        print(f"ERROR: empty bars: {bars_path}", file=sys.stderr)
        return 2

    required = {"bar_open_time", "symbol", "timeframe", "open", "high", "low",
                "close"}
    missing = sorted(required - set(bars.columns))
    if missing:
        print(f"ERROR: bars is missing columns: {missing}", file=sys.stderr)
        return 2

    config = WonderwhalesConfig(
        mode=MODES[args.mode],
        psar_start=args.psar_start,
        psar_inc=args.psar_inc,
        psar_max=args.psar_max,
        fast_ema=args.fast,
        slow_ema=args.slow,
        ema200=args.ema200,
        atr_len=args.atr_len,
        min_atr_pct=args.min_atr_pct,
        vol_ma_len=args.vol_ma_len,
        rsi_len=args.rsi_len,
        bb_len=args.bb_len,
        bb_mult=args.bb_mult,
    )

    symbol = str(bars["symbol"].iloc[0])
    timeframe = str(bars["timeframe"].iloc[0])
    try:
        rows = signal_rows(bars, config, symbol, timeframe)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    rows = rows[list(REFERENCE_COLUMNS)]
    rows.to_csv(out_path, index=False, lineterminator="\n")

    buys = int((rows["side"] == "BUY").sum()) if not rows.empty else 0
    sells = int((rows["side"] == "SELL").sum()) if not rows.empty else 0
    first = rows["bar_open_time"].iloc[0] if not rows.empty else "n/a"
    last = rows["bar_open_time"].iloc[-1] if not rows.empty else "n/a"
    print(
        f"CROSS_IMPLEMENTATION reference: bars={len(bars)} signals={len(rows)} "
        f"buy={buys} sell={sells} symbol={symbol} timeframe={timeframe} "
        f"mode={args.mode} first={first} last={last}"
    )
    print(f"written={out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
