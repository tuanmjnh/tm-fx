"""Compare two stored runs and write reproducible comparison artifacts.

Comparability is deliberately strict: both runs must be completed, use the
same semantic configuration, the same dataset bytes and the same code version.
A warning is still emitted for a dirty worktree, synthetic data or unknown
git state, because those weaken the strength of any conclusion.
"""

from __future__ import annotations

import csv
import json
import math
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping

from mt5_ea_ai_lab.experiment_store.store import STATUS_COMPLETED

COMPARISON_METRICS: tuple[str, ...] = (
    "bars",
    "final_equity",
    "net_profit",
    "total_return",
    "trade_count",
    "win_rate",
    "profit_factor",
    "average_trade",
    "max_drawdown",
    "max_drawdown_pct",
    "exposure_ratio",
    "total_commission",
)


class ComparisonError(ValueError):
    """Raised when a run record cannot be compared."""


def _as_mapping(value: Any) -> dict[str, Any]:
    if isinstance(value, Mapping):
        return dict(value)
    to_dict = getattr(value, "to_dict", None)
    if callable(to_dict):
        result = to_dict()
        if isinstance(result, Mapping):
            return dict(result)
    raise ComparisonError("run must be a mapping or expose to_dict()")


def _is_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _finite_or_none(value: Any) -> Any:
    return value if _is_number(value) else None


def _metric_row(name: str, baseline: Any, run: Any) -> dict[str, Any]:
    baseline_value = baseline if _is_number(baseline) else None
    run_value = run if _is_number(run) else None
    delta = None
    delta_pct = None
    if baseline_value is not None and run_value is not None:
        delta = run_value - baseline_value
        if baseline_value != 0:
            delta_pct = float(delta) / float(baseline_value)
    return {
        "metric": name,
        "baseline": baseline_value,
        "run": run_value,
        "delta": delta,
        "delta_pct": delta_pct,
    }


def _summary(record: Mapping[str, Any]) -> dict[str, Any]:
    metrics = record.get("metrics")
    if not isinstance(metrics, Mapping):
        metrics = {}
    return {
        "experiment_id": record.get("experiment_id"),
        "status": record.get("status"),
        "config_hash": record.get("config_hash"),
        "data_fingerprint": record.get("data_fingerprint"),
        "data_kind": record.get("data_kind"),
        "symbol": record.get("symbol"),
        "timeframe": record.get("timeframe"),
        "code_version": record.get("code_version"),
        "git_commit": record.get("git_commit"),
        "git_dirty": record.get("git_dirty"),
        "metrics": {
            name: _finite_or_none(metrics.get(name))
            for name in COMPARISON_METRICS
            if name in metrics
        },
    }


def compare_runs(baseline: Any, run: Any) -> dict[str, Any]:
    base = _as_mapping(baseline)
    candidate = _as_mapping(run)
    reasons: list[str] = []
    warnings: list[str] = []

    base_id = str(base.get("experiment_id") or "<baseline>")
    run_id = str(candidate.get("experiment_id") or "<run>")

    for label, record in (("baseline", base), ("run", candidate)):
        if record.get("status") != STATUS_COMPLETED:
            reasons.append(f"{label}_status:{record.get('status')}")
        if not isinstance(record.get("metrics"), Mapping):
            reasons.append(f"{label}_missing_metrics")

    if (
        not base.get("config_hash")
        or not candidate.get("config_hash")
        or base.get("config_hash") != candidate.get("config_hash")
    ):
        reasons.append("config_hash_mismatch")
    if (
        not base.get("data_fingerprint")
        or not candidate.get("data_fingerprint")
        or base.get("data_fingerprint") != candidate.get("data_fingerprint")
    ):
        reasons.append("data_fingerprint_mismatch")
    if (
        not base.get("code_version")
        or not candidate.get("code_version")
        or base.get("code_version") != candidate.get("code_version")
    ):
        reasons.append("code_version_mismatch")
    if (
        base.get("git_commit")
        and candidate.get("git_commit")
        and base.get("git_commit") != candidate.get("git_commit")
    ):
        reasons.append("git_commit_mismatch")

    if base.get("git_dirty") is True:
        warnings.append(f"dirty_worktree:{base_id}")
    if candidate.get("git_dirty") is True:
        warnings.append(f"dirty_worktree:{run_id}")
    if not base.get("git_commit") or not candidate.get("git_commit"):
        warnings.append("unknown_git_commit")
    if "synthetic" in {base.get("data_kind"), candidate.get("data_kind")}:
        warnings.append("synthetic_data")

    base_metrics_raw = base.get("metrics")
    run_metrics_raw = candidate.get("metrics")
    base_metrics = base_metrics_raw if isinstance(base_metrics_raw, Mapping) else {}
    run_metrics = run_metrics_raw if isinstance(run_metrics_raw, Mapping) else {}
    metrics_rows = [
        _metric_row(name, base_metrics.get(name), run_metrics.get(name))
        for name in COMPARISON_METRICS
        if name in base_metrics or name in run_metrics
    ]

    return {
        "status": "not_comparable" if reasons else "comparable",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "baseline": _summary(base),
        "run": _summary(candidate),
        "reasons": reasons,
        "warnings": warnings,
        "metrics": metrics_rows,
    }


