"""Source-level contracts for the shared root scripts (W7)."""

from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = REPO_ROOT / "scripts"


def _text(name: str) -> str:
    return (SCRIPTS / name).read_text(encoding="utf-8")


def test_build_script_fails_closed_on_missing_log_and_ex5() -> None:
    text = _text("build-mql5.ps1")
    assert "MetaEditor did not write a log" in text
    assert "log has no Result line" in text
    assert "no .ex5 was produced" in text
    assert "BUILD_FAILED" in text
    assert r"Result:\s*(\d+)\s+errors?," in text


def test_build_script_discovers_sources() -> None:
    text = _text("build-mql5.ps1")
    assert "Get-ChildItem" in text
    assert "-Filter \"*.mq5\"" in text
    assert "Where-Object" in text


def test_check_environment_reads_no_file_content() -> None:
    text = _text("check-environment.ps1")
    assert "SUMMARY: checks=" in text
    assert "[version]\"3.11\"" in text
    assert "Get-Command" in text
    assert "No broker connection" in text
    assert "Get-Content" not in text


def test_run_python_tests_propagates_exit_code() -> None:
    text = _text("run-python-tests.ps1")
    assert "Push-Location" in text
    assert "$LASTEXITCODE" in text
    assert "exit $code" in text
    assert "TESTS_FAILED" in text


def test_package_script_excludes_and_scans() -> None:
    text = _text("package-source.ps1")
    for segment in (".venv", "__pycache__", "reports", "data", "models"):
        assert f'"{segment}"' in text
    assert "Package aborted before copying" in text
    assert "PACKAGE_SHA256" in text
    assert "UTF8Encoding($false)" in text


def test_validate_project_script_is_simulation_only_scanner() -> None:
    text = _text("validate-project.py")
    assert "FORBIDDEN_API" in text
    assert "FORBIDDEN_INCLUDE" in text
    assert "sim_configs" in text
    assert "no broker was contacted" in text
