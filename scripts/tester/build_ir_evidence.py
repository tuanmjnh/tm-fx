"""Assemble the small, committed InfiniteRunner evidence pack.

The raw tester artefacts (sim_*.csv journals up to ~190 MB, tester_*.htm reports)
stay local because reports/ is gitignored. This script copies the tiny equity PNG
and a compact JSON metric summary for each scenario into a TRACKED folder:

  docs/30-research/evidence/infinite-runner/
    README.md            what each scenario is + how to reproduce
    summary.csv          one row per scenario (key metrics, for diffing)
    <scenario>.json      full analyse_ir.analyse() result + source hashes
    <scenario>.png       equity snapshot from the tester report

Run it after a tester run (reports/build/tester-reports/<scenario>/ must exist).

Usage:
  .venv\\Scripts\\python.exe scripts\\tester\\build_ir_evidence.py
"""
from __future__ import annotations

import csv
import hashlib
import importlib.util
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORTS = ROOT / "reports/build/tester-reports"
EVIDENCE = ROOT / "docs/30-research/evidence/infinite-runner"

# scenario order = reading order in the study
SCENARIOS = (
    "infinite_runner_demo_exec",
    "infinite_runner_fixcheck",
    "infinite_runner_long_baseline",
    "infinite_runner_long_base_nolock",
    "infinite_runner_long_exit_run",
    "infinite_runner_long_fixedrr",
    "infinite_runner_long_fixedrr15",
    "infinite_runner_long_fixedrr_clean",
    "infinite_runner_long_mtf",
)

DESCRIPTIONS = {
    "infinite_runner_demo_exec": "shipped preset, 2026.01.05-10.01 (the run that deadlocked after 2 days, 101 trades)",
    "infinite_runner_fixcheck": "U1 fix on the SAME window: trades all 9 months instead of deadlocking",
    "infinite_runner_long_baseline": "2018-2026 shipped inputs; halts permanently at 8% drawdown on 2020.06.23",
    "infinite_runner_long_base_nolock": "2018-2026 reference: shipped step trailing, daily/DD halts off",
    "infinite_runner_long_exit_run": "U2: step trailing off so the fixed runner trail works (let winners run)",
    "infinite_runner_long_fixedrr": "U3: no trail, SL 1R / TP 1R -> raw entry edge (break-even winrate 50%)",
    "infinite_runner_long_fixedrr15": "U3 cross-check: SL 1R / TP 1.5R (break-even winrate 40%)",
    "infinite_runner_long_fixedrr_clean": "U3 definitive: 1:1 with every guard off (no censoring)",
    "infinite_runner_long_mtf": "2018-2026 with InpDirectionMode=1 (IR_DIR_EMA_MTF): 31 trades / 8.75 years",
}

#--- Experiment E1: decompose the faint positive gross of the two "let winners
#--- run" journals by side x year x tail (see the long-run study section 5).
E1_SCENARIOS = ("infinite_runner_long_base_nolock", "infinite_runner_long_exit_run")

CSV_COLUMNS = ("scenario", "trades", "wins", "losses", "winrate", "net",
               "expectancy_r", "expectancy_usd", "profit_factor",
               "max_drawdown_pct", "tp_hits", "net_without_tp")