def _format_cell(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return format(value, ".12g")
    return str(value)


def compare_ids(baseline_id: str, run_id: str) -> str:
    """Stable, filesystem-safe directory name for a comparison."""

    return f"{baseline_id}__vs__{run_id}"


def _markdown(report: Mapping[str, Any]) -> str:
    base = report["baseline"]
    candidate = report["run"]
    lines = [
        "# Experiment comparison",
        "",
        f"- **Status:** `{report['status']}`",
        f"- **Baseline:** `{base.get('experiment_id')}` ({base.get('status')})",
        f"- **Run:** `{candidate.get('experiment_id')}` ({candidate.get('status')})",
        f"- **Generated (UTC):** {report['generated_at_utc']}",
        f"- **Data kind:** baseline `{base.get('data_kind')}`, "
        f"run `{candidate.get('data_kind')}`",
        "",
    ]
    if report["reasons"]:
        lines.extend(["## Blocking reasons", ""])
        lines.extend(f"- `{reason}`" for reason in report["reasons"])
        lines.append("")
    if report["warnings"]:
        lines.extend(["## Warnings", ""])
        lines.extend(f"- `{warning}`" for warning in report["warnings"])
        lines.append("")
    lines.extend(
        [
            "## Metrics",
            "",
            "Delta is `run - baseline`; percentage delta is relative to baseline.",
            "",
            "| Metric | Baseline | Run | Delta | Delta % |",
            "|---|---:|---:|---:|---:|",
        ]
    )
    for row in report["metrics"]:
        delta_pct = row["delta_pct"]
        delta_pct_text = (
            format(delta_pct * 100.0, ".6g") + "%" if delta_pct is not None else ""
        )
        lines.append(
            f"| {row['metric']} | {_format_cell(row['baseline'])} | "
            f"{_format_cell(row['run'])} | {_format_cell(row['delta'])} | "
            f"{delta_pct_text} |"
        )
    lines.extend(
        [
            "",
            "> Generated from stored metadata. Comparable runs are not evidence of "
            "future performance.",
            "",
        ]
    )
    return "\n".join(lines)


def write_comparison(
    report: Mapping[str, Any],
    out_dir: str | Path,
) -> dict[str, Path]:
    destination = Path(out_dir)
    destination.mkdir(parents=True, exist_ok=True)

    json_path = destination / "comparison.json"
    csv_path = destination / "comparison.csv"
    markdown_path = destination / "comparison.md"

    json_path.write_text(
        json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )

    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(("metric", "baseline", "run", "delta", "delta_pct"))
        for row in report["metrics"]:
            writer.writerow(
                (
                    row["metric"],
                    _format_cell(row["baseline"]),
                    _format_cell(row["run"]),
                    _format_cell(row["delta"]),
                    _format_cell(row["delta_pct"]),
                )
            )

    markdown_path.write_text(_markdown(report), encoding="utf-8")

    return {
        "json": json_path,
        "csv": csv_path,
        "markdown": markdown_path,
    }
