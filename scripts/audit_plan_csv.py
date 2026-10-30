"""Audit the simulation journal written by PinePlanSimEA.

Exit codes:
    0  the journal is structurally consistent
    1  at least one issue was found
    2  the file is missing or cannot be validated

Checks are structural (header, INIT/SUMMARY framing, ENTRY/EXIT pairing, stop
and target geometry, SUMMARY counters). Net figures are model units; this says
nothing about profitability and never compares against Pine.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

from mt5_ea_ai_lab.evaluation.pine_parity import PineParityError
from mt5_ea_ai_lab.evaluation.plan_audit import (
    audit_plan_csv,
    write_audit_report,
)


def _resolve(path_value: str) -> Path:
    candidate = Path(path_value)
    return candidate if candidate.is_absolute() else (REPO_ROOT / candidate)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Check structural consistency of a PinePlanSimEA journal."
    )
    parser.add_argument(
        "--csv",
        required=True,
        help="sim_plan_*.csv written by PinePlanSimEA",
    )
    parser.add_argument(
        "--out-dir",
        default="reports/plan_audit",
        help="directory for plan_audit.json",
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
        report = audit_plan_csv(csv_path, offset_minutes=args.offset_minutes)
        json_path = write_audit_report(report, out_dir)
    except (PineParityError, OSError) as exc:
        print(f"audit_error: {exc}", file=sys.stderr)
        return 2

    events = ",".join(f"{k}={v}" for k, v in report.event_counts.items())
    sides = ",".join(f"{k}={v}" for k, v in report.entry_side_counts.items()) or "none"
    exits = ",".join(f"{k}={v}" for k, v in report.exit_reason_counts.items()) or "none"
    print(
        f"status={report.status} rows={report.rows} "
        f"hash={'/'.join(report.config_hashes)} "
        f"symbols={'/'.join(report.symbols)} "
        f"timeframes={'/'.join(report.timeframes)} "
        f"first_bar={report.first_bar} last_bar={report.last_bar} "
        f"events={events} entry_sides={sides} exit_reasons={exits} "
        f"open_at_end={int(report.open_position_at_end)} "
        f"net={report.summary.get('net', '')} issues={len(report.issues)}"
    )
    for issue in report.issues:
        print(f"issue kind={issue.kind} detail={issue.detail}")
    print(f"report_json={json_path}")
    return 0 if report.status == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
