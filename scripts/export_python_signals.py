"""Export Python baseline signals for MQL5 parity comparison.

Exit codes:
    0  signal export written
    1  configuration could not be loaded
    2  dataset validation failed
    3  signal generation failed

The output schema matches ``LabSignalExport.mq5``:
timestamp,symbol,timeframe,signal,reason,fast_prev,slow_prev,fast,slow.
This script does not trade, connect to a broker or read account data.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

import pandas as pd

from mt5_ea_ai_lab.data.loader import DATA_KINDS, DataLoadError, load_ohlcv
from mt5_ea_ai_lab.evaluation.parity import PARITY_COLUMNS, format_timestamp
from mt5_ea_ai_lab.signals import EmaCrossConfig, generate_signals
from mt5_ea_ai_lab.validation import validate_ohlcv


def _resolve(path_value: str) -> Path:
    candidate = Path(path_value)
    return candidate if candidate.is_absolute() else (REPO_ROOT / candidate)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Export Python EMA-crossover signals for MQL5 parity checks."
    )
    parser.add_argument(
        "--data",
        default="datasets/samples/parity_ema_cross.csv",
        help="OHLCV CSV/Parquet fixture (resolved against the repository root)",
    )
    parser.add_argument(
        "--out",
        default="reports/parity/parity_signals_python.csv",
        help="output signal CSV (resolved against the repository root)",
    )
    parser.add_argument("--symbol", default=None, help="override the dataset symbol")
    parser.add_argument("--timeframe", default=None, help="override the dataset timeframe")
    parser.add_argument("--timezone", default="UTC", help="timezone for naive timestamps")
    parser.add_argument(
        "--data-kind",
        default="synthetic",
        choices=DATA_KINDS,
        help="declared dataset kind",
    )
    parser.add_argument("--fast", type=int, default=2, help="fast EMA period")
    parser.add_argument("--slow", type=int, default=3, help="slow EMA period")
    parser.add_argument("--no-long", action="store_true", help="disable BUY signals")
    parser.add_argument("--no-short", action="store_true", help="disable SELL signals")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    data_path = _resolve(args.data)
    out_path = _resolve(args.out)

    try:
        config = EmaCrossConfig(
            fast_period=args.fast,
            slow_period=args.slow,
            allow_long=not args.no_long,
            allow_short=not args.no_short,
        )
        config.validate()
    except ValueError as exc:
        print(f"config_error: {exc}", file=sys.stderr)
        return 1

    try:
        frame, metadata = load_ohlcv(
            data_path,
            symbol=args.symbol,
            timeframe=args.timeframe,
            timezone=args.timezone,
            data_kind=args.data_kind,
        )
    except (DataLoadError, FileNotFoundError, OSError) as exc:
        print(f"load_error: {exc}", file=sys.stderr)
        return 1

    symbol = args.symbol or metadata.symbol
    timeframe = args.timeframe or metadata.timeframe
    if not symbol or not timeframe:
        print(
            "config_error: symbol and timeframe must be provided or present in the dataset",
            file=sys.stderr,
        )
        return 1

    validation = validate_ohlcv(frame, metadata=metadata)
    if not validation.passed:
        print(
            f"invalid_data: {len(validation.errors)} validation error(s)",
            file=sys.stderr,
        )
        for issue in validation.errors[:5]:
            print(issue.to_dict(), file=sys.stderr)
        return 2

    try:
        signals = generate_signals(
            frame["close"].to_numpy(dtype=float),
            frame["timestamp"],
            config,
        )
    except (ValueError, TypeError) as exc:
        print(f"signal_error: {exc}", file=sys.stderr)
        return 3

    export = pd.DataFrame(
        {
            "timestamp": [
                format_timestamp(pd.Timestamp(value)) for value in signals["timestamp"]
            ],
            "symbol": symbol,
            "timeframe": timeframe,
            "signal": signals["signal"],
            "reason": signals["reason"],
            "fast_prev": signals["fast_prev"],
            "slow_prev": signals["slow_prev"],
            "fast": signals["fast"],
            "slow": signals["slow"],
        },
        columns=list(PARITY_COLUMNS),
    )

    out_path.parent.mkdir(parents=True, exist_ok=True)
    export.to_csv(out_path, index=False)

    counts = export["signal"].value_counts().to_dict()
    print(
        f"status=exported rows={len(export)} "
        f"buy={counts.get('BUY', 0)} sell={counts.get('SELL', 0)} "
        f"hold={counts.get('HOLD', 0)} unknown={counts.get('UNKNOWN', 0)} "
        f"fast={config.fast_period} slow={config.slow_period}"
    )
    print(f"output={out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
