from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

import pytest

from mt5_ea_ai_lab.evaluation.multi_source_parity import (
    MISMATCH_COLUMNS,
    compare_multi_source_exports,
    load_multi_source_csv,
    write_parity_report,
)
from mt5_ea_ai_lab.evaluation.pine_parity import PineParityError

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_DIR = REPO_ROOT / "scripts"
sys.path.insert(0, str(SCRIPT_DIR))

import compare_multi_signal_exports as comparator_cli  # noqa: E402

HEADER = [
    "bar_open_time",
    "symbol",
    "timeframe",
    "source",
    "signal_id",
    "side",
    "dir",
    "score",
    "entry",
    "sl",
    "tp1",
    "tp2",
    "tp3",
]


def _row(
    bar: str = "2026-01-05T10:00:00Z",
    *,
    source: str = "Wonderwhales",
    signal_id: str = "WW_BUY_SAR_FLIP",
    side: str = "BUY",
    direction: str = "1",
    score: str = "75.5",
    entry: str = "1.1050",
    sl: str = "1.1000",
    tp1: str = "1.1100",
    tp2: str = "1.1150",
    tp3: str = "1.1200",
    symbol: str = "EURUSD",
    timeframe: str = "M5",
) -> dict[str, str]:
    return {
        "bar_open_time": bar,
        "symbol": symbol,
        "timeframe": timeframe,
        "source": source,
        "signal_id": signal_id,
        "side": side,
        "dir": direction,
        "score": score,
        "entry": entry,
        "sl": sl,
        "tp1": tp1,
        "tp2": tp2,
        "tp3": tp3,
    }


def _write(path: Path, rows: list[dict[str, str]], header: list[str] | None = None) -> Path:
    columns = header or HEADER
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({column: row.get(column, "") for column in columns})
    return path


def _mismatch_fields(report) -> set[tuple[str, str, str]]:
    return {(item.source, item.field, item.kind) for item in report.mismatches}


def test_identical_exports_match(tmp_path: Path) -> None:
    rows = [_row(), _row("2026-01-05T10:05:00Z", signal_id="WW_SELL_SAR_FLIP", side="SELL", direction="-1")]
    reference = _write(tmp_path / "ref.csv", rows)
    mql5 = _write(tmp_path / "mql5.csv", rows)

    report = compare_multi_source_exports(reference, mql5)

    assert report.status == "match"
    assert report.rows_reference == 2
    assert report.rows_mql5 == 2
    assert report.rows_compared == 2
    assert report.mismatch_count == 0


def test_price_within_tolerance_matches(tmp_path: Path) -> None:
    reference = _write(tmp_path / "ref.csv", [_row(entry="1.1050000001")])
    mql5 = _write(tmp_path / "mql5.csv", [_row(entry="1.1050000000")])

    report = compare_multi_source_exports(reference, mql5, tolerance_price=1e-8)

    assert report.status == "match"


def test_price_beyond_tolerance_is_mismatch(tmp_path: Path) -> None:
    reference = _write(tmp_path / "ref.csv", [_row(entry="1.1051")])
    mql5 = _write(tmp_path / "mql5.csv", [_row(entry="1.1050")])

    report = compare_multi_source_exports(reference, mql5)

    assert report.status == "mismatch"
    assert ("Wonderwhales", "entry", "value_mismatch") in _mismatch_fields(report)


def test_score_uses_its_own_tolerance(tmp_path: Path) -> None:
    reference = _write(tmp_path / "ref.csv", [_row(score="75.5000005")])
    mql5 = _write(tmp_path / "mql5.csv", [_row(score="75.5")])

    within = compare_multi_source_exports(reference, mql5, tolerance_score=1e-6)
    beyond = compare_multi_source_exports(reference, mql5, tolerance_score=1e-9)

    assert within.status == "match"
    assert beyond.status == "mismatch"
    assert ("Wonderwhales", "score", "value_mismatch") in _mismatch_fields(beyond)