def _load(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _load_analyse_ir():
    return _load(Path(__file__).with_name("analyse_ir.py"), "analyse_ir")


def _load_ir_breakdown():
    return _load(Path(__file__).with_name("ir_breakdown.py"), "ir_breakdown")


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _find(scenario_dir: Path, pattern: str) -> Path | None:
    hits = [p for p in sorted(scenario_dir.glob(pattern))
            if "_telemetry" not in p.name and "_census" not in p.name]
    return hits[0] if hits else None


def main() -> int:
    analyse_ir = _load_analyse_ir()
    EVIDENCE.mkdir(parents=True, exist_ok=True)

    rows = []
    for scenario in SCENARIOS:
        sdir = REPORTS / scenario
        journal = _find(sdir, "sim_*.csv")
        if journal is None:
            print(f"SKIP {scenario}: no journal under {sdir}")
            continue
        result = analyse_ir.analyse(journal)
        png = _find(sdir, "tester_*.png")
        htm = _find(sdir, "tester_*.htm")
        result["source"] = {
            "journal": journal.name,
            "journal_sha256": _sha256(journal),
            "report_sha256": _sha256(htm) if htm else None,
            "png_sha256": _sha256(png) if png else None,
        }
        result["description"] = DESCRIPTIONS.get(scenario, "")
        if png:
            shutil.copyfile(png, EVIDENCE / f"{scenario}.png")

        (EVIDENCE / f"{scenario}.json").write_text(
            json.dumps(result, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8", newline="\n")

        rows.append({
            "scenario": scenario,
            "trades": result["trades"],
            "wins": result["wins"],
            "losses": result["losses"],
            "winrate": round(result["winrate"], 2),
            "net": round(result["net"], 2),
            "expectancy_r": round(result["expectancy_r"], 4),
            "expectancy_usd": round(result["expectancy_usd"], 3),
            "profit_factor": round(result["profit_factor"], 3),
            "max_drawdown_pct": round(result["max_drawdown_pct"], 2),
            "tp_hits": result["tp_hits"],
            "net_without_tp": round(result["net_without_tp"], 2),
        })
        print(f"WROTE {scenario}: trades={result['trades']} net={result['net']:.2f}")

    with (EVIDENCE / "summary.csv").open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(CSV_COLUMNS))
        writer.writeheader()
        writer.writerows(rows)

    #--- E1: split the gross edge of the two "let winners run" journals.
    e1 = {}
    breakdown = _load_ir_breakdown()
    for scenario in E1_SCENARIOS:
        journal = _find(REPORTS / scenario, "sim_*.csv")
        if journal is None:
            continue
        e1[scenario] = breakdown.breakdown(journal, 0.19, 0.005)
        (EVIDENCE / f"e1_{scenario}.json").write_text(
            json.dumps(e1[scenario], indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8", newline="\n")
        print(f"WROTE e1_{scenario}.json")

    lines = [
        "# InfiniteRunner evidence pack",
        "",
        "Small, committed evidence for the study "
        "[`../../infinite-runner-study.md`](../../infinite-runner-study.md). The raw",
        "tester artefacts (journals up to ~190 MB, HTML reports) live locally under",
        "`reports/build/tester-reports/` and are gitignored; only the equity PNG and a",
        "compact metric JSON per scenario are committed.",
        "",
        "Regenerate with:",
        "",
        "```powershell",
        ".venv\\Scripts\\python.exe scripts\\tester\\gen_ir_sets.py",
        "scripts\\tester\\run_tester.ps1 -Scenario <scenario> -TimeoutSec 10800",
        ".venv\\Scripts\\python.exe scripts\\tester\\build_ir_evidence.py",
        "```",
        "",
        "Every number is `NOT_STRATEGY_RESULT` (operational/measurement); evidence",
        "`NOT_RUN`, profit `UNPROVEN`.",
        "",
        "| scenario | description | trades | winrate | net | exp R | PF | maxDD | TP hits |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in rows:
        lines.append(
            f"| `{row['scenario']}` | {DESCRIPTIONS.get(row['scenario'], '')} | "
            f"{row['trades']} | {row['winrate']:.2f}% | {row['net']:.2f} | "
            f"{row['expectancy_r']:.4f} | {row['profit_factor']:.3f} | "
            f"{row['max_drawdown_pct']:.2f}% | {row['tp_hits']} |")
    if e1:
        lines += [
            "",
            "## Experiment E1 — gross decomposition (side x year x tail)",
            "",
            "Gross per trade = net P&L + spread cost (`--spread-price` 0.19). A broad",
            "edge survives on both sides and across years AND does not vanish when the",
            "best 0.5% of trades are removed. Anything else is luck / drift.",
            "",
            "| scenario | overall gross R | BUY gross R | SELL gross R | gross R without best 0.5% |",
            "|---|---:|---:|---:|---:|",
        ]
        for scenario, r in e1.items():
            by_side = r["by_side"]
            lines.append(
                f"| `{scenario}` | {r['overall']['gross_r']:+.4f} | "
                f"{by_side.get('BUY', {}).get('gross_r', 0.0):+.4f} | "
                f"{by_side.get('SELL', {}).get('gross_r', 0.0):+.4f} | "
                f"{r['tail']['kept']['gross_r']:+.4f} |")
    lines.append("")
    (EVIDENCE / "README.md").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"WROTE {EVIDENCE / 'summary.csv'} ({len(rows)} rows)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
