"""Run the Phase 9 end-to-end research pipeline from one command.

Stages:
    1. backtest  validate data and run the EMA-crossover simulation
    2. ml        build features/labels, train logistic regression, evaluate test
    3. report    combine both stage summaries into one demo report

Exit codes:
    0  both stages completed and the combined report was written
    1  pipeline config, stage config or dataset could not be loaded
    2  dataset validation failed (invalid_data)
    3  a stage failed after loading data
    4  a stage experiment ID already exists in the store
    5  the experiment store could not record a run

The pipeline never executes trades, never connects to a broker and never
claims market performance. Every report is marked as demo/synthetic when the
configured ``data_kind`` is not ``market``.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from types import ModuleType
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

from mt5_ea_ai_lab.experiment_store import sha256_file


class PipelineConfigError(ValueError):
    """Raised when the pipeline configuration is missing or inconsistent."""


def _require_mapping(value: Any, name: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise PipelineConfigError(f"{name} must be a mapping")
    return value


def _require_string(mapping: dict[str, Any], key: str, name: str) -> str:
    value = mapping.get(key)
    if not isinstance(value, str) or not value.strip():
        raise PipelineConfigError(f"{name}.{key} must be a non-empty string")
    return value.strip()


def _resolve(path_value: str) -> Path:
    candidate = Path(path_value)
    return candidate if candidate.is_absolute() else (REPO_ROOT / candidate)


def _load_script(module_name: str, filename: str) -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        module_name, REPO_ROOT / "scripts" / filename
    )
    if spec is None or spec.loader is None:
        raise PipelineConfigError(f"cannot load stage script: {filename}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_config(path: Path) -> dict[str, Any]:
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise PipelineConfigError(f"config file not found: {path}") from exc
    except yaml.YAMLError as exc:
        raise PipelineConfigError(f"cannot parse YAML config: {exc}") from exc

    config = _require_mapping(raw, "config")
    run_id = _require_string(config, "experiment_id", "config")
    backtest_config = _resolve(
        _require_string(config, "backtest_config", "config")
    )
    ml_config = _resolve(_require_string(config, "ml_config", "config"))

    outputs = _require_mapping(config.get("outputs", {}), "config.outputs")
    report_dir = _resolve(outputs.get("report_dir", "reports/pipeline"))
    store = _require_mapping(config.get("store", {}), "config.store")
    db_path = _resolve(store.get("db", "experiments/experiments.sqlite"))

    return {
        "run_id": run_id,
        "backtest_config": backtest_config,
        "ml_config": ml_config,
        "report_dir": report_dir,
        "db_path": db_path,
        "notes": config.get("notes"),
    }


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )


def _read_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise PipelineConfigError(f"stage summary not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise PipelineConfigError(f"invalid stage summary JSON: {path}") from exc


def _status_for(exit_code: int) -> str:
    return {
        0: "completed",
        1: "failed",
        2: "invalid_data",
        3: "failed",
        4: "duplicate_experiment",
        5: "store_error",
    }.get(exit_code, "failed")


def _backtest_metrics(summary: dict[str, Any]) -> dict[str, Any]:
    metrics = summary.get("metrics") or {}
    return {
        "bars": metrics.get("bars"),
        "trade_count": metrics.get("trade_count"),
        "final_equity": metrics.get("final_equity"),
        "net_profit": metrics.get("net_profit"),
        "total_return": metrics.get("total_return"),
        "max_drawdown": metrics.get("max_drawdown"),
        "profit_factor": metrics.get("profit_factor"),
        "exposure_ratio": metrics.get("exposure_ratio"),
    }


def _ml_metrics(summary: dict[str, Any]) -> dict[str, Any]:
    classification = summary.get("classification") or {}
    test = classification.get("test") or {}
    strategy = summary.get("strategy") or {}
    ml_strategy = (strategy.get("ml") or {}).get("metrics") or {}
    buy_hold = strategy.get("buy_and_hold") or {}
    return {
        "test_samples": test.get("samples"),
        "test_roc_auc": test.get("roc_auc"),
        "test_balanced_accuracy": test.get("balanced_accuracy"),
        "test_accuracy": test.get("accuracy"),
        "threshold": summary.get("threshold", {}).get("threshold"),
        "ml_trades": ml_strategy.get("trade_count"),
        "ml_net_profit": ml_strategy.get("net_profit"),
        "buy_hold_net_profit": buy_hold.get("net_pnl"),
        "warnings": summary.get("warnings") or [],
    }


def _stage_record(
    stage_name: str,
    exit_code: int,
    experiment_id: str,
    summary_path: Path,
    report_dir: Path,
) -> dict[str, Any]:
    record: dict[str, Any] = {
        "experiment_id": experiment_id,
        "exit_code": exit_code,
        "status": _status_for(exit_code),
        "report_dir": str(report_dir),
        "summary_path": str(summary_path),
    }
    if summary_path.is_file():
        record["summary_sha256"] = sha256_file(summary_path)
        summary = _read_json(summary_path)
        record["error"] = summary.get("error")
        if stage_name == "backtest":
            record["metrics"] = _backtest_metrics(summary)
            record["benchmark"] = summary.get("benchmark")
        else:
            record["metrics"] = _ml_metrics(summary)
            record["model_sha256"] = summary.get("model_sha256")
    return record


def _render_markdown(payload: dict[str, Any]) -> str:
    stages = payload["stages"]
    backtest = stages.get("backtest", {})
    ml = stages.get("ml", {})
    backtest_metrics = backtest.get("metrics") or {}
    ml_metrics = ml.get("metrics") or {}

    def value(item: Any) -> str:
        if item is None:
            return "n/a"
        if isinstance(item, float):
            return f"{item:.4f}"
        return str(item)

    lines = [
        f"# End-to-end pipeline — {payload['run_id']}",
        "",
        f"- **Status:** `{payload['status']}`",
        f"- **Generated (UTC):** {payload['generated_at_utc']}",
        f"- **Data:** `{payload['data']['path']}` "
        f"({payload['data']['data_kind']}, {payload['data']['symbol']} "
        f"{payload['data']['timeframe']})",
        f"- **Data SHA-256:** `{payload['data']['sha256']}`",
        f"- **Demo:** {'yes' if payload['demo'] else 'no'} — "
        "synthetic or fixture data is not market performance.",
        "",
        "## Stages",
        "",
        "| Stage | Experiment ID | Status | Exit | Report |",
        "|---|---|---|---|---|",
    ]
    for name in ("backtest", "ml"):
        stage = stages.get(name, {})
        lines.append(
            f"| {name} | `{stage.get('experiment_id', 'n/a')}` | "
            f"`{stage.get('status', 'n/a')}` | {stage.get('exit_code', 'n/a')} | "
            f"`{stage.get('report_dir', 'n/a')}` |"
        )
    if payload.get("error"):
        lines.extend(["", f"**Error:** `{payload['error']}`"])

    lines.extend(
        [
            "",
            "## Backtest — EMA crossover",
            "",
            "| Metric | Value |",
            "|---|---|",
            f"| Bars | {value(backtest_metrics.get('bars'))} |",
            f"| Trades | {value(backtest_metrics.get('trade_count'))} |",
            f"| Final equity | {value(backtest_metrics.get('final_equity'))} |",
            f"| Net profit | {value(backtest_metrics.get('net_profit'))} |",
            f"| Total return | {value(backtest_metrics.get('total_return'))} |",
            f"| Max drawdown | {value(backtest_metrics.get('max_drawdown'))} |",
            f"| Profit factor | {value(backtest_metrics.get('profit_factor'))} |",
            f"| Exposure | {value(backtest_metrics.get('exposure_ratio'))} |",
            "",
            "## ML baseline — logistic regression",
            "",
            "| Metric | Value |",
            "|---|---|",
            f"| Test samples | {value(ml_metrics.get('test_samples'))} |",
            f"| Threshold | {value(ml_metrics.get('threshold'))} |",
            f"| Test ROC-AUC | {value(ml_metrics.get('test_roc_auc'))} |",
            f"| Test balanced accuracy | {value(ml_metrics.get('test_balanced_accuracy'))} |",
            f"| Test accuracy | {value(ml_metrics.get('test_accuracy'))} |",
            f"| ML trades | {value(ml_metrics.get('ml_trades'))} |",
            f"| ML net profit | {value(ml_metrics.get('ml_net_profit'))} |",
            f"| Buy & hold net profit | {value(ml_metrics.get('buy_hold_net_profit'))} |",
            "",
            "## Limitations",
            "",
        ]
    )
    lines.extend(f"- {item}" for item in payload["limitations"])
    warnings = ml_metrics.get("warnings") or []
    if warnings:
        lines.extend(["", "ML warnings:", ""])
        lines.extend(f"- `{warning}`" for warning in warnings)
    lines.extend(
        [
            "",
            "## Reproduce",
            "",
            "```powershell",
            ".\\venv\\Scripts\\python.exe scripts\\run_pipeline.py "
            f"--config <pipeline.yaml> --run-id {payload['run_id']}",
            "```",
            "",
            "Re-running with the same config and dataset must produce the same model hash and "
            "metrics; a new `--run-id` is required because experiment IDs are immutable.",
            "",
        ]
    )
    return "\n".join(lines)


def _stage_args(
    *,
    config_path: Path,
    experiment_id: str,
    report_dir: Path,
    db_path: Path,
) -> list[str]:
    return [
        "--config",
        str(config_path),
        "--store",
        "--db",
        str(db_path),
        "--experiment-id",
        experiment_id,
        "--out-dir",
        str(report_dir),
    ]


def _validate_stage_configs(
    backtest_module: ModuleType,
    ml_module: ModuleType,
    config: dict[str, Any],
) -> None:
    try:
        backtest_config = backtest_module.load_config(config["backtest_config"])
        ml_config = ml_module.load_config(config["ml_config"])
    except Exception as exc:  # stage loaders raise their own config error types
        raise PipelineConfigError(f"stage config error: {exc}") from exc

    backtest_data = _resolve(backtest_config["data_path"]).resolve()
    ml_data = _resolve(ml_config["data_path"]).resolve()
    if backtest_data != ml_data:
        raise PipelineConfigError(
            "backtest and ML stages must use the same dataset: "
            f"{backtest_data} != {ml_data}"
        )
    for key in ("data_kind", "symbol", "timeframe"):
        if backtest_config[key] != ml_config[key]:
            raise PipelineConfigError(
                f"backtest and ML configs disagree on data.{key}: "
                f"{backtest_config[key]!r} != {ml_config[key]!r}"
            )
    if not backtest_data.is_file():
        raise PipelineConfigError(f"dataset not found: {backtest_data}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Run the Phase 9 end-to-end research pipeline."
    )
    parser.add_argument(
        "--config",
        default=str(REPO_ROOT / "configs" / "pipeline.example.yaml"),
        help="path to the pipeline YAML config",
    )
    parser.add_argument(
        "--run-id",
        default=None,
        help="override config.experiment_id; must be unique in the store",
    )
    args = parser.parse_args(argv)

    try:
        config = load_config(Path(args.config).resolve())
        run_id = args.run_id.strip() if args.run_id else config["run_id"]
        if not run_id:
            raise PipelineConfigError("--run-id must not be empty")
        backtest_module = _load_script("pipeline_run_backtest", "run_backtest.py")
        ml_module = _load_script("pipeline_train_ml", "train_ml_baseline.py")
        _validate_stage_configs(backtest_module, ml_module, config)
    except (PipelineConfigError, OSError) as exc:
        print(f"config_error: {exc}", file=sys.stderr)
        return 1

    report_dir = config["report_dir"]
    report_dir.mkdir(parents=True, exist_ok=True)
    summary_path = report_dir / run_id / "pipeline_summary.json"
    report_path = report_dir / run_id / "pipeline_report.md"
    if summary_path.exists():
        print(
            f"duplicate_experiment: pipeline report already exists for {run_id}",
            file=sys.stderr,
        )
        return 4
    db_path = config["db_path"]
    backtest_id = f"{run_id}-backtest"
    ml_id = f"{run_id}-ml"
    backtest_report = report_dir / backtest_id
    ml_report = report_dir / ml_id

    data_path = _resolve(
        backtest_module.load_config(config["backtest_config"])["data_path"]
    )
    try:
        data_sha256 = sha256_file(data_path)
    except OSError as exc:
        print(f"config_error: cannot hash dataset: {exc}", file=sys.stderr)
        return 1
    stage_data = backtest_module.load_config(config["backtest_config"])

    stages: dict[str, Any] = {}
    pipeline_status = "completed"
    pipeline_error: str | None = None

    backtest_code = backtest_module.main(
        _stage_args(
            config_path=config["backtest_config"],
            experiment_id=backtest_id,
            report_dir=report_dir,
            db_path=db_path,
        )
    )
    stages["backtest"] = _stage_record(
        "backtest",
        backtest_code,
        backtest_id,
        backtest_report / "summary.json",
        backtest_report,
    )

    if backtest_code != 0:
        pipeline_status = _status_for(backtest_code)
        pipeline_error = stages["backtest"].get("error") or (
            f"backtest stage exited with code {backtest_code}"
        )
    else:
        ml_code = ml_module.main(
            _stage_args(
                config_path=config["ml_config"],
                experiment_id=ml_id,
                report_dir=report_dir,
                db_path=db_path,
            )
        )
        stages["ml"] = _stage_record(
            "ml", ml_code, ml_id, ml_report / "summary.json", ml_report
        )
        if ml_code != 0:
            pipeline_status = _status_for(ml_code)
            pipeline_error = stages["ml"].get("error") or (
                f"ML stage exited with code {ml_code}"
            )

    if "ml" not in stages:
        stages["ml"] = {
            "experiment_id": ml_id,
            "exit_code": None,
            "status": "skipped",
            "report_dir": str(ml_report),
            "summary_path": str(ml_report / "summary.json"),
        }

    data_kind = stage_data["data_kind"]
    limitations = [
        "Synthetic/fixture data is not market history; no performance claim is made.",
        "Python simulation only; MT5 Strategy Tester and ONNX runtime were not run.",
        "One symbol, one timeframe, one position; no portfolio or multi-asset testing.",
        "Costs are fixed spread/slippage/commission assumptions, not live execution.",
        "ML metrics are a single holdout; overfitting and regime shift remain possible.",
        "No broker connection, credentials, live orders or automatic execution.",
    ]
    if data_kind == "market":
        limitations[0] = (
            "Configured data is marked market, but this report is still research output, "
            "not live performance."
        )

    payload: dict[str, Any] = {
        "status": pipeline_status,
        "run_id": run_id,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "error": pipeline_error,
        "demo": data_kind != "market",
        "data": {
            "path": str(data_path),
            "sha256": data_sha256,
            "data_kind": data_kind,
            "symbol": stage_data["symbol"],
            "timeframe": stage_data["timeframe"],
        },
        "stages": stages,
        "limitations": limitations,
        "notes": config["notes"],
    }

    _write_json(summary_path, payload)
    report_path.write_text(_render_markdown(payload), encoding="utf-8")

    print(f"pipeline={run_id} status={pipeline_status}")
    print(f"backtest={backtest_id} status={stages['backtest']['status']}")
    print(f"ml={ml_id} status={stages['ml']['status']}")
    if pipeline_error:
        print(f"error={pipeline_error}", file=sys.stderr)
    print(f"report={report_path}")

    code = stages["backtest"]["exit_code"]
    if code == 0:
        code = stages["ml"]["exit_code"] or 0
    return int(code)


if __name__ == "__main__":
    raise SystemExit(main())
