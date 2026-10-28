from __future__ import annotations

import csv
import importlib.util
from pathlib import Path
from types import ModuleType

import pytest

from mt5_ea_ai_lab.evaluation.pine_parity import (
    MISSING_IN_MQL5,
    MISSING_IN_PINE,
    NAN_MISMATCH,
    VALUE_MISMATCH,
    PineParityError,
    compare_pine_exports,
    load_bar_times,
    load_pine_parity_csv,
    write_report,
)

REPO_ROOT = Path(__file__).resolve().parents[2]

COLUMNS = [
    "bar_open_time",
    "symbol",
    "timeframe",
    "signal_id",
    "side",
    "sar_dir",
    "psar",
    "fast",
    "slow",
    "atr_pct",
    "confirmed_at",
    "input_hash",
]

BASE_ROWS = [
    [
        "2026-01-05T10:00:00Z",
        "EURUSD",
        "M5",
        "WW_BUY_SAR_FLIP",
        "BUY",
        "1",
        "1.10000000",
        "1.10100000",
        "1.10050000",
        "0.450000",
        "2026-01-05T10:05:00Z",
        "abcd1234",
    ],
    [
        "2026-01-05T10:15:00Z",
        "EURUSD",
        "M5",
        "WW_SELL_SAR_FLIP",
        "SELL",
        "-1",
        "1.10500000",
        "1.10300000",
        "1.10400000",
        "0.550000",
        "2026-01-05T10:20:00Z",
        "abcd1234",
    ],
]


def write_csv(path: Path, rows: list[list[str]], columns: list[str] | None = None) -> Path:
    header = COLUMNS if columns is None else columns
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerows(rows)
    return path


def clone_rows() -> list[list[str]]:
    return [list(row) for row in BASE_ROWS]


def test_equal_exports_match(tmp_path: Path) -> None:
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    mql5 = write_csv(tmp_path / "mql5.csv", BASE_ROWS)

    report = compare_pine_exports(pine, mql5)

    assert report.status == "match"
    assert report.mismatch_count == 0
    assert report.rows_pine == 2
    assert report.rows_mql5 == 2
    assert report.rows_compared == 2
    assert report.input_hash_checked is True


def test_missing_row_in_mql5_is_reported(tmp_path: Path) -> None:
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    mql5 = write_csv(tmp_path / "mql5.csv", BASE_ROWS[:1])

    report = compare_pine_exports(pine, mql5)

    assert report.status == "mismatch"
    assert [item.kind for item in report.mismatches] == [MISSING_IN_MQL5]
    assert report.mismatches[0].field == "*"


def test_extra_row_in_mql5_is_reported(tmp_path: Path) -> None:
    extra = list(BASE_ROWS[0])
    extra[0] = "2026-01-05T11:00:00Z"
    extra[10] = "2026-01-05T11:05:00Z"
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    mql5 = write_csv(tmp_path / "mql5.csv", [*BASE_ROWS, extra])

    report = compare_pine_exports(pine, mql5)

    assert report.status == "mismatch"
    assert [item.kind for item in report.mismatches] == [MISSING_IN_PINE]


def test_signal_id_mismatch_is_exact(tmp_path: Path) -> None:
    changed = clone_rows()
    changed[0][3] = "WW_BUY_SAR_EMA"
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    mql5 = write_csv(tmp_path / "mql5.csv", changed)

    report = compare_pine_exports(pine, mql5)

    assert report.status == "mismatch"
    fields = {item.field for item in report.mismatches}
    assert fields == {"signal_id"}
    assert report.mismatches[0].kind == VALUE_MISMATCH


def test_inconsistent_side_is_rejected(tmp_path: Path) -> None:
    changed = clone_rows()
    changed[0][4] = "SELL"
    path = write_csv(tmp_path / "bad.csv", changed)

    with pytest.raises(PineParityError, match="side=SELL"):
        load_pine_parity_csv(path)


def test_inconsistent_direction_is_rejected(tmp_path: Path) -> None:
    changed = clone_rows()
    changed[1][5] = "1"
    path = write_csv(tmp_path / "bad.csv", changed)

    with pytest.raises(PineParityError, match="sar_dir=1"):
        load_pine_parity_csv(path)


