"""Compare Pine reference signals with the MQL5 Wonderwhales EA log.

Exit codes:
    0  every signal matched
    1  at least one mismatch was reported
    2  an input file or argument was invalid

The Pine CSV must use the schema documented in
``docs/BUFFER_CONTRACT_Wonderwhales.md``. This script does not create or alter
reference data; it only compares two existing exports.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

from mt5_ea_ai_lab.evaluation.pine_parity import (
    PineParityError,
    compare_pine_exports,
    write_report,
)


def _resolve(path_value: str) -> Path:
    candidate = Path(path_value)
    return candidate if candidate.is_absolute() else (REPO_ROOT / candidate)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Compare Pine reference signals with the MQL5 Wonderwhales EA log."
    )
    parser.add_argument("--pine", required=True, help="reference CSV exported from Pine")
    parser.add_argument("--mql5", required=True, help="CSV written by PineSignalLabEA")
    parser.add_argument(
        "--out-dir",
        default="reports/pine_parity",
        help="directory for pine_mismatch_report.json and .csv",
    )
    parser.add_argument(
        "--tolerance-price",
        type=float,
        default=1e-8,
        help="absolute tolerance for psar/fast/slow (default: 1e-8)",
    )
    parser.add_argument(
        "--tolerance-oscillator",
        type=float,
        default=1e-6,
        help="absolute tolerance for atr_pct (default: 1e-6)",
    )
    parser.add_argument(
        "--pine-offset-minutes",
        type=float,
        default=0.0,
        help="server offset east of UTC for the Pine file (default: 0)",
    )
    parser.add_argument(
        "--mql5-offset-minutes",
        type=float,
        default=0.0,
        help="broker server offset east of UTC for the MQL5 file, e.g. GMT+3 = 180",
    )
    parser.add_argument(
        "--start",
        default=None,
        help="ignore rows whose bar_open_time is earlier than this timestamp",
    )
    parser.add_argument(
        "--warmup-bars",
        type=int,
        default=0,
        help="drop the first N bar times from both exports",
    )
    parser.add_argument(
        "--bar-times",
        default=None,
        help="CSV with a bar_open_time column; required when --warmup-bars > 0",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    pine_path = _resolve(args.pine)
    mql5_path = _resolve(args.mql5)
    out_dir = _resolve(args.out_dir)
    bar_times = _resolve(args.bar_times) if args.bar_times else None

    try:
        report = compare_pine_exports(
            pine_path,
            mql5_path,
            tolerance_price=args.tolerance_price,
            tolerance_oscillator=args.tolerance_oscillator,
            pine_offset_minutes=args.pine_offset_minutes,
            mql5_offset_minutes=args.mql5_offset_minutes,
            start=args.start,
            warmup_bars=args.warmup_bars,
            bar_times_path=bar_times,
        )
        json_path, csv_path = write_report(report, out_dir)
    except (PineParityError, OSError) as exc:
        print(f"comparison_error: {exc}", file=sys.stderr)
        return 2

    print(
        f"status={report.status} rows_pine={report.rows_pine} "
        f"rows_mql5={report.rows_mql5} rows_compared={report.rows_compared} "
        f"mismatches={report.mismatch_count} "
        f"tolerance_price={report.tolerance_price} "
        f"tolerance_oscillator={report.tolerance_oscillator} "
        f"input_hash_checked={int(report.input_hash_checked)} "
        f"mql5_offset_minutes={report.mql5_offset_minutes:g}"
    )
    print(f"report_json={json_path}")
    print(f"report_csv={csv_path}")
    return 0 if report.status == "match" else 1


if __name__ == "__main__":
    raise SystemExit(main())
