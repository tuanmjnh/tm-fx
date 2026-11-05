"""Source-level contract for scripts/tester/run_tester.ps1.

The runner is the only script that starts the MT5 terminal, so it must fail
closed instead of archiving a run that never happened.
"""
from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
RUNNER = REPO_ROOT / "scripts" / "tester" / "run_tester.ps1"


def _text() -> str:
    return RUNNER.read_text(encoding="utf-8")


def test_runner_fails_closed_when_no_bars_loaded() -> None:
    #--- Regression: on 2026-11-05 a 12-second run exited 0 with a report of
    #--- History Quality n/a / Bars 0 and the previous run's CSV was archived.
    text = _text()
    assert "Bars:</td>" in text
    assert "loaded no bars" in text
    assert "archive left untouched" in text


def test_runner_clears_the_archive_only_after_validation() -> None:
    text = _text()
    validate_at = text.index("loaded no bars")
    clear_at = text.index("Get-ChildItem $OutDir -File")
    copy_at = text.index("$copied = @()")
    assert validate_at < clear_at < copy_at
