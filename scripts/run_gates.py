"""Run every Python gate in one command and print a PASS/FAIL table.

Gates (docs/README.md "Trạng thái cổng"):
  pytest                  - the Python test suite
  validate-project        - layout, banned APIs outside Exec/*, presets
  validate_demo_execution - demo-EA guardrails (InfiniteRunner)
  check_docs_links        - relative doc links resolve

The MQL5 compile needs MetaEditor and is NOT run here (reported as a note).

Exit code: 0 if every gate passed, 1 otherwise, 2 on a usage error.
Usage:
  .venv\\Scripts\\python.exe scripts\\run_gates.py
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# (name, argv). Python is sys.executable so it works inside .venv.
GATES = (
    ("pytest", [sys.executable, "-m", "pytest", "-q"]),
    ("validate-project", [sys.executable, "scripts/validate-project.py"]),
    ("validate_demo_execution", [sys.executable, "scripts/validate_demo_execution.py"]),
    ("check_docs_links", [sys.executable, "scripts/check_docs_links.py"]),
)


def _run_gate(name: str, argv: list[str], cwd: Path) -> dict:
    proc = subprocess.run(argv, cwd=str(cwd), capture_output=True, text=True)
    text = (proc.stdout or "").strip() or (proc.stderr or "").strip()
    tail = text.splitlines()[-1] if text else ""
    return {"name": name, "argv": argv, "returncode": proc.returncode,
            "ok": proc.returncode == 0, "tail": tail}


def run_gates(gates: list[tuple[str, list[str]]], cwd: Path,
              stream: bool = False) -> list[dict]:
    rows = []
    for name, argv in gates:
        if stream:
            print(f"RUN  {name} ...", flush=True)
        rows.append(_run_gate(name, argv, cwd))
    return rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args(argv)

    rows = run_gates(list(GATES), ROOT, stream=True)

    print()
    width = max(len(r["name"]) for r in rows) + 1
    for r in rows:
        status = "PASS" if r["ok"] else "FAIL"
        tail = ("  " + r["tail"]) if r["tail"] else ""
        print(f"{r['name']:<{width}} {status}{tail}")

    failed = [r["name"] for r in rows if not r["ok"]]
    print()
    print(f"SUMMARY: {len(rows) - len(failed)}/{len(rows)} pass")
    print("NOTE: MQL5 compile is manual (scripts/deploy_pineport.ps1 -Apply -Force; needs MetaEditor).")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
