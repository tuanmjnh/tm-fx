"""SQLite-backed experiment metadata store.

The store records :class:`RunMetadata` before a backtest starts and a terminal
status afterwards. Rows are append-only with respect to experiment IDs: an ID
can be claimed once, and only a ``running`` row can transition to a terminal
status. Artifact paths and SHA-256 hashes are recorded so a run can be audited
without re-running it.
"""

from __future__ import annotations

import json
import re
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

SCHEMA_VERSION = 1

STATUS_RUNNING = "running"
STATUS_COMPLETED = "completed"
STATUS_FAILED = "failed"
STATUS_INVALID_DATA = "invalid_data"
STATUS_CANCELLED = "cancelled"
STATUS_INTERRUPTED = "interrupted"

VALID_STATUSES: tuple[str, ...] = (
    STATUS_RUNNING,
    STATUS_COMPLETED,
    STATUS_FAILED,
    STATUS_INVALID_DATA,
    STATUS_CANCELLED,
    STATUS_INTERRUPTED,
)
TERMINAL_STATUSES: frozenset[str] = frozenset(VALID_STATUSES[1:])

EXPERIMENT_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")

_SCHEMA = """
CREATE TABLE IF NOT EXISTS experiments (
    experiment_id TEXT PRIMARY KEY,
    status TEXT NOT NULL CHECK (status IN (
        'running', 'completed', 'failed', 'invalid_data', 'cancelled', 'interrupted'
    )),
    created_at_utc TEXT NOT NULL,
    updated_at_utc TEXT NOT NULL,
    started_at_utc TEXT NOT NULL,
    finished_at_utc TEXT,
    code_version TEXT NOT NULL,
    git_commit TEXT,
    git_dirty INTEGER,
    config_path TEXT NOT NULL,
    config_json TEXT NOT NULL,
    config_hash TEXT NOT NULL,
    data_path TEXT,
    data_fingerprint TEXT,
    data_kind TEXT,
    symbol TEXT,
    timeframe TEXT,
    seed INTEGER,
    report_dir TEXT,
    metrics_json TEXT,
    benchmark_json TEXT,
    signal_counts_json TEXT,
    validation_json TEXT,
    error TEXT,
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_experiments_config_hash
    ON experiments (config_hash);
CREATE INDEX IF NOT EXISTS idx_experiments_data_fingerprint
    ON experiments (data_fingerprint);
CREATE INDEX IF NOT EXISTS idx_experiments_status
    ON experiments (status);

CREATE TABLE IF NOT EXISTS experiment_events (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    experiment_id TEXT NOT NULL REFERENCES experiments (experiment_id),
    event_at_utc TEXT NOT NULL,
    from_status TEXT,
    to_status TEXT NOT NULL,
    detail TEXT
);

CREATE TABLE IF NOT EXISTS experiment_artifacts (
    experiment_id TEXT NOT NULL REFERENCES experiments (experiment_id),
    name TEXT NOT NULL,
    path TEXT NOT NULL,
    sha256 TEXT,
    size_bytes INTEGER,
    created_at_utc TEXT NOT NULL,
    PRIMARY KEY (experiment_id, name)
);
"""


class StoreError(Exception):
    """Raised when the experiment store cannot complete an operation."""


class DuplicateExperimentError(StoreError):
    """Raised when an experiment ID is already present; nothing is modified."""


class RunNotFoundError(StoreError):
    """Raised when an experiment ID does not exist."""


class InvalidTransitionError(StoreError):
    """Raised when a terminal run is modified or a run is not running."""


@dataclass(frozen=True)
class Artifact:
    name: str
    path: str
    sha256: str | None = None
    size_bytes: int | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "path": self.path,
            "sha256": self.sha256,
            "size_bytes": self.size_bytes,
        }


@dataclass(frozen=True)
class RunMetadata:
    experiment_id: str
    config_path: str
    config: Mapping[str, Any]
    config_hash: str
    code_version: str
    data_path: str | None = None
    data_fingerprint: str | None = None
    data_kind: str | None = None
    symbol: str | None = None
    timeframe: str | None = None
    seed: int | None = None
    report_dir: str | None = None
    git_commit: str | None = None
    git_dirty: bool | None = None
    notes: str | None = None
    started_at_utc: str | None = None


