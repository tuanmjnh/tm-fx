"""Markdown model card rendering for the ML baseline."""

from __future__ import annotations

from typing import Any


def _format(value: Any, digits: int = 4) -> str:
    if value is None:
        return "n/a"
    if isinstance(value, bool):
        return "yes" if value else "no"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def _classification_rows(metrics: dict[str, Any]) -> list[str]:
    return [
        f"| Samples | {_format(metrics.get('samples'))} |",
        f"| Positive / negative | {_format(metrics.get('positives'))} / "
        f"{_format(metrics.get('negatives'))} |",
        f"| Accuracy | {_format(metrics.get('accuracy'))} |",
        f"| Balanced accuracy | {_format(metrics.get('balanced_accuracy'))} |",
        f"| Precision / recall / F1 | {_format(metrics.get('precision'))} / "
        f"{_format(metrics.get('recall'))} / {_format(metrics.get('f1'))} |",
        f"| ROC-AUC | {_format(metrics.get('roc_auc'))} |",
        f"| Brier score | {_format(metrics.get('brier_score'))} |",
        f"| Confusion (TN/FP/FN/TP) | "
        f"{metrics.get('confusion', {}).get('tn', 'n/a')} / "
        f"{metrics.get('confusion', {}).get('fp', 'n/a')} / "
        f"{metrics.get('confusion', {}).get('fn', 'n/a')} / "
        f"{metrics.get('confusion', {}).get('tp', 'n/a')} |",
        f"| Threshold | {_format(metrics.get('threshold'))} |",
    ]


def _strategy_rows(metrics: dict[str, Any]) -> list[str]:
    return [
        f"| Trades | {_format(metrics.get('trade_count'))} |",
        f"| Final equity | {_format(metrics.get('final_equity'), 2)} |",
        f"| Net profit | {_format(metrics.get('net_profit'), 2)} |",
        f"| Total return | {_format(metrics.get('total_return'))} |",
        f"| Win rate | {_format(metrics.get('win_rate'))} |",
        f"| Profit factor | {_format(metrics.get('profit_factor'))} |",
        f"| Max drawdown | {_format(metrics.get('max_drawdown'), 2)} |",
        f"| Exposure ratio | {_format(metrics.get('exposure_ratio'))} |",
    ]


