"""Streaming economics summary for InfiniteRunner journals (18-column SimLogger).

Unlike ``analyse_measure.py`` this reads the journal in a single pass (nothing is
loaded into memory), because the InfiniteRunner long-window runs produce journals
up to ~190 MB. It pairs each ENTRY with the next EXIT (one runner position at a
time) to compute the money risk and the realised R.

Money risk = |price - sl| * volume * contract (XAUUSDm contract = 100 oz/lot).
A win at R >= 19.5 is counted as a "safety TP" hit because InpSafetyTpPoints is a
fixed far TP: with SL 5000 pts (1R) and TP 100000 pts that is a 20R target.

T2.2 additions (the long-run study §3-§4):
  * break-even winrate p* = avg_loss / (avg_win + avg_loss) and the gap to it;
  * the implied spread model: gross = net + N * spread_cost, and the sensitivity
    net - N * spread_cost (i.e. a doubled spread), with --spread-price;
  * a bootstrap 95% CI for expectancy in USD and in R (seeded, so reproducible).

Every InfiniteRunner tester run is an operational/measurement run, so the output
is labelled NOT_STRATEGY_RESULT.

Usage:
  .venv\\Scripts\\python.exe scripts\\tester\\analyse_ir.py <journal.csv> [--json out.json]
  .venv\\Scripts\\python.exe scripts\\tester\\analyse_ir.py <dir-of-journals>

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

import numpy as np

CONTRACT = 100.0          # XAUUSDm ounces per lot
TP_R = 19.5               # a win at/above this is the 20R safety TP being hit
PNL_RE = re.compile(r"\|pnl=(-?\d+(?:\.\d+)?)")


def journal_files(target: Path) -> list[Path]:
    if target.is_dir():
        return sorted(p for p in target.rglob("sim_*.csv")
                      if "_telemetry" not in p.name and "_census" not in p.name)
    return [target]


def _bootstrap_mean_ci(values: list[float], samples: int, seed: int) -> list[float]:
    """Percentile 2.5/97.5 CI of the mean, seeded for reproducibility."""
    arr = np.asarray(values, dtype=float)
    n = arr.size
    if n == 0 or samples <= 0:
        return [0.0, 0.0]
    rng = np.random.default_rng(seed)
    means = np.empty(samples, dtype=float)
    for i in range(samples):
        means[i] = arr[rng.integers(0, n, size=n)].mean()
    lo, hi = np.percentile(means, [2.5, 97.5])
    return [float(lo), float(hi)]


def analyse(path: Path, spread_price: float = 0.19, ci_samples: int = 1000,
            ci_seed: int = 12345) -> dict:
    events: collections.Counter[str] = collections.Counter()
    blocks: collections.Counter[str] = collections.Counter()
    entries_by_year: collections.Counter[str] = collections.Counter()
    exits_by_year: collections.Counter[str] = collections.Counter()

    n_trades = wins = losses = flats = 0
    gross_win = gross_loss = 0.0
    net = 0.0
    sum_win = sum_loss = 0.0
    tp_hits = 0
    tp_contrib = 0.0
    r_all: list[float] = []
    pnls: list[float] = []
    spread_cost_total = 0.0

    peak = max_dd = 0.0
    peak_at = trough_at = 0.0
    cur_risk = 0.0
    cur_volume = 0.0

    with path.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            ev = row.get("event", "")
            events[ev] += 1
            try:
                equity = float(row.get("equity", "0") or 0)
            except ValueError:
                equity = 0.0
            if equity > 0.0:
                if equity > peak:
                    peak = equity
                    peak_at = equity
                elif peak > 0.0:
                    dd = (peak - equity) / peak * 100.0
                    if dd > max_dd:
                        max_dd = dd
                        trough_at = equity

            if ev == "ENTRY":
                try:
                    price = float(row.get("price", "0") or 0)
                    sl = float(row.get("sl", "0") or 0)
                    cur_volume = float(row.get("volume", "0") or 0)
                except ValueError:
                    price = sl = cur_volume = 0.0
                cur_risk = abs(price - sl) * cur_volume * CONTRACT
                entries_by_year[(row.get("bar_time", "")[:4])] += 1
            elif ev == "EXIT":
                m = PNL_RE.search(row.get("reason", ""))
                pnl = float(m.group(1)) if m else 0.0
                n_trades += 1
                net += pnl
                pnls.append(pnl)
                spread_cost_total += spread_price * cur_volume * CONTRACT
                if pnl > 0.0:
                    wins += 1
                    sum_win += pnl
                    gross_win += pnl
                elif pnl < 0.0:
                    losses += 1
                    sum_loss += pnl
                    gross_loss += -pnl
                else:
                    flats += 1
                if cur_risk > 0.0:
                    r = pnl / cur_risk
                    r_all.append(r)
                    if r >= TP_R:
                        tp_hits += 1
                        tp_contrib += pnl
                exits_by_year[(row.get("bar_time", "")[:4])] += 1
            elif ev == "BLOCKED":
                blocks[(row.get("reason", "").split("|", 1)[0] or "UNKNOWN")] += 1

    risk = cur_risk if cur_risk > 0.0 else 5.0
    avg_win = (sum_win / wins) if wins else 0.0
    avg_loss = (sum_loss / losses) if losses else 0.0
    #--- Break-even winrate p* = L / (W + L) with W, L the mean win/loss sizes.
    p_be = (-avg_loss) / (avg_win + (-avg_loss)) if (avg_win - avg_loss) > 0 else 0.0
    winrate = (100.0 * wins / n_trades) if n_trades else 0.0

    quantiles = {}
    if r_all:
        r_all.sort()
        n = len(r_all)

        def q(p: float) -> float:
            return r_all[min(n - 1, int(p * n))]

        quantiles = {"p10": q(0.10), "p50": q(0.50), "p90": q(0.90),
                     "max": r_all[-1]}

    #--- r_all already holds pnl/risk per trade in order, so the USD and R
    #--- bootstraps use the same trade sequence.
    ci_usd = _bootstrap_mean_ci(pnls, ci_samples, ci_seed)
    ci_r = _bootstrap_mean_ci(r_all, ci_samples, ci_seed)

    expectancy_usd = (net / n_trades) if n_trades else 0.0
    expectancy_r = (net / (n_trades * risk)) if n_trades else 0.0

    return {
        "path": str(path),
        "events": dict(events),
        "trades": n_trades,
        "wins": wins,
        "losses": losses,
        "flats": flats,
        "winrate": winrate,
        "net": net,
        "expectancy_usd": expectancy_usd,
        "expectancy_usd_ci95": ci_usd,
        "expectancy_r": expectancy_r,
        "expectancy_r_ci95": ci_r,
        "avg_win": avg_win,
        "avg_loss": avg_loss,
        "profit_factor": (gross_win / gross_loss) if gross_loss else 0.0,
        "break_even_winrate": 100.0 * p_be,
        "winrate_gap_pp": winrate - 100.0 * p_be,
        "spread_price": spread_price,
        "spread_cost_total": spread_cost_total,
        "gross": net + spread_cost_total,
        "net_spread_x2": net - spread_cost_total,
        "max_drawdown_pct": max_dd,
        "peak_equity": peak,
        "trough_equity": trough_at,
        "risk_per_trade": risk,
        "tp_hits": tp_hits,
        "tp_contrib": tp_contrib,
        "net_without_tp": net - tp_contrib,
        "r_quantiles": quantiles,
        "entries_by_year": dict(sorted(entries_by_year.items())),
        "exits_by_year": dict(sorted(exits_by_year.items())),
        "blocks": dict(blocks.most_common(10)),
    }


def render_text(r: dict, label: str = "NOT_STRATEGY_RESULT") -> str:
    cu, cr = r["expectancy_usd_ci95"], r["expectancy_r_ci95"]
    lines = [
        f"LABEL: {label}",
        f"IR ANALYSE {Path(r['path']).name}",
        f"  events {r['events']}",
        f"  trades={r['trades']} wins={r['wins']} losses={r['losses']} "
        f"flats={r['flats']} winrate={r['winrate']:.2f}%",
        f"  net={r['net']:.2f} expectancy_usd={r['expectancy_usd']:.3f} "
        f"[{cu[0]:.3f}..{cu[1]:.3f}] expectancy_r={r['expectancy_r']:.4f} "
        f"[{cr[0]:.4f}..{cr[1]:.4f}]",
        f"  avg_win={r['avg_win']:.2f} avg_loss={r['avg_loss']:.2f} "
        f"pf={r['profit_factor']:.3f} p*={r['break_even_winrate']:.2f}% "
        f"gap={r['winrate_gap_pp']:+.2f}pp",
        f"  max_drawdown_pct={r['max_drawdown_pct']:.2f} "
        f"peak_equity={r['peak_equity']:.2f} trough_equity={r['trough_equity']:.2f}",
        f"  spread_price={r['spread_price']} gross={r['gross']:.2f} "
        f"net_spread_x2={r['net_spread_x2']:.2f}",
        f"  tp_hits(R>={TP_R})={r['tp_hits']} tp_contrib={r['tp_contrib']:.2f} "
        f"net_without_tp={r['net_without_tp']:.2f}",
    ]
    if r["r_quantiles"]:
        q = r["r_quantiles"]
        lines.append(f"  R quantiles p10={q['p10']:.2f} p50={q['p50']:.2f} "
                     f"p90={q['p90']:.2f} max={q['max']:.2f}")
    lines.append(f"  entries_by_year {r['entries_by_year']}")
    lines.append(f"  blocks {r['blocks']}")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", help="journal CSV or a directory of journals")
    parser.add_argument("--spread-price", type=float, default=0.19,
                        help="implied spread in price units (XAUUSDm default 0.19)")
    parser.add_argument("--ci-samples", type=int, default=1000,
                        help="bootstrap resamples for the expectancy CI")
    parser.add_argument("--ci-seed", type=int, default=12345,
                        help="bootstrap RNG seed (reproducible)")
    parser.add_argument("--json", default="", help="also write JSON here")
    args = parser.parse_args()

    target = Path(args.target)
    if not target.exists():
        print(f"ERROR: not found: {target}", file=sys.stderr)
        return 2
    paths = journal_files(target)
    if not paths:
        print(f"ERROR: no journal matched under {target}", file=sys.stderr)
        return 2

    results = []
    for path in paths:
        try:
            result = analyse(path, args.spread_price, args.ci_samples, args.ci_seed)
        except (OSError, ValueError) as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
        results.append(result)
        print(render_text(result))
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
