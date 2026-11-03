"""Tests for scripts/check_docs_links.py."""

from __future__ import annotations

import importlib.util
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "scripts" / "check_docs_links.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("check_docs_links", MODULE_PATH)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def test_valid_links_are_counted_and_code_fences_are_ignored(tmp_path: Path) -> None:
    module = _load_module()
    _write(tmp_path / "docs" / "target.md", "# target\n")
    _write(tmp_path / "docs" / "b c.md", "# spaced\n")
    _write(
        tmp_path / "docs" / "index.md",
        "# index\n"
        "[ok](target.md)\n"
        "[spaced](b%20c.md)\n"
        "```\n"
        "[ignored](missing.md)\n"
        "```\n",
    )
    issues, external, checked = module.check_links(tmp_path)
    assert issues == []
    assert checked == 2
    assert external == 0


def test_broken_link_reports_file_and_line(tmp_path: Path) -> None:
    module = _load_module()
    _write(tmp_path / "docs" / "index.md", "# index\n\n[x](missing.md)\n")
    issues, _, _ = module.check_links(tmp_path)
    assert issues == ["docs/index.md:3: broken link: missing.md"]


def test_case_mismatch_is_broken(tmp_path: Path) -> None:
    module = _load_module()
    _write(tmp_path / "docs" / "Sub" / "Target.md", "# target\n")
    _write(tmp_path / "docs" / "index.md", "[x](sub/Target.md)\n")
    issues, _, _ = module.check_links(tmp_path)
    assert len(issues) == 1
    assert "broken link" in issues[0]


def test_external_and_anchor_links_are_skipped(tmp_path: Path) -> None:
    module = _load_module()
    _write(
        tmp_path / "docs" / "index.md",
        "[a](https://example.com)\n"
        "[b](http://example.com)\n"
        "[c](mailto:x@y.z)\n"
        "[d](#section)\n",
    )
    issues, external, checked = module.check_links(tmp_path)
    assert issues == []
    assert external == 3
    assert checked == 0


def test_file_uri_is_broken(tmp_path: Path) -> None:
    module = _load_module()
    _write(tmp_path / "docs" / "index.md", "[x](file:///docs/target.md)\n")
    issues, _, _ = module.check_links(tmp_path)
    assert len(issues) == 1
    assert "file URI" in issues[0]


def test_progress_and_archive_are_exempt(tmp_path: Path) -> None:
    module = _load_module()
    _write(tmp_path / "docs" / "PROGRESS.md", "[x](missing.md)\n")
    _write(tmp_path / "docs" / "99-archive" / "old.md", "[x](missing.md)\n")
    _write(tmp_path / "archive" / "old.md", "[x](missing.md)\n")
    _write(tmp_path / "docs" / "index.md", "[ok](index.md)\n")
    issues, _, checked = module.check_links(tmp_path)
    assert issues == []
    assert checked == 1