def render_model_card(summary: dict[str, Any]) -> str:
    model = summary.get("model", {})
    data = summary.get("data", {})
    labels = summary.get("labels", {})
    features = summary.get("features", {})
    split = summary.get("split", {})
    classification = summary.get("classification", {})
    strategy = summary.get("strategy", {})
    threshold = summary.get("threshold", {})
    execution = summary.get("execution", {})

    lines: list[str] = [
        f"# Model card — {summary.get('experiment_id')}",
        "",
        "> Research baseline only. This model is not connected to a broker and does not place "
        "orders. Metrics below are not evidence of live profitability.",
        "",
        "## Identification",
        "",
        f"- Experiment: `{summary.get('experiment_id')}`",
        f"- Generated (UTC): {summary.get('generated_at_utc')}",
        f"- Code version: {summary.get('code_version')}",
        f"- Git commit: {_format(summary.get('git_commit'))} "
        f"(dirty worktree: {_format(summary.get('git_dirty'))})",
        f"- Model kind: {model.get('kind')}",
        f"- Model artifact: `{summary.get('artifacts', {}).get('model', 'n/a')}`",
        "",
        "## Data",
        "",
        f"- Source: `{data.get('path')}`",
        f"- Data kind: **{data.get('data_kind')}** "
        "(synthetic data is not market evidence)",
        f"- Symbol / timeframe: {data.get('symbol')} / {data.get('timeframe')}",
        f"- Timezone: {data.get('timezone')}",
        f"- Rows: {_format(data.get('rows'))}",
        f"- Data SHA-256: `{_format(summary.get('data_fingerprint'))}`",
        f"- Validation passed: {_format(summary.get('data_validation', {}).get('passed'))}",
        "",
        "## Target and labels",
        "",
        f"- Target: {labels.get('definition', 'n/a')}",
        f"- Horizon: {_format(labels.get('horizon'))} bars",
        f"- Minimum return for a positive/negative label: "
        f"{_format(labels.get('min_return'), 6)}",
        f"- Label counts: {_format(labels.get('counts'))}",
        "- Labels use future prices and are never used as model inputs.",
        "",
        "## Features",
        "",
        f"- Feature count: {_format(features.get('feature_count'))}",
        f"- Warm-up bars dropped: {_format(features.get('warmup_bars'))}",
        f"- Causality: {features.get('causality', 'n/a')}",
        "- Features: " + ", ".join(f"`{name}`" for name in features.get("feature_names", [])),
        "",
        "## Validation design",
        "",
        f"- Chronological train/validation/test sizes: "
        f"{_format(split.get('train', {}).get('size'))} / "
        f"{_format(split.get('validation', {}).get('size'))} / "
        f"{_format(split.get('test', {}).get('size'))}",
        f"- Walk-forward folds: {_format(len(split.get('folds', [])))}",
        f"- Purge rule: {split.get('purge', 'n/a')}",
        f"- Integrity checks: {_format(split.get('checks'))}",
        "- The test segment was not used to fit the model or choose the threshold; "
        "it was evaluated once with the fixed configuration.",
        "",
        "## Training",
        "",
        f"- Hyperparameters: {_format(model.get('hyperparameters'))}",
        f"- Training samples: {_format(model.get('training', {}).get('samples'))} "
        f"(positive {_format(model.get('training', {}).get('positive'))}, "
        f"negative {_format(model.get('training', {}).get('negative'))})",
        f"- Decision threshold: {_format(threshold.get('threshold'))} "
        f"selected by {threshold.get('selection_metric')} on out-of-fold validation "
        f"(tie-break: {threshold.get('tie_break')})",
        "",
        "## Out-of-sample classification",
        "",
        "| Metric | Test |",
        "|---|---|",
        *_classification_rows(classification.get("test", {})),
        "",
        "Reference at threshold 0.5:",
        "",
        "| Metric | Test @ 0.5 |",
        "|---|---|",
        *_classification_rows(classification.get("test_at_half", {})),
        "",
        "Threshold sensitivity is reported, not optimized, on the test set.",
        "",
        "### Walk-forward folds",
        "",
        "| Fold | Validation samples | ROC-AUC | Balanced accuracy |",
        "|---|---|---|---|",
    ]

    for fold in classification.get("folds", []):
        lines.append(
            f"| {fold.get('fold')} | {_format(fold.get('samples'))} | "
            f"{_format(fold.get('roc_auc'))} | {_format(fold.get('balanced_accuracy'))} |"
        )

    oof = classification.get("oof", {})
    lines.extend(
        [
            "",
            f"Out-of-fold aggregate: ROC-AUC {_format(oof.get('roc_auc'))}, "
            f"balanced accuracy {_format(oof.get('balanced_accuracy'))}, "
            f"samples {_format(oof.get('samples'))}.",
            "",
            "## No-ML benchmarks",
            "",
            "Majority-class classifier (classification benchmark):",
            "",
            "| Metric | Value |",
            "|---|---|",
            *_classification_rows(classification.get("majority_benchmark", {})),
            "",
            "Trading benchmarks use the same test window, horizon and cost model as the "
            "ML strategy:",
            "",
            "| Strategy | Trades | Final equity | Net profit | Total return | Max DD | Exposure |",
            "|---|---|---|---|---|---|---|",
        ]
    )
    for name, key in (("ML logistic", "ml"), ("Momentum rule", "momentum"), ("Buy & hold", "buy_and_hold")):
        metrics = strategy.get(key, {})
        if "metrics" in metrics:
            metrics = metrics["metrics"]
        if key == "buy_and_hold" and metrics:
            lines.append(
                f"| {name} | 1 | {_format(metrics.get('net_pnl', 0) + execution.get('initial_equity', 0), 2)} | "
                f"{_format(metrics.get('net_pnl'), 2)} | {_format(metrics.get('return'))} | "
                "n/a | 1.0000 |"
            )
        else:
            lines.append(
                f"| {name} | {_format(metrics.get('trade_count'))} | "
                f"{_format(metrics.get('final_equity'), 2)} | "
                f"{_format(metrics.get('net_profit'), 2)} | "
                f"{_format(metrics.get('total_return'))} | "
                f"{_format(metrics.get('max_drawdown'), 2)} | "
                f"{_format(metrics.get('exposure_ratio'))} |"
            )

    data_kind = data.get("data_kind")
    data_limitation = (
        "Synthetic single-symbol data; no claim about market performance."
        if data_kind != "market"
        else f"{data_kind} single-symbol data; no claim about future performance."
    )

    lines.extend(
        [
            "",
            "## Cost assumptions",
            "",
            f"- Initial equity: {_format(execution.get('initial_equity'), 2)}",
            f"- Position units: {_format(execution.get('position_units'), 2)}",
            f"- Point size: {_format(execution.get('point_size'), 6)}",
            f"- Spread / slippage (points): {_format(execution.get('spread_points'))} / "
            f"{_format(execution.get('slippage_points'))}",
            f"- Commission per side: {_format(execution.get('commission_per_side'), 2)}",
            "- No leverage model, margin call or financing is applied; position size is a "
            "research parameter.",
            "",
            "## Limitations",
            "",
            f"- {data_limitation}",
            "- Small sample, one horizon and one feature set; results are sensitive to regime.",
            "- Classification metrics and simulated strategy metrics answer different questions "
            "and must not be conflated.",
            "- No annualized Sharpe/Sortino, no microstructure model, no slippage calibration.",
            "- No ONNX/MQL5 inference in this phase.",
            "- Tuning after inspecting test metrics would invalidate the reported out-of-sample "
            "result.",
            "",
            "## Dependencies",
            "",
            f"- {_format(model.get('dependencies'))}",
            "",
        ]
    )
    return "\n".join(lines)
