"""Audit the signal CSV written by the MQL5 Wonderwhales EA.

Exit codes:
    0  the export is structurally consistent
    1  at least one issue was found
    2  the file is missing or cannot be validated

This does not compare against Pine. Use ``compare_pine_exports.py`` for parity.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

from mt5_ea_ai_lab.evaluation.pine_parity import PineParityError
from mt5_ea_ai_lab.evaluation.signal_audit import (
    audit_signal_csv,
    write_audit_report,
)


def _resolve(path_value: str) -> Path:
    candidate = Path(path_value)
    return candidate if candidate.is_absolute() else (REPO_ROOT / candidate)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Check structural consistency of an EA signal CSV."
    )
    parser.add_argument(
        "--csv",
        required=True,
        help="CSV written by PineSignalLabEA (MQL5/Files/...)",
    )
    parser.add_argument(
        "--out-dir",
        default="reports/signal_audit",
        help="directory for signal_audit.json",
    )
    parser.add_argument(
        "--offset-minutes",
        type=float,
        default=0.0,
        help="broker server offset east of UTC, e.g. GMT+3 = 180 (default: 0)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    csv_path = _resolve(args.csv)
    out_dir = _resolve(args.out_dir)

    try:
        report = audit_signal_csv(csv_path, offset_minutes=args.offset_minutes)
        json_path = write_audit_report(report, out_dir)
    except (PineParityError, OSError) as exc:
        print(f"audit_error: {exc}", file=sys.stderr)
        return 2

    signals = ",".join(f"{key}={value}" for key, value in report.signal_counts.items())
    sides = ",".join(f"{key}={value}" for key, value in report.side_counts.items())
    print(
        f"status={report.status} rows={report.rows} "
        f"first_bar={report.first_bar} last_bar={report.last_bar} "
        f"symbols={'/'.join(report.symbols)} "
        f"timeframes={'/'.join(report.timeframes)} "
        f"signals={signals} sides={sides} "
        f"empty_price_cells={report.empty_price_cells} "
        f"issues={len(report.issues)}"
    )
    for issue in report.issues:
        print(f"issue kind={issue.kind} detail={issue.detail}")
    print(f"report_json={json_path}")
    return 0 if report.status == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
