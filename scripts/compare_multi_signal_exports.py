"""Compare a Pine reference export with the MQL5 multi-source signal log.

Exit codes:
    0  every signal matched
    1  at least one mismatch was reported
    2  an argument or CSV schema was invalid
    3  blocked: one of the two exports does not exist

This script never creates reference data. When the Pine export is missing it
reports ``BLOCKED`` instead of inventing rows.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

from mt5_ea_ai_lab.evaluation.multi_source_parity import (
    compare_multi_source_exports,
    write_parity_report,
)
from mt5_ea_ai_lab.evaluation.pine_parity import PineParityError

EXIT_MATCH = 0
EXIT_MISMATCH = 1
EXIT_INVALID = 2
EXIT_BLOCKED = 3


def _resolve(path_value: str) -> Path:
    candidate = Path(path_value)
    return candidate if candidate.is_absolute() else (REPO_ROOT / candidate)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Compare a Pine reference export with the unified CSV written by "
            "PineMultiSignalLabEA."
        )
    )
    parser.add_argument("--reference", required=True, help="Pine reference CSV")
    parser.add_argument("--mql5", required=True, help="CSV written by PineMultiSignalLabEA")
    parser.add_argument(
        "--out-dir",
        default="reports/multi_source_parity",
        help="directory for the JSON and mismatch CSV reports",
    )
    parser.add_argument(
        "--tolerance-price",
        type=float,
        default=1e-8,
        help="absolute tolerance for entry/sl/tp1..3 (default: 1e-8)",
    )
    parser.add_argument(
        "--tolerance-score",
        type=float,
        default=1e-6,
        help="absolute tolerance for score (default: 1e-6)",
    )
    parser.add_argument(
        "--reference-offset-minutes",
        type=float,
        default=0.0,
        help="server offset east of UTC for the reference file (default: 0)",
    )
    parser.add_argument(
        "--mql5-offset-minutes",
        type=float,
        default=0.0,
        help="broker server offset east of UTC for the MQL5 file, e.g. GMT+3 = 180",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    reference_path = _resolve(args.reference)
    mql5_path = _resolve(args.mql5)
    out_dir = _resolve(args.out_dir)

    for label, path in (("reference", reference_path), ("mql5", mql5_path)):
        if not path.is_file():
            print(
                f"parity=BLOCKED reason={label}_file_missing path={path}",
                file=sys.stderr,
            )
            return EXIT_BLOCKED

    try:
        report = compare_multi_source_exports(
            reference_path,
            mql5_path,
            tolerance_price=args.tolerance_price,
            tolerance_score=args.tolerance_score,
            reference_offset_minutes=args.reference_offset_minutes,
            mql5_offset_minutes=args.mql5_offset_minutes,
        )
        json_path, csv_path = write_parity_report(report, out_dir)
    except (PineParityError, OSError) as exc:
        print(f"comparison_error: {exc}", file=sys.stderr)
        return EXIT_INVALID

    print(
        f"status={report.status} rows_reference={report.rows_reference} "
        f"rows_mql5={report.rows_mql5} rows_compared={report.rows_compared} "
        f"mismatches={report.mismatch_count} "
        f"tolerance_price={report.tolerance_price} "
        f"tolerance_score={report.tolerance_score} "
        f"mql5_offset_minutes={report.mql5_offset_minutes:g}"
    )
    for summary in report.sources:
        print(
            f"source={summary.source} reference={summary.reference_rows} "
            f"mql5={summary.mql5_rows} compared={summary.compared_rows} "
            f"mismatches={summary.mismatch_count}"
        )
    print(f"report_json={json_path}")
    print(f"report_csv={csv_path}")
    return EXIT_MATCH if report.status == "match" else EXIT_MISMATCH


if __name__ == "__main__":
    raise SystemExit(main())
