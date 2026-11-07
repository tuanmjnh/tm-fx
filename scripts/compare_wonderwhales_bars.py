"""Per-bar agreement between the MQL5 Wonderwhales indicator and the Python port.

This is the *cross-implementation* check: the MQL5 side is the buffer dump
written by ``WonderwhalesDumpTesterEA``, the Python side is an independent
reimplementation of the documented Pine spec run over the same bars. It is **not**
Pine parity, and its result must never be used to unblock ``InpRequireParity``.

Reports, over the rows after the warm-up window:
  * exact-match rates for ``sar_dir``, ``buy_signal``, ``sell_signal``;
  * max absolute difference and tolerance pass-rate for ``psar``/``fast``/``slow``;
  * the first few mismatching bar times per field, so a real disagreement can be
    inspected instead of guessed.

Exit codes: 0 report written, 2 unreadable/invalid input.

Usage:
  .venv\\Scripts\\python.exe scripts\\compare_wonderwhales_bars.py ^
      --dump reports\\build\\tester-reports\\portref_dump_m5\\sim_portref_dump_m5.csv ^
      --out-dir reports\\portref --warmup-bars 300
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

from mt5_ea_ai_lab.signals.wonderwhales import (  # noqa: E402
    MODE_EMA,
    MODE_SAR,
    MODE_SAR_EMA,
    MODE_SAR_EMA_ATR,
    WonderwhalesConfig,
    generate_bars,
)

MODES = {
    "sar": MODE_SAR,
    "ema": MODE_EMA,
    "sar_ema": MODE_SAR_EMA,
    "sar_ema_atr": MODE_SAR_EMA_ATR,
}

EXACT_FIELDS = ("sar_dir", "buy_signal", "sell_signal", "blocked_buy",
                "blocked_sell")
NUMERIC_FIELDS = ("psar", "fast", "slow")


def _to_number(series: pd.Series) -> pd.Series:
    """Parse to float, treating blanks and implausible magnitudes as missing.

    An MQL5 EMPTY_VALUE (DBL_MAX) can survive a round trip as a huge float rather
    than as an empty field, and an XAU price is never near 1e12, so anything that
    large is really "no value" and must not be compared.
    """

    numeric = pd.to_numeric(series.replace("", np.nan), errors="coerce")
    return numeric.mask(numeric.abs() > 1.0e12, np.nan)


def explain(report: dict) -> str:
    lines = [
        "CROSS_IMPLEMENTATION port check (NOT Pine parity)",
        f"bars={report['bars']} compared={report['compared']} "
        f"warmup_skipped={report['skipped']}",
        f"exact_match={json.dumps(report['exact_match'], sort_keys=True)}",
        f"numeric={json.dumps(report['numeric'], sort_keys=True)}",
    ]
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump", required=True,
                        help="CSV from WonderwhalesDumpTesterEA")
    parser.add_argument("--out-dir", default="reports/portref")
    parser.add_argument("--warmup-bars", type=int, default=300,
                        help="leading rows skipped on both sides")
    parser.add_argument("--mode", choices=sorted(MODES), default="sar_ema")
    parser.add_argument("--tolerance-price", type=float, default=1e-4)
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
    args = parser.parse_args(argv)

    dump_path = Path(args.dump)
    if not dump_path.is_file():
        print(f"ERROR: not a file: {dump_path}", file=sys.stderr)
        return 2
    try:
        dump = pd.read_csv(dump_path, dtype=str)
    except (OSError, pd.errors.ParserError, pd.errors.EmptyDataError) as exc:
        print(f"ERROR: cannot read dump: {exc}", file=sys.stderr)
        return 2
    if dump.empty:
        print(f"ERROR: empty dump: {dump_path}", file=sys.stderr)
        return 2

    required = {"bar_open_time", "open", "high", "low", "close", "psar",
                "sar_dir", "buy_signal", "sell_signal", "fast", "slow",
                "blocked_buy", "blocked_sell"}
    missing = sorted(required - set(dump.columns))
    if missing:
        print(f"ERROR: dump is missing columns: {missing}", file=sys.stderr)
        return 2
    if args.warmup_bars < 0:
        print("ERROR: --warmup-bars must be >= 0", file=sys.stderr)
        return 2

    #--- PSAR is a recurrence, so the two series only agree when they start at
    #--- the same bar. The MQL5 indicator starts at ITS first computable bar,
    #--- which may be inside the preloaded history; run the port from there.
    psar_all = _to_number(dump["psar"]).to_numpy()
    valid_positions = np.where(np.isfinite(psar_all))[0]
    if valid_positions.size == 0:
        print("ERROR: dump has no computed MQL5 PSAR to align on", file=sys.stderr)
        return 2
    first_valid = int(valid_positions[0])
    if first_valid > 0:
        dump = dump.iloc[first_valid:].reset_index(drop=True)

    #--- Indicators need valid floats; the dump leaves not-ready prices blank.
    numeric_dump = dump.copy()
    for column in ("open", "high", "low", "close"):
        numeric_dump[column] = _to_number(dump[column])
    bars = numeric_dump[["bar_open_time", "open", "high", "low", "close"]].copy()
    bars["tick_volume"] = _to_number(dump.get("tick_volume", pd.Series(
        np.zeros(len(dump)))))

    config = WonderwhalesConfig(
        mode=MODES[args.mode],
        psar_start=args.psar_start, psar_inc=args.psar_inc,
        psar_max=args.psar_max, fast_ema=args.fast, slow_ema=args.slow,
        ema200=args.ema200, atr_len=args.atr_len,
        min_atr_pct=args.min_atr_pct, vol_ma_len=args.vol_ma_len,
        rsi_len=args.rsi_len, bb_len=args.bb_len, bb_mult=args.bb_mult,
    )
    try:
        python_side = generate_bars(bars, config)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    mql5_dir = _to_number(dump["sar_dir"]).astype("Int64")
    mql5_buy = _to_number(dump["buy_signal"]).fillna(0) > 0.5
    mql5_sell = _to_number(dump["sell_signal"]).fillna(0) > 0.5
    mql5_blocked_buy = _to_number(dump["blocked_buy"]).fillna(0) > 0.5
    mql5_blocked_sell = _to_number(dump["blocked_sell"]).fillna(0) > 0.5

    start = min(args.warmup_bars, len(dump))
    sl = slice(start, len(dump))
    times = dump["bar_open_time"].to_numpy()[sl]

    exact: dict[str, dict] = {}
    for name, mql5_values, py_values in (
        ("sar_dir", mql5_dir.to_numpy()[sl],
         python_side["sar_dir"].to_numpy()[sl]),
        ("buy_signal", mql5_buy.to_numpy()[sl],
         python_side["signal_buy"].to_numpy()[sl]),
        ("sell_signal", mql5_sell.to_numpy()[sl],
         python_side["signal_sell"].to_numpy()[sl]),
        ("blocked_buy", mql5_blocked_buy.to_numpy()[sl],
         python_side["blocked_buy"].to_numpy()[sl]),
        ("blocked_sell", mql5_blocked_sell.to_numpy()[sl],
         python_side["blocked_sell"].to_numpy()[sl]),
    ):
        #--- NaN on the MQL5 side means "not computed"; skip those rows.
        valid = ~pd.isna(mql5_values)
        compared = int(valid.sum())
        matches = int(np.sum(np.asarray(py_values)[valid]
                             == np.asarray(mql5_values)[valid]))
        mismatched_times = [str(t) for t, ok in
                            zip(times[valid], (np.asarray(py_values)[valid]
                                               == np.asarray(mql5_values)[valid]))
                            if not ok][:5]
        exact[name] = {
            "compared": compared,
            "matches": matches,
            "match_rate": (matches / compared) if compared else None,
            "first_mismatches": mismatched_times,
        }

    numeric: dict[str, dict] = {}
    for name, column in (("psar", "psar"), ("fast", "fast"), ("slow", "slow")):
        mql5_values = _to_number(dump[column]).to_numpy()[sl]
        py_values = python_side[column].to_numpy()[sl]
        both = (~pd.isna(mql5_values)) & np.isfinite(py_values)
        compared = int(both.sum())
        if compared == 0:
            numeric[name] = {"compared": 0, "max_abs_diff": None,
                             "within_tolerance": None, "tolerance": None}
            continue
        diff = np.abs(py_values[both] - mql5_values[both])
        numeric[name] = {
            "compared": compared,
            "max_abs_diff": float(diff.max()),
            "within_tolerance": int((diff <= args.tolerance_price).sum()),
            "tolerance": args.tolerance_price,
        }

    report = {
        "label": "CROSS_IMPLEMENTATION",
        "note": "NOT Pine parity; do not use to unblock InpRequireParity",
        "dump": str(dump_path),
        "symbol": str(dump["symbol"].iloc[0]) if "symbol" in dump else None,
        "timeframe": str(dump["timeframe"].iloc[0]) if "timeframe" in dump else None,
        "mode": args.mode,
        "aligned_from_row": first_valid,
        "bars": int(len(dump)),
        "skipped": int(start),
        "compared": int(len(dump) - start),
        "exact_match": exact,
        "numeric": numeric,
    }

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / f"port_check_{report['timeframe']}.json"
    json_path.write_text(json.dumps(report, indent=2), encoding="utf-8")

    print(explain(report))
    print(f"report_json={json_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
