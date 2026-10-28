"""Validate an OHLCV dataset and write JSON/CSV reports.

Exit codes:
    0  validation passed (warnings allowed)
    1  dataset could not be loaded
    2  validation found errors
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

from mt5_ea_ai_lab.data.loader import DATA_KINDS, DataLoadError, load_ohlcv
from mt5_ea_ai_lab.validation import validate_ohlcv


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate an OHLCV CSV/Parquet file without modifying it."
    )
    parser.add_argument("path", help="dataset file (.csv, .parquet, .pq)")
    parser.add_argument("--symbol", default=None, help="expected symbol, e.g. EURUSD")
    parser.add_argument("--timeframe", default=None, help="expected timeframe, e.g. M5")
    parser.add_argument(
        "--tz",
        default="UTC",
        help="timezone for timestamps without an offset (default: UTC)",
    )
    parser.add_argument(
        "--data-kind",
        choices=DATA_KINDS,
        default="unknown",
        help="label the dataset; use 'synthetic' for generated fixtures",
    )
    parser.add_argument(
        "--expected-step-seconds",
        type=float,
        default=None,
        help="expected bar spacing in seconds; inferred from the data when omitted",
    )
    parser.add_argument(
        "--max-gap-factor",
        type=float,
        default=3.0,
        help="flag gaps larger than this multiple of the expected step",
    )
    parser.add_argument(
        "--out-dir",
        default=str(REPO_ROOT / "reports" / "validation"),
        help="directory for the JSON/CSV reports",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    try:
        frame, metadata = load_ohlcv(
            args.path,
            symbol=args.symbol,
            timeframe=args.timeframe,
            timezone=args.tz,
            data_kind=args.data_kind,
        )
    except (DataLoadError, FileNotFoundError, OSError) as exc:
        print(f"load_error: {exc}", file=sys.stderr)
        return 1

    report = validate_ohlcv(
        frame,
        metadata=metadata,
        expected_step=args.expected_step_seconds,
        max_gap_factor=args.max_gap_factor,
    )

    source = Path(args.path)
    out_dir = Path(args.out_dir)
    json_path = report.to_json(out_dir / f"{source.stem}.validation.json")
    csv_path = report.to_csv(out_dir / f"{source.stem}.validation.csv")

    print(
        f"dataset={source} rows={report.row_count} "
        f"errors={len(report.errors)} warnings={len(report.warnings)} "
        f"passed={report.passed}"
    )
    for issue in report.issues:
        print(f"{issue.severity.upper()} {issue.code}: {issue.message} ({issue.count})")
    print(f"json={json_path}")
    print(f"csv={csv_path}")

    return 0 if report.passed else 2


if __name__ == "__main__":
    raise SystemExit(main())
