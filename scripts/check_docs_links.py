"""Check every relative markdown link in the repository.

Only local targets are validated: a link must resolve to an existing file or
directory, with the exact case used on disk. External schemes (http, https,
mailto, tel) and same-page anchors are skipped and counted separately.
``file:`` URIs are reported as broken so documentation uses relative paths.

Exempt by design: ``docs/PROGRESS.md`` (append-only history) and the immutable
snapshots under ``docs/99-archive/`` and ``archive/``. Transient tooling
directories (pytest temporary fixture roots, pip build trees, task-runner temp
folders, pytest caches) are pruned by name: they are never documentation and a
pytest session that runs this checker must not fail on its own fixtures.

Exit codes:
    0  every local link resolves
    1  at least one link is broken
    2  the project root is missing
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path
from urllib.parse import unquote

REPO_ROOT = Path(__file__).resolve().parents[1]

EXEMPT_DIRS = (
    ".git",
    ".venv",
    "node_modules",
    "reports",
    "github-demo",
    "archive",
    "docs/99-archive",
)
EXEMPT_FILES = ("docs/PROGRESS.md",)

#--- Transient tooling directories: pruned by directory-name prefix so a test
#--- run that executes this checker never fails on its own temporary fixtures.
PRUNED_DIR_PREFIXES = ("pytest-of-", "pip-", "tmp", "tmpsnub_")
PRUNED_DIR_NAMES = (".pytest_cache",)

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
FENCE_RE = re.compile(r"^```.*?^```", re.MULTILINE | re.DOTALL)
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")
EXTERNAL_PREFIXES = ("http://", "https://", "mailto:", "tel:")


def _is_exempt(rel: str) -> bool:
    if rel in EXEMPT_FILES:
        return True
    return any(rel == d or rel.startswith(d + "/") for d in EXEMPT_DIRS)


def _is_pruned_dir(name: str) -> bool:
    return name in PRUNED_DIR_NAMES or name.startswith(PRUNED_DIR_PREFIXES)


def _iter_markdown(root: Path):
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = Path(dirpath).relative_to(root).as_posix()
        rel_dir = "" if rel_dir == "." else rel_dir
        dirnames[:] = [
            name
            for name in dirnames
            if not _is_pruned_dir(name)
            and not _is_exempt(f"{rel_dir}/{name}".lstrip("/"))
        ]
        for name in filenames:
            if not name.endswith(".md"):
                continue
            rel = f"{rel_dir}/{name}".lstrip("/")
            if _is_exempt(rel):
                continue
            yield Path(dirpath) / name, rel


def _strip_code(text: str) -> str:
    text = FENCE_RE.sub(lambda m: "\n" * m.group(0).count("\n"), text)
    return INLINE_CODE_RE.sub("", text)


def _resolves_case_exact(path: Path) -> bool:
    """True when every component of *path* exists with this exact case."""
    parts = path.parts
    if not parts:
        return False
    current = Path(parts[0])
    for part in parts[1:]:
        try:
            entries = {entry.name: entry for entry in os.scandir(current)}
        except OSError:
            return False
        entry = entries.get(part)
        if entry is None:
            return False
        current = Path(entry.path)
    return True


def check_links(root: Path) -> tuple[list[str], int, int]:
    root = root.resolve()
    issues: list[str] = []
    external = 0
    checked = 0
    for path, rel in _iter_markdown(root):
        text = _strip_code(path.read_text(encoding="utf-8", errors="replace"))
        for lineno, line in enumerate(text.splitlines(), start=1):
            for raw in LINK_RE.findall(line):
                target = raw.strip()
                if not target or target.startswith("#"):
                    continue
                if target.startswith(EXTERNAL_PREFIXES):
                    external += 1
                    continue
                if target.startswith("file:"):
                    issues.append(f"{rel}:{lineno}: file URI is not a link: {target}")
                    continue
                candidate = unquote(target.split("#", 1)[0].split("?", 1)[0])
                if not candidate:
                    continue
                if candidate.startswith("/"):
                    joined = Path(os.path.normpath(root / candidate.lstrip("/")))
                else:
                    joined = Path(os.path.normpath(path.parent / candidate))
                try:
                    joined.relative_to(root)
                except ValueError:
                    external += 1
                    continue
                checked += 1
                if not _resolves_case_exact(joined):
                    issues.append(f"{rel}:{lineno}: broken link: {target}")
    return issues, external, checked


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    args = parser.parse_args(argv)
    root: Path = args.root
    if not root.is_dir():
        print(f"ERROR: missing {root}", file=sys.stderr)
        return 2
    issues, external, checked = check_links(root)
    for issue in issues:
        print(f"BROKEN: {issue}")
    print(f"SUMMARY: broken={len(issues)} external={external} checked={checked}")
    print("Static check only: no file was modified and no network request was made.")
    return 0 if not issues else 1


if __name__ == "__main__":
    raise SystemExit(main())