@dataclass(frozen=True)
class RunRecord:
    experiment_id: str
    status: str
    created_at_utc: str
    updated_at_utc: str
    started_at_utc: str
    finished_at_utc: str | None
    code_version: str
    git_commit: str | None
    git_dirty: bool | None
    config_path: str
    config: dict[str, Any]
    config_hash: str
    data_path: str | None
    data_fingerprint: str | None
    data_kind: str | None
    symbol: str | None
    timeframe: str | None
    seed: int | None
    report_dir: str | None
    metrics: dict[str, Any] | None
    benchmark: dict[str, Any] | None
    signal_counts: dict[str, Any] | None
    validation: dict[str, Any] | None
    error: str | None
    notes: str | None
    artifacts: tuple[Artifact, ...] = ()

    def to_dict(self) -> dict[str, Any]:
        return {
            "experiment_id": self.experiment_id,
            "status": self.status,
            "created_at_utc": self.created_at_utc,
            "updated_at_utc": self.updated_at_utc,
            "started_at_utc": self.started_at_utc,
            "finished_at_utc": self.finished_at_utc,
            "code_version": self.code_version,
            "git_commit": self.git_commit,
            "git_dirty": self.git_dirty,
            "config_path": self.config_path,
            "config": self.config,
            "config_hash": self.config_hash,
            "data_path": self.data_path,
            "data_fingerprint": self.data_fingerprint,
            "data_kind": self.data_kind,
            "symbol": self.symbol,
            "timeframe": self.timeframe,
            "seed": self.seed,
            "report_dir": self.report_dir,
            "metrics": self.metrics,
            "benchmark": self.benchmark,
            "signal_counts": self.signal_counts,
            "validation": self.validation,
            "error": self.error,
            "notes": self.notes,
            "artifacts": [artifact.to_dict() for artifact in self.artifacts],
        }


def validate_experiment_id(experiment_id: str) -> str:
    """Return a normalized ID or raise ``ValueError``.

    IDs become directory names, so only a conservative character set is
    accepted and path separators or traversal segments cannot be expressed.
    """

    if not isinstance(experiment_id, str):
        raise ValueError("experiment_id must be a string")
    cleaned = experiment_id.strip()
    if not EXPERIMENT_ID_PATTERN.match(cleaned):
        raise ValueError(
            "experiment_id must match [A-Za-z0-9][A-Za-z0-9._-]{0,127}"
        )
    return cleaned


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _encode_json(value: Any, field_name: str) -> str:
    try:
        return json.dumps(value, sort_keys=True, allow_nan=False)
    except (TypeError, ValueError) as exc:
        raise StoreError(f"{field_name} is not JSON serializable: {exc}") from exc


def _decode_json(value: str | None) -> Any:
    if value is None:
        return None
    try:
        return json.loads(value)
    except json.JSONDecodeError as exc:
        raise StoreError(f"stored JSON is corrupted: {exc}") from exc


