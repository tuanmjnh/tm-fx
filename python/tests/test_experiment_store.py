from __future__ import annotations

from pathlib import Path

import pytest

from mt5_ea_ai_lab.experiment_store import (
    Artifact,
    DuplicateExperimentError,
    ExperimentStore,
    FingerprintError,
    InvalidTransitionError,
    RunMetadata,
    RunNotFoundError,
    StoreError,
    canonical_json,
    hash_config,
    read_git_state,
    sha256_file,
    validate_experiment_id,
)

CONFIG = {
    "strategy": {"fast_period": 2, "slow_period": 3},
    "execution": {"initial_equity": 10_000.0},
    "seed": 42,
}
CONFIG_HASH = "a" * 64
DATA_HASH = "b" * 64
COMMIT = "c" * 40


def make_metadata(experiment_id: str = "exp-1", **overrides: object) -> RunMetadata:
    values: dict[str, object] = {
        "experiment_id": experiment_id,
        "config_path": "configs/backtest.example.yaml",
        "config": CONFIG,
        "config_hash": CONFIG_HASH,
        "code_version": "0.1.0",
        "data_path": "datasets/samples/demo.csv",
        "data_fingerprint": DATA_HASH,
        "data_kind": "synthetic",
        "symbol": "EURUSD",
        "timeframe": "M5",
        "seed": 42,
        "report_dir": "reports/backtests/exp-1",
        "git_commit": COMMIT,
        "git_dirty": False,
        "notes": "unit test",
        "started_at_utc": "2026-01-01T00:00:00+00:00",
    }
    values.update(overrides)
    return RunMetadata(**values)  # type: ignore[arg-type]


@pytest.fixture()
def store(tmp_path: Path) -> ExperimentStore:
    with ExperimentStore(tmp_path / "experiments.sqlite") as instance:
        yield instance


def test_start_run_records_running_metadata(store: ExperimentStore) -> None:
    record = store.start_run(make_metadata())

    assert record.status == "running"
    assert record.experiment_id == "exp-1"
    assert record.config == CONFIG
    assert record.config_hash == CONFIG_HASH
    assert record.data_fingerprint == DATA_HASH
    assert record.git_commit == COMMIT
    assert record.git_dirty is False
    assert record.finished_at_utc is None
    assert record.metrics is None

    events = store.list_events("exp-1")
    assert [(event["from_status"], event["to_status"]) for event in events] == [
        (None, "running")
    ]


def test_duplicate_experiment_id_does_not_overwrite(store: ExperimentStore) -> None:
    store.start_run(make_metadata())
    store.complete_run("exp-1", {"final_equity": 10_100.0})

    with pytest.raises(DuplicateExperimentError):
        store.start_run(make_metadata(notes="second attempt"))

    record = store.get_run("exp-1")
    assert record is not None
    assert record.status == "completed"
    assert record.metrics == {"final_equity": 10_100.0}
    assert record.notes == "unit test"
    assert len(store.list_events("exp-1")) == 2


def test_terminal_run_cannot_transition_again(store: ExperimentStore) -> None:
    store.start_run(make_metadata())
    store.complete_run("exp-1", {"final_equity": 10_100.0})

    with pytest.raises(InvalidTransitionError):
        store.fail_run("exp-1", "late failure")

    record = store.get_run("exp-1")
    assert record is not None
    assert record.status == "completed"
    assert record.error is None
    assert len(store.list_events("exp-1")) == 2


def test_running_run_can_be_marked_interrupted(store: ExperimentStore) -> None:
    store.start_run(make_metadata())

    record = store.mark_interrupted("exp-1")

    assert record.status == "interrupted"
    assert record.finished_at_utc is not None
    assert record.error is not None
    with pytest.raises(InvalidTransitionError):
        store.complete_run("exp-1", {"final_equity": 1.0})


def test_running_run_can_be_cancelled(store: ExperimentStore) -> None:
    store.start_run(make_metadata())

    record = store.cancel_run("exp-1", "operator cancelled")

    assert record.status == "cancelled"
    assert record.error == "operator cancelled"
    assert record.finished_at_utc is not None


def test_duplicate_artifact_names_are_rejected(store: ExperimentStore) -> None:
    store.start_run(make_metadata())

    with pytest.raises(StoreError, match="unique"):
        store.complete_run(
            "exp-1",
            {"final_equity": 1.0},
            artifacts=[
                Artifact(name="summary", path="a.json"),
                Artifact(name="summary", path="b.json"),
            ],
        )
    assert store.get_run("exp-1").status == "running"  # type: ignore[union-attr]


def test_completed_requires_metrics(store: ExperimentStore) -> None:
    store.start_run(make_metadata())
    with pytest.raises(StoreError, match="require metrics"):
        store.finish_run("exp-1", "completed")
    assert store.get_run("exp-1").status == "running"  # type: ignore[union-attr]