def test_price_tolerance_is_absolute(tmp_path: Path) -> None:
    changed = clone_rows()
    changed[0][6] = "1.100000005"
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    mql5 = write_csv(tmp_path / "mql5.csv", changed)

    assert compare_pine_exports(pine, mql5).status == "match"

    changed[0][6] = "1.1000002"
    mql5 = write_csv(tmp_path / "mql5.csv", changed)
    report = compare_pine_exports(pine, mql5)
    assert report.status == "mismatch"
    assert report.mismatches[0].field == "psar"
    assert abs(report.mismatches[0].difference) == pytest.approx(2e-7, rel=0, abs=1e-12)


def test_oscillator_uses_separate_tolerance(tmp_path: Path) -> None:
    changed = clone_rows()
    changed[0][9] = "0.4500005"
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    mql5 = write_csv(tmp_path / "mql5.csv", changed)

    assert compare_pine_exports(pine, mql5).status == "match"

    changed[0][9] = "0.4500020"
    mql5 = write_csv(tmp_path / "mql5.csv", changed)
    report = compare_pine_exports(pine, mql5)
    assert report.status == "mismatch"
    assert report.mismatches[0].field == "atr_pct"


def test_empty_numeric_must_be_empty_on_both_sides(tmp_path: Path) -> None:
    changed = clone_rows()
    changed[0][7] = ""
    pine = write_csv(tmp_path / "pine.csv", changed)
    mql5 = write_csv(tmp_path / "mql5.csv", BASE_ROWS)

    report = compare_pine_exports(pine, mql5)
    assert report.status == "mismatch"
    assert report.mismatches[0].kind == NAN_MISMATCH

    both = clone_rows()
    both[0][7] = ""
    pine = write_csv(tmp_path / "pine.csv", both)
    mql5 = write_csv(tmp_path / "mql5.csv", both)
    assert compare_pine_exports(pine, mql5).status == "match"


def test_input_hash_mismatch_is_reported(tmp_path: Path) -> None:
    changed = clone_rows()
    changed[0][11] = "ffffffff"
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    mql5 = write_csv(tmp_path / "mql5.csv", changed)

    report = compare_pine_exports(pine, mql5)

    assert report.status == "mismatch"
    assert report.mismatches[0].field == "input_hash"


def test_start_filter_applies_to_both_sides(tmp_path: Path) -> None:
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    mql5 = write_csv(tmp_path / "mql5.csv", BASE_ROWS)

    report = compare_pine_exports(pine, mql5, start="2026-01-05T10:10:00Z")

    assert report.status == "match"
    assert report.rows_pine == 1
    assert report.rows_mql5 == 1


def test_warmup_bars_requires_bar_times(tmp_path: Path) -> None:
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    mql5 = write_csv(tmp_path / "mql5.csv", BASE_ROWS)

    with pytest.raises(PineParityError, match="requires bar_times_path"):
        compare_pine_exports(pine, mql5, warmup_bars=1)


def test_warmup_bars_drops_earlier_bar_times(tmp_path: Path) -> None:
    bars = write_csv(
        tmp_path / "bars.csv",
        [["2026-01-05T10:00:00Z"], ["2026-01-05T10:15:00Z"]],
        columns=["bar_open_time"],
    )
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    mql5 = write_csv(tmp_path / "mql5.csv", BASE_ROWS)

    report = compare_pine_exports(
        pine, mql5, warmup_bars=1, bar_times_path=bars
    )

    assert report.status == "match"
    assert report.rows_pine == 1
    assert report.mismatches == ()


def test_filtering_everything_is_an_error(tmp_path: Path) -> None:
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    mql5 = write_csv(tmp_path / "mql5.csv", BASE_ROWS)

    with pytest.raises(PineParityError, match="no rows remain"):
        compare_pine_exports(pine, mql5, start="2027-01-01T00:00:00Z")


def test_invalid_timestamp_is_rejected(tmp_path: Path) -> None:
    changed = clone_rows()
    changed[0][0] = "not-a-time"
    path = write_csv(tmp_path / "bad.csv", changed)

    with pytest.raises(PineParityError, match="invalid bar_open_time"):
        load_pine_parity_csv(path)


def test_duplicate_keys_are_rejected(tmp_path: Path) -> None:
    path = write_csv(tmp_path / "bad.csv", [BASE_ROWS[0], BASE_ROWS[0]])

    with pytest.raises(PineParityError, match="duplicate"):
        load_pine_parity_csv(path)


def test_missing_required_column_is_rejected(tmp_path: Path) -> None:
    columns = [column for column in COLUMNS if column != "signal_id"]
    path = write_csv(tmp_path / "bad.csv", [BASE_ROWS[0]], columns=columns)

    with pytest.raises(PineParityError, match="missing required columns"):
        load_pine_parity_csv(path)


