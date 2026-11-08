"""One-command parity check for the Wonderwhales 2-mode gate.

Wraps ``scripts/compare_pine_exports.py`` with the WW2 defaults and, more
importantly, enforces the decision rule that was agreed BEFORE any result was
seen (docs/10-bots/wonderwhales-2mode.md section 5.3):

    InpRequireParity may be set to false only when the report is
    status=match, mismatch_count=0, over at least --min-signals signals.

The script never creates or edits reference data: it reads the two exports, runs
the existing comparator, and prints/records ALLOW_FLIP or KEEP_BLOCKED.

Exit codes:
    0  compared, decision ALLOW_FLIP
    1  compared, decision KEEP_BLOCKED (mismatch, or sample too small)
    2  an input/argument/schema problem
    3  BLOCKED: one of the two exports does not exist

Usage:
  .venv\\Scripts\\python.exe scripts\\ww2_parity_check.py ^
      --pine reports\\pine_parity\\pine_reference.csv ^
      --mql5 reports\\build\\tester-reports\\portref_sig_m5\\sim_portref_sig_m5.csv
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

from mt5_ea_ai_lab.evaluation.pine_parity import (  # noqa: E402
    REQUIRED_COLUMNS,
    PineParityError,
    compare_pine_exports,
    write_report,
)

EXIT_ALLOW = 0
EXIT_KEEP_BLOCKED = 1
EXIT_INVALID = 2
EXIT_BLOCKED = 3

DECISION_RULE = (
    "InpRequireParity may be set to false only when status=match, "
    "mismatch_count=0, and rows_compared >= min-signals."
)


def _resolve(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else (REPO_ROOT / candidate)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pine", required=True,
                        help="reference CSV exported from TradingView (UTC)")
    parser.add_argument("--mql5", required=True,
                        help="CSV written by PineSignalLabEA (broker server time)")
    parser.add_argument("--out-dir", default="reports/pine_parity")
    parser.add_argument("--mql5-offset-minutes", type=float, default=180.0,
                        help="broker server offset east of UTC (Exness GMT+3 = 180)")
    parser.add_argument("--pine-offset-minutes", type=float, default=0.0)
    parser.add_argument("--warmup-bars", type=int, default=300)
    parser.add_argument("--bar-times", default=None,
                        help="CSV with a bar_open_time column (required for --warmup-bars)")
    parser.add_argument("--min-signals", type=int, default=100,
                        help="decision rule minimum for rows_compared")
    parser.add_argument("--tolerance-price", type=float, default=1e-8)
    parser.add_argument("--tolerance-oscillator", type=float, default=1e-6)
    return parser


def _read_rows(path: Path) -> list[dict[str, str]]:
    import csv

    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def _describe(path: Path, label: str) -> dict:
    """Report symbol/timeframe/signal counts, and reject a wrong schema."""

    try:
        rows = _read_rows(path)
    except OSError as exc:
        raise PineParityError(f"cannot read {label} export {path}: {exc}") from exc
    if not rows:
        raise PineParityError(f"{label} export has no data rows: {path}")

    missing = [c for c in REQUIRED_COLUMNS if c not in rows[0]]
    if missing:
        raise PineParityError(
            f"{label} export is missing required columns: {', '.join(missing)}")

    symbols = {row.get("symbol", "").strip() for row in rows}
    timeframes = {row.get("timeframe", "").strip() for row in rows}
    buys = sum(1 for row in rows if row.get("side", "").strip() == "BUY")
    sells = sum(1 for row in rows if row.get("side", "").strip() == "SELL")
    signals = sum(1 for row in rows if row.get("signal_id", "").strip())
    return {
        "rows": len(rows),
        "symbols": sorted(symbols),
        "timeframes": sorted(timeframes),
        "buys": buys,
        "sells": sells,
        "signals": signals,
    }


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    pine_path = _resolve(args.pine)
    mql5_path = _resolve(args.mql5)
    out_dir = _resolve(args.out_dir)
    bar_times = _resolve(args.bar_times) if args.bar_times else None

    for label, path in (("pine", pine_path), ("mql5", mql5_path)):
        if not path.is_file():
            print(f"parity=BLOCKED reason={label}_file_missing path={path}",
                  file=sys.stderr)
            print(f"DECISION: KEEP_BLOCKED ({DECISION_RULE})")
            return EXIT_BLOCKED

    try:
        pine = _describe(pine_path, "pine")
        mql5 = _describe(mql5_path, "mql5")
        report = compare_pine_exports(
            pine_path,
            mql5_path,
            tolerance_price=args.tolerance_price,
            tolerance_oscillator=args.tolerance_oscillator,
            pine_offset_minutes=args.pine_offset_minutes,
            mql5_offset_minutes=args.mql5_offset_minutes,
            warmup_bars=args.warmup_bars,
            bar_times_path=bar_times,
        )
        json_path, csv_path = write_report(report, out_dir)
    except (PineParityError, OSError) as exc:
        print(f"parity=INVALID reason={exc}", file=sys.stderr)
        print(f"DECISION: KEEP_BLOCKED ({DECISION_RULE})")
        return EXIT_INVALID

    print(f"pine rows={pine['rows']} buy={pine['buys']} sell={pine['sells']} "
          f"symbols={','.join(pine['symbols'])} timeframes={','.join(pine['timeframes'])}")
    print(f"mql5 rows={mql5['rows']} buy={mql5['buys']} sell={mql5['sells']} "
          f"symbols={','.join(mql5['symbols'])} timeframes={','.join(mql5['timeframes'])}")

    #--- The comparator matches `symbol` exactly; flag the known trap before it
    #--- turns every row into missing_in_*.
    if pine["symbols"] != mql5["symbols"]:
        print("WARN: symbol values differ between the exports "
              f"(pine={pine['symbols']} mql5={mql5['symbols']}); the comparator "
              "matches them exactly, so normalise the Pine export's symbol column "
              "to the broker symbol before trusting the result.")

    print(f"status={report.status} rows_compared={report.rows_compared} "
          f"mismatches={report.mismatch_count} "
          f"mql5_offset_minutes={report.mql5_offset_minutes:g}")

    enough = report.rows_compared >= args.min_signals
    allow = (report.status == "match" and report.mismatch_count == 0 and enough)
    decision = "ALLOW_FLIP" if allow else "KEEP_BLOCKED"
    reasons = []
    if report.status != "match":
        reasons.append(f"status={report.status}")
    if report.mismatch_count:
        reasons.append(f"mismatches={report.mismatch_count}")
    if not enough:
        reasons.append(f"rows_compared={report.rows_compared} < min_signals={args.min_signals}")

    out_dir.mkdir(parents=True, exist_ok=True)
    decision_path = out_dir / "ww2_parity_decision.txt"
    decision_path.write_text(
        "\n".join([
            f"DECISION: {decision}",
            f"RULE: {DECISION_RULE}",
            f"status={report.status}",
            f"mismatch_count={report.mismatch_count}",
            f"rows_compared={report.rows_compared}",
            f"min_signals={args.min_signals}",
            f"pine={pine_path}",
            f"mql5={mql5_path}",
            f"reason={'; '.join(reasons) if reasons else 'none'}",
            "NOTE: parity OFF (InpRequireParity=false) must be set by the operator",
            "      only after ALLOW_FLIP; see docs/10-bots/wonderwhales-2mode.md 5.3.",
            "",
        ]),
        encoding="utf-8",
    )

    print(f"DECISION: {decision}" + (f" ({'; '.join(reasons)})" if reasons else ""))
    print(f"RULE: {DECISION_RULE}")
    print(f"report_json={json_path}")
    print(f"report_csv={csv_path}")
    print(f"decision_file={decision_path}")
    return EXIT_ALLOW if allow else EXIT_KEEP_BLOCKED


if __name__ == "__main__":
    raise SystemExit(main())