def test_signal_missing_in_mql5(tmp_path: Path) -> None:
    reference = _write(tmp_path / "ref.csv", [_row(), _row("2026-01-05T10:05:00Z")])
    mql5 = _write(tmp_path / "mql5.csv", [_row()])

    report = compare_multi_source_exports(reference, mql5)

    assert report.mismatch_count == 1
    assert report.mismatches[0].kind == "missing_in_mql5"
    assert report.mismatches[0].bar_open_time == "2026-01-05T10:05:00Z"


def test_signal_missing_in_reference(tmp_path: Path) -> None:
    reference = _write(tmp_path / "ref.csv", [_row()])
    mql5 = _write(tmp_path / "mql5.csv", [_row(), _row("2026-01-05T10:05:00Z")])

    report = compare_multi_source_exports(reference, mql5)

    assert report.mismatch_count == 1
    assert report.mismatches[0].kind == "missing_in_reference"


def test_signal_id_and_side_mismatch(tmp_path: Path) -> None:
    reference = _write(tmp_path / "ref.csv", [_row()])
    mql5 = _write(
        tmp_path / "mql5.csv",
        [_row(signal_id="WW_SELL_SAR_FLIP", side="SELL", direction="-1")],
    )

    report = compare_multi_source_exports(reference, mql5)

    fields = {(item.field, item.kind) for item in report.mismatches}
    assert ("signal_id", "value_mismatch") in fields
    assert ("side", "value_mismatch") in fields
    assert ("dir", "value_mismatch") in fields


def test_dir_mismatch_reports_integer_values(tmp_path: Path) -> None:
    reference = _write(tmp_path / "ref.csv", [_row()])
    mql5 = _write(tmp_path / "mql5.csv", [_row(direction="-1")])

    report = compare_multi_source_exports(reference, mql5)

    mismatch = next(item for item in report.mismatches if item.field == "dir")
    assert mismatch.reference_value == 1
    assert mismatch.mql5_value == -1


def test_one_sided_nan_is_mismatch(tmp_path: Path) -> None:
    reference = _write(tmp_path / "ref.csv", [_row(tp3="1.1200")])
    mql5 = _write(tmp_path / "mql5.csv", [_row(tp3="")])

    report = compare_multi_source_exports(reference, mql5)

    assert ("Wonderwhales", "tp3", "nan_mismatch") in _mismatch_fields(report)


def test_both_empty_prices_are_equal(tmp_path: Path) -> None:
    reference = _write(tmp_path / "ref.csv", [_row(tp2="", tp3="")])
    mql5 = _write(tmp_path / "mql5.csv", [_row(tp2="", tp3="")])

    report = compare_multi_source_exports(reference, mql5)

    assert report.status == "match"


def test_duplicate_key_rejected(tmp_path: Path) -> None:
    path = _write(tmp_path / "dup.csv", [_row(), _row()])

    with pytest.raises(PineParityError, match="duplicate"):
        load_multi_source_csv(path)


def test_unknown_source_rejected(tmp_path: Path) -> None:
    path = _write(tmp_path / "unknown.csv", [_row(source="SomeOtherEA")])

    with pytest.raises(PineParityError, match="unknown source"):
        load_multi_source_csv(path)


def test_missing_required_column_rejected(tmp_path: Path) -> None:
    header = [column for column in HEADER if column != "score"]
    path = _write(tmp_path / "missing.csv", [_row()], header=header)

    with pytest.raises(PineParityError, match="missing required columns"):
        load_multi_source_csv(path)


def test_invalid_side_rejected(tmp_path: Path) -> None:
    path = _write(tmp_path / "side.csv", [_row(side="LONG")])

    with pytest.raises(PineParityError, match="invalid side"):
        load_multi_source_csv(path)


def test_confirmed_at_is_validated_when_present(tmp_path: Path) -> None:
    header = [*HEADER, "confirmed_at"]
    good = _row()
    good["confirmed_at"] = "2026-01-05T10:05:00Z"
    _write(tmp_path / "good.csv", [good], header=header)
    assert len(load_multi_source_csv(tmp_path / "good.csv")) == 1

    bad = _row()
    bad["confirmed_at"] = "2026-01-05T10:07:00Z"
    _write(tmp_path / "bad.csv", [bad], header=header)
    with pytest.raises(PineParityError, match="confirmed_at"):
        load_multi_source_csv(tmp_path / "bad.csv")


