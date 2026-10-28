from __future__ import annotations

from pathlib import Path

import pandas as pd
import pytest

from mt5_ea_ai_lab.data.loader import (
    DataLoadError,
    DatasetMetadata,
    load_ohlcv,
)

FIXTURES = Path(__file__).parent / "fixtures"
FIXTURE = FIXTURES / "synthetic_eurusd_m5.csv"


def load_fixture(**kwargs):
    return load_ohlcv(FIXTURE, timezone="UTC", data_kind="synthetic", **kwargs)


def test_loads_fixture_and_metadata() -> None:
    frame, metadata = load_fixture()

    assert isinstance(metadata, DatasetMetadata)
    assert metadata.rows == 6
    assert metadata.symbol == "EURUSD"
    assert metadata.timeframe == "M5"
    assert metadata.data_kind == "synthetic"
    assert metadata.file_format == "csv"
    assert metadata.original_columns[0] == "timestamp"
    assert str(frame["timestamp"].dtype) == "datetime64[ns, UTC]"
    assert frame["timestamp"].iloc[0].isoformat() == "2024-01-01T00:00:00+00:00"
    assert frame["close"].dtype.kind == "f"


def test_normalizes_mt5_date_time_and_angle_brackets(tmp_path: Path) -> None:
    path = tmp_path / "mt5_export.csv"
    path.write_text(
        "<DATE>,<TIME>,<OPEN>,<HIGH>,<LOW>,<CLOSE>,<TICKVOL>,<SPREAD>\n"
        "2024-01-01,00:00:00,1.1000,1.1010,1.0990,1.1005,10,5\n"
        "2024-01-01,00:05:00,1.1005,1.1020,1.1000,1.1015,12,6\n",
        encoding="utf-8",
    )

    frame, _ = load_ohlcv(path, timezone="UTC")

    assert list(frame.columns[:6]) == [
        "timestamp",
        "open",
        "high",
        "low",
        "close",
        "tick_volume",
    ]
    assert frame["timestamp"].iloc[0].isoformat() == "2024-01-01T00:00:00+00:00"
    assert frame["tick_volume"].tolist() == [10, 12]
    assert frame["spread"].tolist() == [5, 6]


def test_empty_csv_returns_empty_frame(tmp_path: Path) -> None:
    path = tmp_path / "empty.csv"
    path.write_text("", encoding="utf-8")

    frame, metadata = load_ohlcv(path)

    assert frame.empty
    assert metadata.rows == 0
    assert metadata.normalized_columns == ()


def test_missing_file_raises() -> None:
    with pytest.raises(FileNotFoundError):
        load_ohlcv(FIXTURES / "does_not_exist.csv")


def test_unsupported_format_raises(tmp_path: Path) -> None:
    path = tmp_path / "data.txt"
    path.write_text("timestamp,open,high,low,close,tick_volume\n", encoding="utf-8")

    with pytest.raises(DataLoadError, match="unsupported dataset format"):
        load_ohlcv(path)


def test_invalid_data_kind_raises() -> None:
    with pytest.raises(DataLoadError, match="data_kind"):
        load_ohlcv(FIXTURE, data_kind="synthetic-ish")


def test_naive_timestamps_are_localized_then_converted_to_utc(tmp_path: Path) -> None:
    path = tmp_path / "naive.csv"
    path.write_text(
        "timestamp,open,high,low,close,tick_volume\n"
        "2024-01-01 10:00:00,1,2,0.5,1.5,10\n",
        encoding="utf-8",
    )

    frame, _ = load_ohlcv(path, timezone="Europe/Berlin")

    assert frame["timestamp"].iloc[0].isoformat() == "2024-01-01T09:00:00+00:00"


def test_aware_timestamps_are_converted_to_utc(tmp_path: Path) -> None:
    path = tmp_path / "aware.csv"
    path.write_text(
        "timestamp,open,high,low,close,tick_volume\n"
        "2024-01-01T00:00:00+02:00,1,2,0.5,1.5,10\n",
        encoding="utf-8",
    )

    frame, _ = load_ohlcv(path)

    assert frame["timestamp"].iloc[0].isoformat() == "2023-12-31T22:00:00+00:00"


def test_loader_preserves_row_order(tmp_path: Path) -> None:
    path = tmp_path / "unsorted.csv"
    path.write_text(
        "timestamp,open,high,low,close,tick_volume\n"
        "2024-01-01 00:05:00,1,2,0.5,1.5,10\n"
        "2024-01-01 00:00:00,1,2,0.5,1.5,10\n",
        encoding="utf-8",
    )

    frame, _ = load_ohlcv(path)

    assert frame["timestamp"].iloc[0] > frame["timestamp"].iloc[1]


def test_duplicate_normalized_columns_raise(tmp_path: Path) -> None:
    path = tmp_path / "duplicate.csv"
    path.write_text(
        "timestamp,datetime,open,high,low,close,tick_volume\n"
        "2024-01-01 00:00:00,2024-01-01 00:00:00,1,2,0.5,1.5,10\n",
        encoding="utf-8",
    )

    with pytest.raises(DataLoadError, match="duplicate columns"):
        load_ohlcv(path)


def test_parquet_roundtrip_when_pyarrow_is_available(tmp_path: Path) -> None:
    pytest.importorskip("pyarrow")

    frame, _ = load_fixture()
    path = tmp_path / "sample.parquet"
    frame.to_parquet(path, index=False)

    loaded, metadata = load_ohlcv(path, data_kind="synthetic")

    assert metadata.file_format == "parquet"
    assert len(loaded) == len(frame)
    assert loaded["close"].tolist() == frame["close"].tolist()
    assert isinstance(loaded["timestamp"].dtype, pd.DatetimeTZDtype)