def test_failed_requires_error(store: ExperimentStore) -> None:
    store.start_run(make_metadata())
    with pytest.raises(StoreError, match="non-empty error"):
        store.fail_run("exp-1", "")
    assert store.get_run("exp-1").status == "running"  # type: ignore[union-attr]


def test_nan_metrics_are_rejected_without_changing_status(
    store: ExperimentStore,
) -> None:
    store.start_run(make_metadata())

    with pytest.raises(StoreError, match="JSON serializable"):
        store.complete_run("exp-1", {"final_equity": float("nan")})

    record = store.get_run("exp-1")
    assert record is not None
    assert record.status == "running"
    assert record.metrics is None


def test_artifacts_and_json_fields_roundtrip(
    store: ExperimentStore, tmp_path: Path
) -> None:
    store.start_run(make_metadata())
    artifact_path = tmp_path / "trades.csv"
    artifact_path.write_text("trade_id,pnl\n1,10.0\n", encoding="utf-8")
    artifact = Artifact(
        name="trades",
        path=str(artifact_path),
        sha256=sha256_file(artifact_path),
        size_bytes=artifact_path.stat().st_size,
    )
    metrics = {"final_equity": 10_294.6, "win_rate": None, "trade_count": 1}
    benchmark = {"net_pnl": 194.6}
    signal_counts = {"BUY": 1, "HOLD": 7}
    validation = {"passed": True, "errors": 0, "warnings": 1}

    store.complete_run(
        "exp-1",
        metrics,
        benchmark=benchmark,
        signal_counts=signal_counts,
        validation=validation,
        artifacts=[artifact],
    )

    store.close()
    with ExperimentStore(store.path) as reopened:
        record = reopened.get_run("exp-1")

    assert record is not None
    assert record.status == "completed"
    assert record.metrics == metrics
    assert record.benchmark == benchmark
    assert record.signal_counts == signal_counts
    assert record.validation == validation
    assert record.artifacts == (artifact,)
    assert record.finished_at_utc is not None


def test_list_runs_filters_and_orders(store: ExperimentStore) -> None:
    store.start_run(make_metadata("exp-a", started_at_utc="2026-01-01T00:00:00+00:00"))
    store.complete_run("exp-a", {"final_equity": 1.0})
    store.start_run(make_metadata("exp-b", started_at_utc="2026-01-02T00:00:00+00:00"))

    assert [record.experiment_id for record in store.list_runs()] == [
        "exp-b",
        "exp-a",
    ]
    completed = store.list_runs(status="completed")
    assert [record.experiment_id for record in completed] == ["exp-a"]
    assert store.list_runs(status="completed", include_artifacts=True)[0].artifacts == ()
    with pytest.raises(StoreError, match="unknown status"):
        store.list_runs(status="done")
    with pytest.raises(StoreError, match="limit"):
        store.list_runs(limit=0)


def test_unknown_experiment_id_operations(store: ExperimentStore) -> None:
    assert store.get_run("missing") is None
    with pytest.raises(RunNotFoundError, match="not found"):
        store.fail_run("missing", "boom")


def test_invalid_experiment_id_is_rejected(tmp_path: Path) -> None:
    for candidate in ("", "../escape", "nested/name", ".hidden", "a b"):
        with pytest.raises(ValueError):
            validate_experiment_id(candidate)

    with ExperimentStore(tmp_path / "experiments.sqlite") as store:
        with pytest.raises(ValueError):
            store.start_run(make_metadata("../escape"))


def test_start_run_rejects_empty_hash(store: ExperimentStore) -> None:
    with pytest.raises(StoreError, match="config_hash"):
        store.start_run(make_metadata(config_hash=""))


def test_schema_version_and_events_persist(tmp_path: Path) -> None:
    path = tmp_path / "experiments.sqlite"
    with ExperimentStore(path) as store:
        store.start_run(make_metadata())
        store.fail_run("exp-1", "load_error: missing file")

    with ExperimentStore(path) as reopened:
        record = reopened.get_run("exp-1")
        events = reopened.list_events("exp-1")

    assert record is not None
    assert record.status == "failed"
    assert record.error == "load_error: missing file"
    assert [(event["from_status"], event["to_status"]) for event in events] == [
        (None, "running"),
        ("running", "failed"),
    ]


def test_canonical_json_and_config_hash_are_order_independent() -> None:
    left = {"b": 2, "a": {"y": 1, "x": 0}}
    right = {"a": {"x": 0, "y": 1}, "b": 2}
    assert canonical_json(left) == canonical_json(right)
    assert hash_config(left) == hash_config(right)


def test_canonical_json_rejects_nan() -> None:
    with pytest.raises(FingerprintError):
        canonical_json({"value": float("nan")})
    with pytest.raises(FingerprintError):
        hash_config({"value": float("inf")})


def test_read_git_state_missing_directory(tmp_path: Path) -> None:
    state = read_git_state(tmp_path / "missing")
    assert state.commit is None
    assert state.dirty is None
    assert state.to_dict() == {"commit": None, "dirty": None}
