"""Compare two stored experiment runs and write JSON/CSV/Markdown artifacts.

Exit codes:
    0  runs are comparable
    1  runs are not comparable (see reasons)
    2  database or run metadata could not be read

The command is read-only: it never modifies the database or the compared runs.
"""

from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

from mt5_ea_ai_lab.experiment_store import (  # noqa: E402
    ExperimentStore,
    StoreError,
    compare_ids,
    compare_runs,
    validate_experiment_id,
    write_comparison,
)


def _resolve(path_value: str, base: Path) -> Path:
    candidate = Path(path_value)
    return candidate if candidate.is_absolute() else (base / candidate)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Compare two experiment runs stored in SQLite."
    )
    parser.add_argument(
        "--db",
        default=str(REPO_ROOT / "experiments" / "experiments.sqlite"),
        help="SQLite experiment database",
    )
    parser.add_argument("--baseline", required=True, help="baseline experiment ID")
    parser.add_argument("--run", required=True, help="candidate experiment ID")
    parser.add_argument(
        "--out-dir",
        default=None,
        help=(
            "comparison output directory; defaults to "
            "reports/comparisons/<baseline>__vs__<run>"
        ),
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    try:
        baseline_id = validate_experiment_id(args.baseline)
        run_id = validate_experiment_id(args.run)
    except ValueError as exc:
        print(f"input_error: {exc}", file=sys.stderr)
        return 2

    db_path = _resolve(args.db, REPO_ROOT)
    if not db_path.is_file():
        print(f"store_error: database not found: {db_path}", file=sys.stderr)
        return 2

    out_dir = _resolve(
        args.out_dir or f"reports/comparisons/{compare_ids(baseline_id, run_id)}",
        REPO_ROOT,
    )

    try:
        with ExperimentStore(db_path) as store:
            baseline = store.get_run(baseline_id)
            run = store.get_run(run_id)
    except (StoreError, OSError, sqlite3.Error) as exc:
        print(f"store_error: {exc}", file=sys.stderr)
        return 2

    missing = [
        name
        for name, record in ((baseline_id, baseline), (run_id, run))
        if record is None
    ]
    if missing:
        for name in missing:
            print(f"run_not_found: {name}", file=sys.stderr)
        return 2

    report = compare_runs(baseline, run)
    try:
        artifacts = write_comparison(report, out_dir)
    except OSError as exc:
        print(f"write_error: {exc}", file=sys.stderr)
        return 2

    reasons = report["reasons"]
    warnings = report["warnings"]
    print(
        f"comparison={report['status']} baseline={baseline_id} run={run_id} "
        f"reasons={len(reasons)} warnings={len(warnings)}"
    )
    for reason in reasons:
        print(f"reason={reason}")
    for warning in warnings:
        print(f"warning={warning}")
    print(f"report_json={artifacts['json']}")
    print(f"report_csv={artifacts['csv']}")
    print(f"report_markdown={artifacts['markdown']}")
    return 0 if report["status"] == "comparable" else 1


if __name__ == "__main__":
    raise SystemExit(main())