class ExperimentStore:
    """Thin SQLite wrapper; one instance owns one connection."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._connection = sqlite3.connect(str(self.path), timeout=10.0)
        self._connection.row_factory = sqlite3.Row
        self._connection.execute("PRAGMA foreign_keys = ON")
        self._migrate()

    def _migrate(self) -> None:
        version = int(self._connection.execute("PRAGMA user_version").fetchone()[0])
        if version == SCHEMA_VERSION:
            return
        if version > SCHEMA_VERSION:
            self._connection.close()
            raise StoreError(
                f"database schema version {version} is newer than supported "
                f"version {SCHEMA_VERSION}"
            )
        with self._connection:
            self._connection.executescript(_SCHEMA)
            self._connection.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")

    def close(self) -> None:
        self._connection.close()

    def __enter__(self) -> "ExperimentStore":
        return self

    def __exit__(self, exc_type: Any, exc: Any, traceback: Any) -> None:
        self.close()

    def _artifact_rows(self, experiment_id: str) -> tuple[Artifact, ...]:
        rows = self._connection.execute(
            "SELECT name, path, sha256, size_bytes FROM experiment_artifacts "
            "WHERE experiment_id = ? ORDER BY name",
            (experiment_id,),
        ).fetchall()
        return tuple(
            Artifact(
                name=row["name"],
                path=row["path"],
                sha256=row["sha256"],
                size_bytes=row["size_bytes"],
            )
            for row in rows
        )

    def start_run(self, metadata: RunMetadata) -> RunRecord:
        experiment_id = validate_experiment_id(metadata.experiment_id)
        if not metadata.config_hash.strip():
            raise StoreError("config_hash must not be empty")
        if not metadata.code_version.strip():
            raise StoreError("code_version must not be empty")

        started_at = metadata.started_at_utc or utc_now()
        config_json = _encode_json(metadata.config, "config")
        dirty_value = None if metadata.git_dirty is None else int(metadata.git_dirty)

        with self._connection:
            existing = self._connection.execute(
                "SELECT 1 FROM experiments WHERE experiment_id = ?",
                (experiment_id,),
            ).fetchone()
            if existing is not None:
                raise DuplicateExperimentError(
                    f"experiment_id already exists: {experiment_id}"
                )
            self._connection.execute(
                """
                INSERT INTO experiments (
                    experiment_id, status, created_at_utc, updated_at_utc,
                    started_at_utc, code_version, git_commit, git_dirty,
                    config_path, config_json, config_hash, data_path,
                    data_fingerprint, data_kind, symbol, timeframe, seed,
                    report_dir, notes
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    experiment_id,
                    STATUS_RUNNING,
                    started_at,
                    started_at,
                    started_at,
                    metadata.code_version,
                    metadata.git_commit,
                    dirty_value,
                    metadata.config_path,
                    config_json,
                    metadata.config_hash,
                    metadata.data_path,
                    metadata.data_fingerprint,
                    metadata.data_kind,
                    metadata.symbol,
                    metadata.timeframe,
                    metadata.seed,
                    metadata.report_dir,
                    metadata.notes,
                ),
            )
            self._connection.execute(
                """
                INSERT INTO experiment_events (
                    experiment_id, event_at_utc, from_status, to_status, detail
                ) VALUES (?, ?, NULL, ?, ?)
                """,
                (experiment_id, started_at, STATUS_RUNNING, "started"),
            )

        record = self.get_run(experiment_id)
        if record is None:
            raise StoreError(f"run disappeared after start: {experiment_id}")
        return record

    def finish_run(
        self,
        experiment_id: str,
        status: str,
        *,
        metrics: Mapping[str, Any] | None = None,
        benchmark: Mapping[str, Any] | None = None,
        signal_counts: Mapping[str, Any] | None = None,
        validation: Mapping[str, Any] | None = None,
        error: str | None = None,
        artifacts: Sequence[Artifact] = (),
        finished_at_utc: str | None = None,
    ) -> RunRecord:
        if status not in TERMINAL_STATUSES:
            raise StoreError(f"status must be terminal, got {status!r}")
        if status == STATUS_COMPLETED and metrics is None:
            raise StoreError("completed runs require metrics")
        if status in (STATUS_FAILED, STATUS_INVALID_DATA) and not (
            error and error.strip()
        ):
            raise StoreError(f"{status} runs require a non-empty error")

        artifact_list = list(artifacts)
        names = [artifact.name for artifact in artifact_list]
        if len(names) != len(set(names)):
            raise StoreError("artifact names must be unique within a run")
        for artifact in artifact_list:
            if not artifact.name.strip() or not artifact.path.strip():
                raise StoreError("artifact name and path must not be empty")

        metrics_json = None if metrics is None else _encode_json(metrics, "metrics")
        benchmark_json = (
            None if benchmark is None else _encode_json(benchmark, "benchmark")
        )
        signal_counts_json = (
            None
            if signal_counts is None
            else _encode_json(signal_counts, "signal_counts")
        )
        validation_json = (
            None if validation is None else _encode_json(validation, "validation")
        )
        finished_at = finished_at_utc or utc_now()

        with self._connection:
            row = self._connection.execute(
                "SELECT status FROM experiments WHERE experiment_id = ?",
                (experiment_id,),
            ).fetchone()
            if row is None:
                raise RunNotFoundError(f"experiment_id not found: {experiment_id}")
            current = str(row["status"])
            if current != STATUS_RUNNING:
                raise InvalidTransitionError(
                    f"experiment {experiment_id} is {current}, expected running"
                )

            self._connection.execute(
                """
                UPDATE experiments
                SET status = ?, updated_at_utc = ?, finished_at_utc = ?,
                    metrics_json = ?, benchmark_json = ?, signal_counts_json = ?,
                    validation_json = ?, error = ?
                WHERE experiment_id = ? AND status = ?
                """,
                (
                    status,
                    finished_at,
                    finished_at,
                    metrics_json,
                    benchmark_json,
                    signal_counts_json,
                    validation_json,
                    error,
                    experiment_id,
                    STATUS_RUNNING,
                ),
            )
            self._connection.execute(
                """
                INSERT INTO experiment_events (
                    experiment_id, event_at_utc, from_status, to_status, detail
                ) VALUES (?, ?, ?, ?, ?)
                """,
                (
                    experiment_id,
                    finished_at,
                    current,
                    status,
                    error or status,
                ),
            )
            for artifact in artifact_list:
                self._connection.execute(
                    """
                    INSERT INTO experiment_artifacts (
                        experiment_id, name, path, sha256, size_bytes, created_at_utc
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (
                        experiment_id,
                        artifact.name,
                        artifact.path,
                        artifact.sha256,
                        artifact.size_bytes,
                        finished_at,
                    ),
                )

        record = self.get_run(experiment_id)
        if record is None:
            raise StoreError(f"run disappeared after finish: {experiment_id}")
        return record

    def complete_run(
        self,
        experiment_id: str,
        metrics: Mapping[str, Any],
        *,
        benchmark: Mapping[str, Any] | None = None,
        signal_counts: Mapping[str, Any] | None = None,
        validation: Mapping[str, Any] | None = None,
        artifacts: Sequence[Artifact] = (),
    ) -> RunRecord:
        return self.finish_run(
            experiment_id,
            STATUS_COMPLETED,
            metrics=metrics,
            benchmark=benchmark,
            signal_counts=signal_counts,
            validation=validation,
            artifacts=artifacts,
        )

    def fail_run(
        self,
        experiment_id: str,
        error: str,
        *,
        validation: Mapping[str, Any] | None = None,
        artifacts: Sequence[Artifact] = (),
    ) -> RunRecord:
        return self.finish_run(
            experiment_id,
            STATUS_FAILED,
            error=error,
            validation=validation,
            artifacts=artifacts,
        )

    def invalidate_run(
        self,
        experiment_id: str,
        error: str,
        *,
        validation: Mapping[str, Any] | None = None,
        artifacts: Sequence[Artifact] = (),
    ) -> RunRecord:
        return self.finish_run(
            experiment_id,
            STATUS_INVALID_DATA,
            error=error,
            validation=validation,
            artifacts=artifacts,
        )

    def cancel_run(
        self,
        experiment_id: str,
        reason: str | None = None,
        *,
        artifacts: Sequence[Artifact] = (),
    ) -> RunRecord:
        return self.finish_run(
            experiment_id,
            STATUS_CANCELLED,
            error=reason,
            artifacts=artifacts,
        )

    def mark_interrupted(
        self,
        experiment_id: str,
        reason: str = "process ended before a terminal status was recorded",
        *,
        artifacts: Sequence[Artifact] = (),
    ) -> RunRecord:
        return self.finish_run(
            experiment_id,
            STATUS_INTERRUPTED,
            error=reason,
            artifacts=artifacts,
        )

    def get_run(self, experiment_id: str) -> RunRecord | None:
        row = self._connection.execute(
            "SELECT * FROM experiments WHERE experiment_id = ?",
            (experiment_id,),
        ).fetchone()
        if row is None:
            return None
        return self._row_to_record(row, self._artifact_rows(experiment_id))

    def list_runs(
        self,
        *,
        status: str | None = None,
        limit: int = 50,
        include_artifacts: bool = False,
    ) -> list[RunRecord]:
        if status is not None and status not in VALID_STATUSES:
            raise StoreError(f"unknown status filter: {status!r}")
        if limit <= 0:
            raise StoreError("limit must be positive")

        if status is None:
            rows = self._connection.execute(
                "SELECT * FROM experiments ORDER BY created_at_utc DESC, "
                "experiment_id DESC LIMIT ?",
                (limit,),
            ).fetchall()
        else:
            rows = self._connection.execute(
                "SELECT * FROM experiments WHERE status = ? "
                "ORDER BY created_at_utc DESC, experiment_id DESC LIMIT ?",
                (status, limit),
            ).fetchall()
        return [
            self._row_to_record(
                row,
                self._artifact_rows(row["experiment_id"])
                if include_artifacts
                else (),
            )
            for row in rows
        ]

    def list_events(self, experiment_id: str) -> list[dict[str, Any]]:
        rows = self._connection.execute(
            "SELECT * FROM experiment_events WHERE experiment_id = ? "
            "ORDER BY event_id",
            (experiment_id,),
        ).fetchall()
        return [
            {
                "event_id": int(row["event_id"]),
                "experiment_id": row["experiment_id"],
                "event_at_utc": row["event_at_utc"],
                "from_status": row["from_status"],
                "to_status": row["to_status"],
                "detail": row["detail"],
            }
            for row in rows
        ]

    def _row_to_record(
        self,
        row: sqlite3.Row,
        artifacts: tuple[Artifact, ...],
    ) -> RunRecord:
        dirty = row["git_dirty"]
        return RunRecord(
            experiment_id=str(row["experiment_id"]),
            status=str(row["status"]),
            created_at_utc=str(row["created_at_utc"]),
            updated_at_utc=str(row["updated_at_utc"]),
            started_at_utc=str(row["started_at_utc"]),
            finished_at_utc=row["finished_at_utc"],
            code_version=str(row["code_version"]),
            git_commit=row["git_commit"],
            git_dirty=None if dirty is None else bool(dirty),
            config_path=str(row["config_path"]),
            config=_decode_json(row["config_json"]),
            config_hash=str(row["config_hash"]),
            data_path=row["data_path"],
            data_fingerprint=row["data_fingerprint"],
            data_kind=row["data_kind"],
            symbol=row["symbol"],
            timeframe=row["timeframe"],
            seed=row["seed"],
            report_dir=row["report_dir"],
            metrics=_decode_json(row["metrics_json"]),
            benchmark=_decode_json(row["benchmark_json"]),
            signal_counts=_decode_json(row["signal_counts_json"]),
            validation=_decode_json(row["validation_json"]),
            error=row["error"],
            notes=row["notes"],
            artifacts=artifacts,
        )
