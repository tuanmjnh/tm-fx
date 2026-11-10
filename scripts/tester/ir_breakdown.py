"""Decompose an InfiniteRunner journal by side x year x tail (experiment E1).

The long-window InfiniteRunner journals (``analyse_ir.py``) show a small POSITIVE
gross edge when winners are allowed to run (net + N*spread > 0) while the
fixed-SL/TP runs sit at zero. E1 asks whether that gross comes from a real
effect or from a market-wide drift / a few lucky trades, by splitting it three
ways:

  * by SIDE (BUY vs SELL) - a drift captured by a long-biased rule shows up on
    one side only;
  * by YEAR - a real effect is present across years, a regime artefact is not;
  * by TAIL - drop the best ``--tail-frac`` of trades (by net P&L) and see if the
    gross survives.

Gross per trade = net_pnl + spread_cost, where spread_cost = spread_price *
volume * contract (XAUUSDm contract = 100 oz/lot). The spread is an INPUT
(``--spread-price``, default 0.19) reconstructed from the fixed-SL/TP runs; the
result is therefore approximate and labelled NOT_STRATEGY_RESULT.

Streaming: the journal is read once; only one small tuple per closed trade is
kept (not the rows), so a ~190 MB journal is fine.

Usage:
  .venv\\Scripts\\python.exe scripts\\tester\\ir_breakdown.py <journal.csv> [--spread-price 0.19]
  .venv\\Scripts\\python.exe scripts\\tester\\ir_breakdown.py <journal.csv> --json out.json

Exit codes: 0 ok, 2 unreadable/empty input.
"""
from __future__ import annotations

import argparse
import collections
import csv
import json
import re
import sys
from pathlib import Path

CONTRACT = 100.0          # XAUUSDm ounces per lot
PNL_RE = re.compile(r"\|pnl=(-?\d+(?:\.\d+)?)")


def _trades(path: Path, spread_price: float) -> list[dict]:
    """One dict per closed trade, read in a single pass."""
    trades: list[dict] = []
    side = ""
    volume = 0.0
    risk = 0.0
    with path.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            ev = row.get("event", "")
            if ev == "ENTRY":
                side = (row.get("side", "") or "").strip()
                try:
                    price = float(row.get("price", "0") or 0)
                    sl = float(row.get("sl", "0") or 0)
                    volume = float(row.get("volume", "0") or 0)
                except ValueError:
                    price = sl = volume = 0.0
                risk = abs(price - sl) * volume * CONTRACT
            elif ev == "EXIT":
                m = PNL_RE.search(row.get("reason", ""))
                pnl = float(m.group(1)) if m else 0.0
                cost = spread_price * volume * CONTRACT
                trades.append({
                    "side": side or (row.get("side", "") or "").strip(),
                    "year": (row.get("bar_time", "") or "")[:4],
                    "pnl": pnl,
                    "risk": risk,
                    "gross": pnl + cost,
                })
    return trades


def _agg(trades: list[dict]) -> dict:
    n = len(trades)
    if n == 0:
        return {"n": 0, "net": 0.0, "gross": 0.0, "net_per_trade": 0.0,
                "gross_per_trade": 0.0, "net_r": 0.0, "gross_r": 0.0}
    net = sum(t["pnl"] for t in trades)
    gross = sum(t["gross"] for t in trades)
    risk = sum(t["risk"] for t in trades)
    return {
        "n": n,
        "net": net,
        "gross": gross,
        "net_per_trade": net / n,
        "gross_per_trade": gross / n,
        "net_r": (net / risk) if risk else 0.0,
        "gross_r": (gross / risk) if risk else 0.0,
    }


def breakdown(path: Path, spread_price: float, tail_frac: float) -> dict:
    trades = _trades(path, spread_price)
    if not trades:
        raise ValueError(f"no closed trades in {path}")

    by_side: dict[str, list[dict]] = collections.defaultdict(list)
    by_year: dict[str, list[dict]] = collections.defaultdict(list)
    for t in trades:
        by_side[t["side"] or "?"].append(t)
        by_year[t["year"] or "?"].append(t)

    #--- Tail: drop the best tail_frac of trades (by net P&L) and recompute.
    ranked = sorted(trades, key=lambda t: t["pnl"])
    drop = int(round(len(ranked) * tail_frac))
    kept = ranked[: len(ranked) - drop] if drop > 0 else ranked
    dropped = ranked[len(ranked) - drop:] if drop > 0 else []
    tail = {
        "drop_n": len(dropped),
        "drop_net": sum(t["pnl"] for t in dropped),
        "kept": _agg(kept),
    }

    return {
        "path": str(path),
        "spread_price": spread_price,
        "tail_frac": tail_frac,
        "overall": _agg(trades),
        "by_side": {k: _agg(v) for k, v in sorted(by_side.items())},
        "by_year": {k: _agg(v) for k, v in sorted(by_year.items())},
        "tail": tail,
    }


def _row(label: str, a: dict) -> str:
    return (f"  {label:14s} n={a['n']:6d} net={a['net']:9.1f} "
            f"gross={a['gross']:9.1f} ({a['gross_r']:+.4f}R/trade) "
            f"net_R={a['net_r']:+.4f}")


def render(r: dict) -> str:
    o = r["overall"]
    lines = [
        "LABEL: NOT_STRATEGY_RESULT (operational/measurement; spread is an input)",
        f"IR BREAKDOWN {Path(r['path']).name}  spread_price={r['spread_price']}",
        _row("OVERALL", o),
        "  by side:",
    ]
    for k, a in r["by_side"].items():
        lines.append(_row(k, a))
    lines.append("  by year:")
    for k, a in r["by_year"].items():
        lines.append(_row(k, a))
    t = r["tail"]
    lines.append(f"  tail: dropped {t['drop_n']} best trades "
                 f"(net={t['drop_net']:.1f}); survivors:")
    lines.append(_row("kept", t["kept"]))
    return "\n".join(lines)


def _journal_files(target: Path) -> list[Path]:
    if target.is_dir():
        return sorted(p for p in target.rglob("sim_*.csv")
                      if "_telemetry" not in p.name and "_census" not in p.name)
    return [target]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", help="journal CSV or a directory of journals")
    parser.add_argument("--spread-price", type=float, default=0.19,
                        help="implied spread in price units (XAUUSDm default 0.19)")
    parser.add_argument("--tail-frac", type=float, default=0.005,
                        help="fraction of best trades to drop for the tail test")
    parser.add_argument("--json", default="", help="also write JSON here")
    args = parser.parse_args()

    target = Path(args.target)
    if not target.exists():
        print(f"ERROR: not found: {target}", file=sys.stderr)
        return 2
    paths = _journal_files(target)
    if not paths:
        print(f"ERROR: no journal matched under {target}", file=sys.stderr)
        return 2

    results = []
    for path in paths:
        try:
            result = breakdown(path, args.spread_price, args.tail_frac)
        except (OSError, ValueError) as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
        results.append(result)
        print(render(result))
        print()

    if args.json:
        payload = results[0] if len(results) == 1 else results
        Path(args.json).write_text(
            json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8", newline="\n")
        print(f"WROTE {args.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
