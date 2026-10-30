#!/usr/bin/env python3
"""Fail-closed validator for simulation-only configuration and MQL5 source."""
from __future__ import annotations
import argparse, json, re, sys
from pathlib import Path

FORBIDDEN_SOURCE_PATTERNS = [
    r'\bOrderSend\s*\(',
    r'\bOrderSendAsync\s*\(',
    r'\bMqlTradeRequest\b',
    r'\bCTrade\b',
    r'\bPositionOpen\s*\(',
    r'\bPositionClose\s*\(',
    r'\bPositionClosePartial\s*\(',
    r'\bOrderOpen\s*\(',
    r'\bOrderModify\s*\(',
]

def strip_comments_and_strings(source: str) -> str:
    # Approximate scanner sufficient for accidental API use detection, not a full MQL parser.
    source = re.sub(r'/\*[\s\S]*?\*/', ' ', source)
    source = re.sub(r'//[^\n]*', ' ', source)
    source = re.sub(r'"(?:\\.|[^"\\])*"', '""', source)
    return source

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', default='configs/project.example.json')
    parser.add_argument('--project-root', default='.')
    args = parser.parse_args()
    root = Path(args.project_root).resolve()
    config_path = (root / args.config).resolve()
    errors: list[str] = []
    try:
        cfg = json.loads(config_path.read_text(encoding='utf-8'))
    except Exception as exc:
        print(f'FAIL: unable to read config {config_path}: {exc}')
        return 2
    if cfg.get('execution_mode') != 'SIMULATION_ONLY':
        errors.append('execution_mode must equal SIMULATION_ONLY')
    if cfg.get('allow_live_trading') is not False:
        errors.append('allow_live_trading must be false')
    risk = cfg.get('risk_defaults', {})
    numeric_positive = ['max_virtual_positions', 'max_grid_levels', 'max_virtual_exposure', 'max_daily_loss_pct', 'max_drawdown_pct', 'max_spread_points']
    for key in numeric_positive:
        try:
            val = float(risk[key])
            if val <= 0: errors.append(f'risk_defaults.{key} must be > 0')
        except Exception:
            errors.append(f'risk_defaults.{key} is missing or not numeric')
    try:
        adds = int(risk['max_dca_adds'])
        if adds < 0: errors.append('risk_defaults.max_dca_adds must be >= 0')
    except Exception: errors.append('risk_defaults.max_dca_adds is missing or invalid')
    if errors:
        for e in errors: print('FAIL:', e)
        return 1

    source_dir = root / 'MQL5' / 'Experts' / 'MT5EALab'
    files = list(source_dir.rglob('*.mq5')) if source_dir.exists() else []
    for path in files:
        source = strip_comments_and_strings(path.read_text(encoding='utf-8', errors='replace'))
        for pat in FORBIDDEN_SOURCE_PATTERNS:
            if re.search(pat, source, re.IGNORECASE):
                errors.append(f'forbidden trading API pattern {pat!r} found in {path.relative_to(root)}')
    if errors:
        for e in errors: print('FAIL:', e)
        return 1
    print(f'PASS: simulation-only config validated; scanned {len(files)} MQL5 source file(s).')
    if not files:
        print('NOTE: no MQL5 source files found yet; source-level scan was vacuous, not proof of a completed EA.')
    return 0

if __name__ == '__main__':
    sys.exit(main())
