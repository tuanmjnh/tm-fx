"""Deterministic hashes and repository state used by the experiment store.

Fingerprints are only meaningful when they are reproducible: JSON is
canonicalized before hashing, files are hashed from raw bytes, and no
environment-dependent values (absolute paths, timestamps) are included.
"""

from __future__ import annotations

import hashlib
import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping

_CHUNK_SIZE = 1024 * 1024


class FingerprintError(ValueError):
    """Raised when a value cannot be canonicalized or hashed."""


@dataclass(frozen=True)
class GitState:
    commit: str | None
    dirty: bool | None

    def to_dict(self) -> dict[str, Any]:
        return {"commit": self.commit, "dirty": self.dirty}


def canonical_json(value: Any) -> str:
    """Serialize ``value`` so equal structures always produce equal text."""

    try:
        return json.dumps(
            value,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
            allow_nan=False,
        )
    except (TypeError, ValueError) as exc:
        raise FingerprintError(f"value is not canonically serializable: {exc}") from exc


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_file(path: str | Path) -> str:
    """Hash raw file bytes; the file must exist and be readable."""

    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(_CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest()


def hash_config(config: Mapping[str, Any]) -> str:
    """Hash the semantic parts of an experiment configuration.

    Callers decide which fields are semantic. Paths, output locations and
    timestamps should be excluded; ``data_fingerprint`` covers file content.
    """

    if not isinstance(config, Mapping):
        raise FingerprintError("config must be a mapping")
    return sha256_text(canonical_json(config))


def _run_git(repo_root: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *arguments],
        cwd=repo_root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=15,
        check=False,
    )


def read_git_state(repo_root: str | Path) -> GitState:
    """Return the current commit and dirty flag, or ``None`` when unavailable.

    Missing git, a non-repository directory or a git error is reported as
    ``(None, None)`` rather than raising: the store can still record a run,
    but comparability will warn about unknown code state.
    """

    root = Path(repo_root)
    if not root.is_dir():
        return GitState(commit=None, dirty=None)
    try:
        commit_result = _run_git(root, "rev-parse", "HEAD")
        if commit_result.returncode != 0:
            return GitState(commit=None, dirty=None)
        status_result = _run_git(root, "status", "--porcelain")
    except (OSError, subprocess.SubprocessError):
        return GitState(commit=None, dirty=None)

    commit = commit_result.stdout.strip() or None
    if status_result.returncode != 0:
        return GitState(commit=commit, dirty=None)
    dirty = bool(status_result.stdout.strip())
    return GitState(commit=commit, dirty=dirty)