def test_empty_file_is_rejected(tmp_path: Path) -> None:
    path = write_csv(tmp_path / "empty.csv", [])

    with pytest.raises(PineParityError, match="no signal rows"):
        load_pine_parity_csv(path)


def test_unknown_signal_id_is_rejected(tmp_path: Path) -> None:
    changed = clone_rows()
    changed[0][3] = "WW_UNKNOWN"
    path = write_csv(tmp_path / "bad.csv", changed)

    with pytest.raises(PineParityError, match="unknown signal_id"):
        load_pine_parity_csv(path)


def test_wrong_confirmed_at_is_rejected(tmp_path: Path) -> None:
    changed = clone_rows()
    changed[0][10] = "2026-01-05T10:06:00Z"
    path = write_csv(tmp_path / "bad.csv", changed)

    with pytest.raises(PineParityError, match="confirmed_at"):
        load_pine_parity_csv(path)


def test_bar_times_file_is_sorted_and_deduplicated(tmp_path: Path) -> None:
    path = write_csv(
        tmp_path / "bars.csv",
        [["2026-01-05T10:15:00Z"], ["2026-01-05T10:00:00Z"], ["2026-01-05T10:00:00Z"]],
        columns=["bar_open_time"],
    )

    times = load_bar_times(path)

    assert list(times) == ["2026-01-05T10:00:00Z", "2026-01-05T10:15:00Z"]


def test_write_report_creates_json_and_csv(tmp_path: Path) -> None:
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    changed = clone_rows()
    changed[0][3] = "WW_BUY_SAR_EMA"
    mql5 = write_csv(tmp_path / "mql5.csv", changed)
    report = compare_pine_exports(pine, mql5)

    json_path, csv_path = write_report(report, tmp_path / "out")

    assert json_path.exists() and csv_path.exists()
    assert '"status": "mismatch"' in json_path.read_text(encoding="utf-8")


def load_script() -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        "compare_pine_exports_script",
        REPO_ROOT / "scripts" / "compare_pine_exports.py",
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_cli_exit_codes(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    comparator = load_script()
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    matching = write_csv(tmp_path / "matching.csv", BASE_ROWS)

    code = comparator.main(
        ["--pine", str(pine), "--mql5", str(matching), "--out-dir", str(tmp_path / "ok")]
    )
    assert code == 0
    assert "status=match" in capsys.readouterr().out

    changed = clone_rows()
    changed[0][3] = "WW_BUY_SAR_EMA"
    mismatch = write_csv(tmp_path / "mismatch.csv", changed)
    code = comparator.main(
        ["--pine", str(pine), "--mql5", str(mismatch), "--out-dir", str(tmp_path / "bad")]
    )
    assert code == 1
    assert "status=mismatch" in capsys.readouterr().out

    code = comparator.main(
        ["--pine", str(tmp_path / "missing.csv"), "--mql5", str(matching)]
    )
    assert code == 2
    assert "comparison_error" in capsys.readouterr().err


def test_mql5_server_time_offset_and_dot_format(tmp_path: Path) -> None:
    server = clone_rows()
    server[0][0] = "2026.01.05 13:00:00"
    server[0][10] = "2026.01.05 13:05:00"
    server[1][0] = "2026.01.05 13:15:00"
    server[1][10] = "2026.01.05 13:20:00"
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    mql5 = write_csv(tmp_path / "mql5.csv", server)

    report = compare_pine_exports(pine, mql5, mql5_offset_minutes=180)

    assert report.status == "match"
    assert report.mql5_offset_minutes == 180.0


def test_wrong_server_offset_reports_missing_rows(tmp_path: Path) -> None:
    server = clone_rows()
    server[0][0] = "2026.01.05 13:00:00"
    server[0][10] = "2026.01.05 13:05:00"
    server[1][0] = "2026.01.05 13:15:00"
    server[1][10] = "2026.01.05 13:20:00"
    pine = write_csv(tmp_path / "pine.csv", BASE_ROWS)
    mql5 = write_csv(tmp_path / "mql5.csv", server)

    report = compare_pine_exports(pine, mql5)

    assert report.status == "mismatch"
    kinds = {item.kind for item in report.mismatches}
    assert kinds == {MISSING_IN_MQL5, MISSING_IN_PINE}
