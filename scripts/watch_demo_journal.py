"""Watch the live demo journal of ``PATrendRiderXAUv1DemoEA`` and report real orders.

The EA appends the 18-column ``SimLogger`` CSV to ``<Data Folder>\\MQL5\\Files\\
pa_trendrider_demo.csv``. This tool reads that file, remembers how far it has already
seen, and prints every event that appeared since the last checkpoint. Events that mean
a real order left the terminal (``ENTRY``, ``EXIT``, ``CLOSE_REQUEST``, ``TRAIL``,
``ADOPT``, ``SYNC``) and events that mean something went wrong (``KILL``, ``ERROR``,
``STATE_ERROR``, ``RESET``) are reported as alerts.

It is read-only: it never opens MT5, never touches ``MQL5\\Experts``, never sends a
trade and never reads credentials. ``MQL5\\Logs`` and ``MQL5\\Files`` are the only
inputs, plus the local checkpoint file under ``reports/``.

Exit codes:
    0  checkpoint advanced, no alert-worthy event
    1  at least one alert-worthy event was reported
    2  no journal was found, or it does not match the documented schema
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

JOURNAL_NAME = "pa_trendrider_demo.csv"
KILL_SWITCH_NAME = "PA_TREND_RIDER_DEMO_STOP.txt"
DEFAULT_STATE_PATH = REPO_ROOT / "reports" / "demo-watch" / "journal_checkpoint.json"

EXPECTED_HEADER = (
    "logged_at",
    "bar_time",
    "ea",
    "version",
    "config_hash",
    "symbol",
    "timeframe",
    "event",
    "side",
    "price",
    "volume",
    "entry",
    "sl",
    "tp",
    "exposure",
    "equity",
    "drawdown_pct",
    "reason",
)

ALERT_KINDS = {
    "ENTRY": "ORDER",
    "EXIT": "ORDER",
    "TRAIL": "ORDER",
    "CLOSE_REQUEST": "ORDER",
    "ADOPT": "ORDER",
    "SYNC": "ORDER",
    "KILL": "FAULT",
    "ERROR": "FAULT",
    "STATE_ERROR": "FAULT",
    "RESET": "FAULT",
}
ALERT_EVENTS = tuple(ALERT_KINDS)


class JournalError(RuntimeError):
    """Raised when the journal is missing or structurally wrong."""


def emit(line: str) -> None:
    """Print one line and flush, so ``| tee``/redirects see alerts immediately."""
    print(line, flush=True)


def terminal_data_roots() -> list[Path]:
    """Candidate MT5 data roots: every terminal profile under ``%APPDATA%``."""
    appdata = os.environ.get("APPDATA")
    if not appdata:
        return []
    return [Path(appdata) / "MetaQuotes" / "Terminal"]


def find_journal(explicit: str | None, name: str = JOURNAL_NAME) -> Path:
    """Resolve the live journal CSV or raise ``JournalError``."""
    if explicit:
        candidate = Path(explicit)
        if not candidate.is_absolute():
            candidate = REPO_ROOT / candidate
        if not candidate.is_file():
            raise JournalError(f"journal not found: {candidate}")
        return candidate

    hits: list[Path] = []
    seen: set[Path] = set()
    for root in terminal_data_roots():
        if not root.is_dir():
            continue
        for path in sorted(root.glob(f"*/MQL5/Files/{name}")):
            resolved = path.resolve()
            if resolved not in seen:
                seen.add(resolved)
                hits.append(resolved)
    if not hits:
        raise JournalError(
            f"no {name} under any MQL5/Files data folder; pass --csv with an absolute path"
        )
    if len(hits) > 1:
        detail = " | ".join(str(path) for path in hits)
        raise JournalError(f"ambiguous journal, pass --csv: {detail}")
    return hits[0]


def read_records(path: Path, offset: int) -> tuple[list[dict[str, str]], int, bool]:
    """Read whole lines appended after ``offset``.

    Returns the parsed records, the new byte offset and whether the file shrank
    (which means it was recreated and the checkpoint has to restart).
    """
    size = path.stat().st_size
    restarted = size < offset
    start = 0 if restarted else offset
    with path.open("rb") as handle:
        handle.seek(start)
        payload = handle.read()
    text = payload.decode("utf-8", errors="replace").replace("\r\n", "\n")
    lines = text.split("\n")
    remainder = lines.pop()
    records: list[dict[str, str]] = []
    for line in lines:
        if not line.strip():
            continue
        fields = next(csv.reader([line]))
        if fields[0] == EXPECTED_HEADER[0] and tuple(fields) == EXPECTED_HEADER:
            continue
        if len(fields) != len(EXPECTED_HEADER):
            raise JournalError(
                f"{path}: expected {len(EXPECTED_HEADER)} columns, got {len(fields)}"
            )
        records.append(dict(zip(EXPECTED_HEADER, fields)))
    return records, size - len(remainder.encode("utf-8", errors="replace")), restarted


def load_checkpoint(path: Path) -> int:
    if not path.is_file():
        return -1
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, OSError):
        return -1
    value = raw.get("offset")
    return int(value) if isinstance(value, int) else -1


def save_checkpoint(path: Path, journal: Path, offset: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "journal": str(journal),
        "offset": offset,
        "size": journal.stat().st_size,
        "saved_at": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def journal_age_seconds(path: Path, now: float | None = None) -> float:
    return max(0.0, (now if now is not None else time.time()) - path.stat().st_mtime)


def kill_switch_present(journal: Path, name: str = KILL_SWITCH_NAME) -> bool:
    return (journal.parent / name).is_file()


def classify(record: dict[str, str]) -> str | None:
    """Return ``ORDER``, ``FAULT`` or ``None`` for one journal record."""
    return ALERT_KINDS.get(record["event"])


def block_reasons(records: list[dict[str, str]]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for record in records:
        if record["event"] != "RISK":
            continue
        reason = record["reason"]
        if not reason.startswith("ENTRY_BLOCKED"):
            continue
        token = reason.split("|")[1] if "|" in reason else reason
        counts[token] = counts.get(token, 0) + 1
    return counts


def format_record(record: dict[str, str]) -> str:
    detail = record["reason"]
    if record["event"] in ("ENTRY", "EXIT", "TRAIL", "CLOSE_REQUEST"):
        detail = (
            f"{detail}|side={record['side']}|price={record['price']}"
            f"|volume={record['volume']}|sl={record['sl']}|tp={record['tp']}"
            f"|equity={record['equity']}"
        )
    return f"WATCH|{record['event']}|{record['logged_at']}|{record['bar_time']}|{detail}"


def report(journal: Path, records: list[dict[str, str]], *, quiet: bool) -> int:
    alerts = [record for record in records if classify(record)]
    if not quiet:
        for record in records:
            emit(format_record(record))
        counts: dict[str, int] = {}
        for record in records:
            counts[record["event"]] = counts.get(record["event"], 0) + 1
        summary = "|".join(f"{key}={counts[key]}" for key in sorted(counts))
        emit(f"WATCH|SUMMARY|events={len(records)}|{summary or 'none'}")
        blocked = block_reasons(records)
        if blocked:
            emit(
                "WATCH|BLOCKED|"
                + "|".join(f"{key}={blocked[key]}" for key in sorted(blocked))
            )
    for record in alerts:
        if quiet:
            emit(format_record(record))
    if kill_switch_present(journal):
        emit(f"WATCH|FAULT|kill_switch_file_present|{KILL_SWITCH_NAME}")
        alerts.append({"event": "KILL", "reason": KILL_SWITCH_NAME})
    age = journal_age_seconds(journal)
    if age > 2 * 3600:
        emit(f"WATCH|NOTE|journal_stale|age_seconds={int(age)}")
    return 1 if alerts else 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Report new events in the live demo journal of the TrendRider DemoEA."
    )
    parser.add_argument("--csv", help="absolute path to pa_trendrider_demo.csv")
    parser.add_argument(
        "--state",
        help=f"checkpoint file (default {DEFAULT_STATE_PATH.relative_to(REPO_ROOT)})",
    )
    parser.add_argument(
        "--from-start",
        action="store_true",
        help="on the first run read the whole file instead of starting at its end",
    )
    parser.add_argument("--reset", action="store_true", help="discard the checkpoint first")
    parser.add_argument(
        "--watch",
        action="store_true",
        help="keep polling instead of exiting after one pass",
    )
    parser.add_argument("--interval", type=float, default=30.0, help="poll seconds")
    parser.add_argument(
        "--timeout",
        type=float,
        default=0.0,
        help="stop watching after this many seconds (0 = never)",
    )
    parser.add_argument(
        "--stop-on-alert",
        action="store_true",
        help="stop watching as soon as an order or fault event appears",
    )
    parser.add_argument("--quiet", action="store_true", help="only print alert lines")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        journal = find_journal(args.csv)
    except JournalError as error:
        emit(f"WATCH|ERROR|{error}")
        return 2

    state_path = Path(args.state) if args.state else DEFAULT_STATE_PATH
    if not state_path.is_absolute():
        state_path = REPO_ROOT / state_path
    if args.reset and state_path.is_file():
        state_path.unlink()

    checkpoint = load_checkpoint(state_path)
    if checkpoint < 0:
        checkpoint = 0 if args.from_start else journal.stat().st_size
        emit(
            f"WATCH|INIT|journal={journal}|checkpoint={checkpoint}"
            f"|{'full_scan' if checkpoint == 0 else 'tailing_from_end'}"
        )

    started = time.time()
    exit_code = 0
    while True:
        try:
            records, offset, restarted = read_records(journal, checkpoint)
        except JournalError as error:
            emit(f"WATCH|ERROR|{error}")
            return 2
        if restarted:
            emit("WATCH|NOTE|journal_recreated|restarting_checkpoint")
        if records:
            code = report(journal, records, quiet=args.quiet)
            exit_code = max(exit_code, code)
        checkpoint = offset
        save_checkpoint(state_path, journal, checkpoint)
        if not args.watch:
            return exit_code
        if args.stop_on_alert and exit_code:
            return exit_code
        wait = max(1.0, args.interval)
        if args.timeout:
            elapsed = time.time() - started
            if elapsed >= args.timeout:
                emit(f"WATCH|TIMEOUT|seconds={int(elapsed)}")
                return exit_code
            wait = min(wait, args.timeout - elapsed)
        time.sleep(wait)


if __name__ == "__main__":
    raise SystemExit(main())
