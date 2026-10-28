"""Generate the deterministic synthetic dataset used by the ML demo.

The series is synthetic, not market data. It mixes regimes with different
drift and volatility so the ML baseline has both learnable and non-stationary
structure; results must still be reported as synthetic research output.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = REPO_ROOT / "datasets" / "samples" / "synthetic_ml_demo.csv"


def generate(rows: int = 1800, seed: int = 20261027) -> pd.DataFrame:
    if rows < 100:
        raise ValueError("rows must be at least 100")
    rng = np.random.default_rng(seed)

    drift = np.zeros(rows)
    volatility = np.zeros(rows)
    regimes = ((-0.000015, 0.00035), (0.000020, 0.00050), (0.0, 0.00028))
    block = 220
    for start in range(0, rows, block):
        mean, sigma = regimes[(start // block) % len(regimes)]
        drift[start : start + block] = mean
        volatility[start : start + block] = sigma

    noise = rng.normal(0.0, 1.0, rows)
    returns = np.zeros(rows)
    for index in range(rows):
        previous = returns[index - 1] if index else 0.0
        returns[index] = (
            drift[index] + 0.25 * previous + volatility[index] * noise[index]
        )
    returns = np.clip(returns, -0.004, 0.004)

    close = 1.10 * np.exp(np.cumsum(returns))
    open_price = np.empty(rows)
    open_price[0] = close[0] * (1.0 + rng.normal(0.0, 0.00005))
    open_price[1:] = close[:-1] * (1.0 + rng.normal(0.0, 0.00003, rows - 1))

    span = np.abs(rng.normal(0.0, 0.00018, rows)) + 0.00004
    high = np.maximum(open_price, close) + span * rng.uniform(0.3, 1.0, rows)
    low = np.minimum(open_price, close) - span * rng.uniform(0.3, 1.0, rows)
    volume = rng.lognormal(mean=4.6, sigma=0.35, size=rows)
    volume = np.maximum(10, np.round(volume * (1.0 + 40.0 * np.abs(returns)))).astype(int)

    timestamps = pd.date_range(
        "2024-01-01T00:00:00Z", periods=rows, freq="5min", tz="UTC"
    )
    frame = pd.DataFrame(
        {
            "timestamp": timestamps,
            "open": np.round(open_price, 5),
            "high": np.round(high, 5),
            "low": np.round(low, 5),
            "close": np.round(close, 5),
            "tick_volume": volume,
            "spread": rng.integers(8, 16, rows),
            "real_volume": 0,
            "symbol": "EURUSD",
            "timeframe": "M5",
        }
    )
    frame["high"] = frame[["open", "high", "close", "low"]].max(axis=1)
    frame["low"] = frame[["open", "high", "close", "low"]].min(axis=1)
    if frame[["open", "high", "low", "close"]].isna().any().any():
        raise ValueError("generated OHLC contains missing values")
    if not ((frame["high"] >= frame[["open", "close"]].max(axis=1)) &
            (frame["low"] <= frame[["open", "close"]].min(axis=1))).all():
        raise ValueError("generated OHLC is inconsistent")
    return frame


def main() -> None:
    frame = generate()
    DEFAULT_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    frame.to_csv(DEFAULT_OUTPUT, index=False, date_format="%Y-%m-%dT%H:%M:%SZ")
    print(f"wrote {len(frame)} synthetic rows to {DEFAULT_OUTPUT}")


if __name__ == "__main__":
    main()
