"""Compare MQL5 and Python signal exports.

Exit codes:
    0  all rows match
    1  at least one mismatch was reported
    2  an input file or argument was invalid

Signals and reasons must match exactly. Numeric fields use an absolute
tolerance. Reports are written as mismatch_report.json and
mismatch_report.csv in --out-dir.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

from mt5_ea_ai_lab.evaluation.parity import (
    SignalComparisonError,
    compare_signal_files,
    write_report,
)


def _resolve(path_value: str) -> Path:
    candidate = Path(path_value)
    return candidate if candidate.is_absolute() else (REPO_ROOT / candidate)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Compare MQL5 and Python signal CSV exports."
    )
    parser.add_argument("--mql5", required=True, help="signal CSV produced by MQL5")
    parser.add_argument("--python", required=True, help="signal CSV produced by Python")
    parser.add_argument(
        "--out-dir",
        default="reports/parity",
        help="directory for mismatch_report.json and .csv",
    )
    parser.add_argument(
        "--tolerance",
        type=float,
        default=1e-9,
        help="absolute tolerance for numeric fields (default: 1e-9)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    mql5_path = _resolve(args.mql5)
    python_path = _resolve(args.python)
    out_dir = _resolve(args.out_dir)

    try:
        report = compare_signal_files(
            mql5_path,
            python_path,
            tolerance=args.tolerance,
        )
        json_path, csv_path = write_report(report, out_dir)
    except (SignalComparisonError, OSError) as exc:
        print(f"comparison_error: {exc}", file=sys.stderr)
        return 2

    print(
        f"status={report.status} rows_mql5={report.rows_mql5} "
        f"rows_python={report.rows_python} rows_compared={report.rows_compared} "
        f"mismatches={report.mismatch_count} tolerance={report.tolerance}"
    )
    print(f"report_json={json_path}")
    print(f"report_csv={csv_path}")
    return 0 if report.status == "match" else 1


if __name__ == "__main__":
    raise SystemExit(main())