def test_offset_minutes_aligns_server_time(tmp_path: Path) -> None:
    reference = _write(tmp_path / "ref.csv", [_row(bar="2026-01-05T10:00:00Z")])
    mql5 = _write(tmp_path / "mql5.csv", [_row(bar="2026-01-05 13:00:00")])

    report = compare_multi_source_exports(
        reference, mql5, mql5_offset_minutes=180
    )

    assert report.status == "match"
    assert report.rows_compared == 1


def test_optional_text_columns_compared_when_both_present(tmp_path: Path) -> None:
    header = [*HEADER, "contract_version", "reason", "input_hash"]
    left = _row()
    left.update(contract_version="1.0.0", reason="REASON_3", input_hash="abc")
    right = _row()
    right.update(contract_version="1.0.0", reason="REASON_4", input_hash="abc")
    reference = _write(tmp_path / "ref.csv", [left], header=header)
    mql5 = _write(tmp_path / "mql5.csv", [right], header=header)

    report = compare_multi_source_exports(reference, mql5)

    assert report.mismatch_count == 1
    assert report.mismatches[0].field == "reason"


def test_per_source_summary(tmp_path: Path) -> None:
    ww = _row()
    lk = _row("2026-01-05T10:05:00Z", source="LongKacoVSA", signal_id="LK_BUY", score="")
    reference = _write(tmp_path / "ref.csv", [ww, lk])
    mql5 = _write(tmp_path / "mql5.csv", [ww])

    report = compare_multi_source_exports(reference, mql5)

    summary = {item.source: item for item in report.sources}
    assert summary["Wonderwhales"].mismatch_count == 0
    assert summary["LongKacoVSA"].mismatch_count == 1
    assert summary["LongKacoVSA"].compared_rows == 0


def test_write_report_creates_json_and_csv(tmp_path: Path) -> None:
    reference = _write(tmp_path / "ref.csv", [_row(entry="1.1051")])
    mql5 = _write(tmp_path / "mql5.csv", [_row(entry="1.1050")])
    report = compare_multi_source_exports(reference, mql5)

    json_path, csv_path = write_parity_report(report, tmp_path / "out")

    payload = json.loads(json_path.read_text(encoding="utf-8"))
    assert payload["status"] == "mismatch"
    assert payload["mismatch_count"] == 1
    header = csv_path.read_text(encoding="utf-8").splitlines()[0].split(",")
    assert tuple(header) == MISMATCH_COLUMNS


def test_cli_reports_blocked_when_reference_missing(tmp_path: Path, capsys) -> None:
    mql5 = _write(tmp_path / "mql5.csv", [_row()])

    code = comparator_cli.main(
        [
            "--reference",
            str(tmp_path / "absent_ref.csv"),
            "--mql5",
            str(mql5),
            "--out-dir",
            str(tmp_path / "out"),
        ]
    )

    assert code == comparator_cli.EXIT_BLOCKED
    assert "parity=BLOCKED" in capsys.readouterr().err
    assert not (tmp_path / "out").exists()


def test_cli_exit_codes_for_match_and_mismatch(tmp_path: Path) -> None:
    rows = [_row()]
    reference = _write(tmp_path / "ref.csv", rows)
    mql5 = _write(tmp_path / "mql5.csv", rows)
    args = [
        "--reference",
        str(reference),
        "--mql5",
        str(mql5),
        "--out-dir",
        str(tmp_path / "match"),
    ]
    assert comparator_cli.main(args) == comparator_cli.EXIT_MATCH

    mql5_bad = _write(tmp_path / "mql5_bad.csv", [_row(entry="1.2")])
    args = [
        "--reference",
        str(reference),
        "--mql5",
        str(mql5_bad),
        "--out-dir",
        str(tmp_path / "mismatch"),
    ]
    assert comparator_cli.main(args) == comparator_cli.EXIT_MISMATCH
