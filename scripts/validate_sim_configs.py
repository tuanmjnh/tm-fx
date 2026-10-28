"""Fail-closed validation for Track C simulation presets.

Checks every preset in ``configs/sim`` and ``configs/project.example.json``
against the EA input contracts in :mod:`mt5_ea_ai_lab.sim_configs`, including
project scenarios with overrides. Snapshots are written once per config hash
and never overwritten.

Simulation only: this script reads local JSON and writes local reports. It does
not connect to a broker, open an account, compile MQL5 or send any order.

Exit codes:
    0  every preset and scenario passed
    1  at least one validation failed
    2  the project root or config directory could not be read
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "python" / "src"))

from mt5_ea_ai_lab.sim_configs import (  # noqa: E402
    preset_files,
    validate_preset,
    validate_project,
    write_snapshot,
)


def _load(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="project root (default: repository root)",
    )
    parser.add_argument(
        "--snapshot-dir",
        default="reports/config-snapshots",
        help="directory for immutable config snapshots",
    )
    parser.add_argument(
        "--no-snapshot",
        action="store_true",
        help="validate only; do not write snapshots",
    )
    args = parser.parse_args(argv)

    root: Path = args.root.resolve()
    configs_dir = root / "configs" / "sim"
    if not configs_dir.is_dir():
        print(f"ERROR: missing {configs_dir}", file=sys.stderr)
        return 2

    failures = 0
    checked = 0
    snapshot_dir = root / args.snapshot_dir

    for path in preset_files(configs_dir):
        checked += 1
        try:
            config = _load(path)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"FAIL: {path.name}: cannot read: {exc}")
            failures += 1
            continue
        issues = validate_preset(config)
        if issues:
            failures += 1
            print(f"FAIL: {path.name}")
            for issue in issues:
                print(f"  - {issue}")
            continue
        print(f"PASS: {path.name} (ea={config['ea']})")
        if not args.no_snapshot and isinstance(config, dict):
            snapshot, created = write_snapshot(snapshot_dir, config)
            print(f"  snapshot: {snapshot.relative_to(root)} "
                  f"({'written' if created else 'unchanged'})")

    project_path = root / "configs" / "project.example.json"
    if project_path.exists():
        checked += 1
        try:
            project = _load(project_path)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"FAIL: {project_path.name}: cannot read: {exc}")
            failures += 1
        else:
            issues = validate_project(project, root)
            if issues:
                failures += 1
                print(f"FAIL: {project_path.name}")
                for issue in issues:
                    print(f"  - {issue}")
            else:
                scenario_count = len(project.get("scenarios", []))
                preset_count = len(project.get("presets", {}))
                print(
                    f"PASS: {project_path.name} "
                    f"(presets={preset_count} scenarios={scenario_count})"
                )
                if not args.no_snapshot:
                    snapshot, created = write_snapshot(snapshot_dir, project)
                    print(f"  snapshot: {snapshot.relative_to(root)} "
                          f"({'written' if created else 'unchanged'})")
    else:
        print("FAIL: configs/project.example.json is missing")
        failures += 1

    print(f"SUMMARY: checked={checked} fail={failures}")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
