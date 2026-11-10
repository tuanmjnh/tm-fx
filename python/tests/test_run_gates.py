"""Contract for scripts/run_gates.py (the one-command gate runner).

The runner must run each gate as a subprocess with the venv interpreter, report
PASS/FAIL from the exit code, and cover exactly the documented gates. The
subprocess mechanism is checked with trivial commands (no MT5 needed).
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "run_gates.py"


def _load():
    spec = importlib.util.spec_from_file_location("run_gates", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_gate_list_covers_the_documented_checks() -> None:
    names = {name for name, _argv in _load().GATES}
    assert names == {
        "pytest",
        "validate-project",
        "validate_demo_execution",
        "validate_pineport",
        "check_docs_links",
    }


def test_gates_use_the_venv_interpreter() -> None:
    for _name, argv in _load().GATES:
        assert argv[0] == sys.executable


def test_run_gates_reports_pass_and_fail(tmp_path: Path) -> None:
    module = _load()
    gates = [
        ("ok", [sys.executable, "-c", "print('fine')"]),
        ("bad", [sys.executable, "-c", "import sys; sys.exit(3)"]),
    ]
    rows = module.run_gates(gates, tmp_path)
    assert [r["ok"] for r in rows] == [True, False]
    assert rows[0]["tail"] == "fine"
    assert rows[1]["returncode"] == 3
