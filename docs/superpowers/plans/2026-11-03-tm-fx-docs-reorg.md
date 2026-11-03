# Kế hoạch thực thi — Tái cấu trúc tài liệu `tm-fx`

- **Ngày:** 2026-11-03
- **Trạng thái:** READY FOR EXECUTION
- **Nguồn (đã duyệt):** `docs/superpowers/specs/2026-11-03-tm-fx-docs-reorg-design.md`
- **Người thực hiện giả định:** kỹ sư chưa từng đọc repo này. Mọi đường dẫn, tên file, con số
  và lệnh kiểm chứng dưới đây là hợp đồng; không cần suy đoán thêm.
- **Thời lượng ước tính:** 1 phiên làm việc dài (13 task, 13 commit).

---

## 0. Mục tiêu, kiến trúc, stack

**Mục tiêu:** đưa toàn bộ tài liệu còn hiệu lực vào một cây theo mục đích, một điểm vào duy nhất,
một chuẩn input được viết ra, và một cổng chặn link chết — **không** sửa logic EA, **không** sửa
preset JSON, **không** chạy tester.

**Kiến trúc kết quả:**

```
docs/
├─ README.md                 # điểm vào duy nhất
├─ PROGRESS.md               # log append-only, giữ nguyên chỗ
├─ superpowers/              # spec + plan (tài liệu quy trình)
├─ 00-start/                 # roadmap, first-run, glossary
├─ 10-bots/                  # danh mục 15 EA, 5 trang bot, input-convention, ea-anatomy
├─ 20-operations/            # install, tester, demo-execution, toolchain, presets, troubleshooting, evidence
├─ 30-research/              # 14 tài liệu kỹ thuật + indicators/ (8) + ai-integration + open-source-research
├─ 90-decisions/             # 7 ADR cũ + ADR 0008
└─ 99-archive/               # V1/V2/V3 nguyên bản + LINK_MAP
```

**Stack:** Python 3.11 (pytest, script kiểm tra), PowerShell (build/deploy), MQL5 (chỉ đọc để lấy
bảng input và cập nhật comment đường dẫn).

**Task graph:** `T0 → T1 → T2 → T3 → T4 → (T5, T6) → T7 → T8 → T9 → T10 → T11 → T12`.
T5 và T6 độc lập nhau về file nhưng cùng ghi vào `docs/10-bots/`; làm tuần tự cho an toàn.

---

## 1. Ràng buộc toàn cục (áp dụng cho mọi task)

1. **Chỉ demo/Strategy Tester.** Không tạo, không sửa, không chạy bất kỳ thứ gì liên quan tài khoản
   real/live. Không thêm login, credential, `WebRequest`, socket.
2. **Không sửa `input` hoặc logic trong bất kỳ `.mq5`/`.mqh` nào.** Task 11 chỉ sửa **comment và
   `#property description`**. Không đổi tên input, không đổi giá trị mặc định.
3. **Không sửa `configs/demo/*.json`** và `configs/sim/*.json`.
4. **Không nâng nhãn trạng thái** của bất kỳ bot nào. Bộ nhãn là 9, cố định:
   `DONE`, `PASS`, `PARTIAL`, `READY_FOR_MANUAL_VALIDATION`, `NOT_RUN`,
   `BLOCKED` / `BLOCKED_PENDING_ADR`, `UNPROVEN`, `FAIL`.
5. **Không tắt/bỏ qua check** trong validator để làm cổng xanh. Không `# noqa`, không `try/except`
   nuốt lỗi, không xóa test.
6. **`99-archive/` là bất biến.** Chỉ `git mv` vào, không sửa nội dung, không viết lại link bên trong.
   `docs/PROGRESS.md` cũng bất biến (chỉ append).
7. **Không biến link ngoài repo thành link nội bộ giả.** `file:///D:/...` và `../../tm-trading/...`
   phải thành câu trích dẫn văn bản (dùng backtick), không phải link markdown.
8. **Không đưa `InfiniteRunnerXAUV3DemoEA.mq5` trở lại `mt5/`.**
9. **Mỗi task = một commit.** Không gộp task. Không `git push`.
10. **Ngôn ngữ:** tài liệu tiếng Việt có dấu, giữ token kỹ thuật tiếng Anh; commit message tiếng Anh.
11. **Mọi lệnh chạy từ `D:\Applications\tm-fx`.** Dùng `.\.venv\Scripts\python.exe`, không dùng
    `python` trần nếu chưa activate.
12. **Đóng terminal MT5 trước Task 11** (build/deploy cần quyền ghi vào thư mục dữ liệu).

---

## 2. Điều kiện tiên quyết

```powershell
cd D:\Applications\tm-fx
git status --porcelain          # phải khớp baseline ở Task 0
.\.venv\Scripts\python.exe -m pytest --collect-only -q | Select-Object -Last 1
# kỳ vọng trước Task 1: "430 tests collected"
```

Đo baseline **trước khi sửa gì** và ghi lại output thật:

```powershell
.\.venv\Scripts\python.exe scripts\validate_demo_execution.py   # kỳ vọng: checks=13 fail=0
.\.venv\Scripts\python.exe scripts\validate-project.py          # kỳ vọng: checks=14 fail=1
.\.venv\Scripts\python.exe -m pytest -q                          # kỳ vọng: 428 passed, 2 failed
```

Nếu số khác, **dừng lại** và báo chủ dự án; đừng "sửa cho khớp".

---

## Task 0 — Baseline commit + đánh dấu spec đã duyệt

**Files:**
- Modify: `docs/superpowers/specs/2026-11-03-tm-fx-docs-reorg-design.md` (1 dòng trạng thái)
- Git: stage toàn bộ working tree hiện có, trừ 4 mục rác/WIP

**Interfaces:**
- Consumes: working tree tại commit `88df404`.
- Produces: commit baseline sạch để `git mv` chạy được trên mọi file (kể cả file đang untracked).

**Steps**

1. Đổi dòng 4 của spec:

```markdown
- **Trạng thái:** APPROVED (chủ dự án duyệt 2026-11-03)
```

1b. Sửa hai dòng **đã kiểm là sai** trong bảng gap §9 của spec (thêm vào cuối bảng, không xoá dòng cũ):

```markdown
| `InpMaxDailyLossPct` | PA đang là `InpDailyLossLimitPct` | Đổi tên ở phase C |
| `InpMaxExposure` | IR và WW dùng `InpMaxLots` | Phase C thay bằng `InpMaxExposure` |
```

Lý do: đã quét source 2026-11-03 — PA không có `InpMaxDailyLossPct`; `InpMaxLots` có ở IR và WW
(không chỉ WW). Kế hoạch Task 6 dùng ma trận đầy đủ; spec phải khớp để không còn hai nguồn sự thật.

2. Stage có chủ đích, loại trừ rác và WIP:

```powershell
git add -A -- . `
  ':!mt5/Experts/InfiniteRunnerXAUV3DemoEA.mq5' `
  ':!node_modules' `
  ':!package.json' `
  ':!pnpm-lock.yaml'
git status --porcelain
```

Kỳ vọng: chỉ còn đúng 4 dòng untracked:

```
?? mt5/Experts/InfiniteRunnerXAUV3DemoEA.mq5
?? node_modules/
?? package.json
?? pnpm-lock.yaml
```

3. Commit:

```powershell
git commit -m "chore: baseline before docs reorg (ADR 0007, Wonderwhales demo EA, gates)"
git log -1 --oneline
```

**Verification:** `git status --porcelain` chỉ còn 4 mục trên; `git log -1` hiển thị commit mới.

---

## Task 1 — Cô lập IR V3 để cổng xanh lại

**Files:**
- Create: `archive/wip/2026-11-03_InfiniteRunnerXAUV3/README.md`
- Move: `mt5/Experts/InfiniteRunnerXAUV3DemoEA.mq5` → `archive/wip/2026-11-03_InfiniteRunnerXAUV3/`

**Interfaces:**
- Consumes: file untracked từ Task 0 (không dùng `git mv` được).
- Produces: `mt5/` không còn file vượt ranh giới `ExecBroker`; `validate-project.py` về `fail=0`.

**Steps**

1. Tạo README cô lập (nội dung chính xác):

```markdown
# WIP — InfiniteRunner XAU V3 (cô lập 2026-11-03)

File `InfiniteRunnerXAUV3DemoEA.mq5` là bản thử nghiệm của chủ dự án, **không** phải một phần
của bộ EA demo đã đăng ký.

- **Không** được build, deploy hay đưa vào `scripts/deploy_pineport.ps1`.
- **Không** được chạy trên tài khoản thật.
- Lý do cô lập: 6 lời gọi `AccountInfoDouble`/`AccountInfoInteger` (dòng 534, 1621, 1626,
  1699, 1704, 1705) nằm ngoài `mt5/Include/Exec/*`, vi phạm ranh giới "chỉ `ExecBroker` gửi lệnh"
  mà `scripts/validate-project.py` quét.
- Điều kiện đưa trở lại `mt5/`: chuyển toàn bộ truy cập tài khoản vào `mt5/Include/Exec/*`,
  compile 0 lỗi / 0 cảnh báo, và có ADR riêng chấp thuận bot demo thứ sáu.

Trạng thái: `BLOCKED` — chưa có ADR, chưa có bằng chứng tester.
```

2. Di chuyển file (plain move vì chưa tracked):

```powershell
New-Item -ItemType Directory -Force archive\wip\2026-11-03_InfiniteRunnerXAUV3 | Out-Null
Move-Item mt5\Experts\InfiniteRunnerXAUV3DemoEA.mq5 archive\wip\2026-11-03_InfiniteRunnerXAUV3\
```

3. Chạy cổng:

```powershell
.\.venv\Scripts\python.exe scripts\validate-project.py
.\.venv\Scripts\python.exe -m pytest -q
```

Kỳ vọng: `SUMMARY: checks=14 fail=0` và `430 passed`.

4. Commit:

```powershell
git add -A
git commit -m "chore: quarantine InfiniteRunner XAU V3 WIP out of mt5/"
```

**Verification:** `Test-Path mt5\Experts\InfiniteRunnerXAUV3DemoEA.mq5` → `False`;
`Test-Path archive\wip\2026-11-03_InfiniteRunnerXAUV3\InfiniteRunnerXAUV3DemoEA.mq5` → `True`.

---

## Task 2 — Dọn rác thư mục gốc + `.gitignore`

**Files:**
- Delete: `reportsbuild-allsuite/`, `pip-metadata-6127bt5c/`, `pip-unpack-fo46zcow/`,
  `pytest-of-tuanmjnh/`, `.pytest_cache/`, `node_modules/`, `package.json`, `pnpm-lock.yaml`,
  `build_test.log`
- Modify: `.gitignore` (thêm `node_modules/`)

**Interfaces:**
- Consumes: Task 0 đã loại các mục này khỏi commit baseline.
- Produces: `git status --porcelain` rỗng.

**Steps**

1. Kiểm tra từng mục là rác có thể sinh lại (không có file nguồn):

```powershell
Get-ChildItem reportsbuild-allsuite -Recurse -File | Group-Object Extension | Select-Object Name,Count
# kỳ vọng: chỉ .log
```

2. Xóa:

```powershell
Remove-Item -Recurse -Force reportsbuild-allsuite, pip-metadata-6127bt5c, pip-unpack-fo46zcow,
  pytest-of-tuanmjnh, .pytest_cache, node_modules
Remove-Item -Force package.json, pnpm-lock.yaml, build_test.log
```

3. Thêm vào cuối `.gitignore`:

```gitignore
# Node (repo không có mã JS)
node_modules/
```

4. Kiểm tra không còn gì:

```powershell
git status --porcelain     # kỳ vọng: rỗng (trước commit)
Get-ChildItem -Force | Select-Object Name
```

5. Commit:

```powershell
git add .gitignore
git commit -m "chore: remove build junk from repo root"
```

**Verification:** `reports/` và `github-demo/` **vẫn còn** (đã gitignore, là bằng chứng/vật liệu audit).

---

## Task 3 — `git mv` tài liệu + cập nhật đường dẫn trong 8 script

Đây là task rủi ro cao nhất. Làm **một lần**, không copy. Cuối task phải xanh cả 8 validator.

**Files:**
- Move: theo bảng dưới (dùng `git mv`, giữ lịch sử)
- Modify: `scripts/validate-project.py`, `scripts/validate_demo_execution.py`,
  `scripts/validate_pineport.py`, `scripts/validate_longkaco.py`, `scripts/validate_pamtf.py`,
  `scripts/validate_tmfz.py`, `scripts/validate_tmind2.py`, `scripts/validate_tmxau2.py`,
  `scripts/package_pineport.ps1`, `scripts/deploy_pineport.ps1`

**Interfaces:**
- Consumes: cây `docs/` tại Task 2.
- Produces: cây đích §6 của spec; tên file mới là hợp đồng cho Task 4–12.

**Steps**

1. Di chuyển thư mục trước (thứ tự quan trọng — `docs/30-research` phải tồn tại trước `indicators`):

```powershell
git mv docs\reference docs\30-research
git mv docs\indicators docs\30-research\indicators
git mv docs\decisions docs\90-decisions
```

2. Tạo thư mục đích còn lại:

```powershell
New-Item -ItemType Directory -Force docs\00-start, docs\10-bots, docs\20-operations\presets, docs\99-archive | Out-Null
```

3. Di chuyển từng file:

```powershell
git mv docs\MASTER_ROADMAP.md docs\00-start\roadmap.md
git mv docs\guides\beginner-first-run.md docs\00-start\first-run.md
git mv docs\guides\install-and-test.md docs\20-operations\install.md
git mv docs\guides\strategy-tester.md docs\20-operations\strategy-tester.md
git mv docs\guides\demo-execution.md docs\20-operations\demo-execution.md
git mv docs\guides\toolchain.md docs\20-operations\toolchain.md
git mv docs\guides\ea-anatomy-and-ai.md docs\10-bots\ea-anatomy.md
git mv docs\configurations\README.md docs\20-operations\presets.md
foreach ($f in 'dca_demo.set','grid_demo.set','infinite_runner_v2.set','pa_trendrider_xau.set') {
  git mv "docs\configurations\$f" "docs\20-operations\presets\$f"
}
git mv docs\MT5_EA_Lab_V1 docs\99-archive\MT5_EA_Lab_V1
git mv docs\MT5_EA_Lab_V2 docs\99-archive\MT5_EA_Lab_V2
git mv docs\MT5_EA_Lab_V3 docs\99-archive\MT5_EA_Lab_V3
```

4. Dọn thư mục rỗng:

```powershell
Remove-Item docs\guides, docs\configurations -Force
```

5. Cập nhật `scripts/validate-project.py` — `REQUIRED_FILES` (dòng 80–152), thay đúng 15 dòng:

| Dòng cũ | Dòng mới |
|---|---|
| `"docs/MASTER_ROADMAP.md",` | `"docs/00-start/roadmap.md",` |
| `"docs/guides/install-and-test.md",` | `"docs/20-operations/install.md",` |
| `"docs/guides/strategy-tester.md",` | `"docs/20-operations/strategy-tester.md",` |
| `"docs/guides/toolchain.md",` | `"docs/20-operations/toolchain.md",` |
| `"docs/indicators/README.md",` | `"docs/30-research/indicators/README.md",` |
| `"docs/indicators/parity.md",` | `"docs/30-research/indicators/parity.md",` |
| `"docs/reference/architecture.md",` | `"docs/30-research/architecture.md",` |
| `"docs/reference/simulation.md",` | `"docs/30-research/simulation.md",` |
| `"docs/reference/testing.md",` | `"docs/30-research/testing.md",` |
| `"docs/reference/risk.md",` | `"docs/30-research/risk.md",` |
| `"docs/reference/release.md",` | `"docs/30-research/release.md",` |
| `"docs/decisions/0003-demo-execution-scope.md",` | `"docs/90-decisions/0003-demo-execution-scope.md",` |
| `"docs/decisions/0004-all-bots-demo-execution.md",` | `"docs/90-decisions/0004-all-bots-demo-execution.md",` |
| `"docs/decisions/0007-wonderwhales-demo-bot.md",` | `"docs/90-decisions/0007-wonderwhales-demo-bot.md",` |
| `"docs/guides/demo-execution.md",` | `"docs/20-operations/demo-execution.md",` |

6. Cập nhật `scripts/validate_demo_execution.py` dòng 44–47:

```python
ADR = "docs/90-decisions/0004-all-bots-demo-execution.md"
ADR_0003 = "docs/90-decisions/0003-demo-execution-scope.md"
ADR_0007 = "docs/90-decisions/0007-wonderwhales-demo-bot.md"
GUIDE = "docs/20-operations/demo-execution.md"
```

7. Cập nhật 6 validator indicator: đổi tiền tố `docs/indicators/` → `docs/30-research/indicators/`
   trong các dict hằng số (và trong docstring dòng 3 của `validate_tmind2.py` / `validate_tmxau2.py`):

```powershell
$files = 'validate_pineport.py','validate_longkaco.py','validate_pamtf.py',
         'validate_tmfz.py','validate_tmind2.py','validate_tmxau2.py'
foreach ($f in $files) {
  $p = "scripts\$f"
  $t = Get-Content $p -Raw -Encoding UTF8
  $t = $t -replace 'docs/indicators/', 'docs/30-research/indicators/'
  [IO.File]::WriteAllText((Resolve-Path $p), $t, (New-Object Text.UTF8Encoding($false)))
}
```

8. Cập nhật `scripts/package_pineport.ps1` dòng 40–64:

```powershell
$p = 'scripts\package_pineport.ps1'
$t = Get-Content $p -Raw -Encoding UTF8
$t = $t -replace 'docs/indicators/', 'docs/30-research/indicators/'
$t = $t -replace 'docs/reference/testing\.md', 'docs/30-research/testing.md'
$t = $t -replace 'docs/guides/install-and-test\.md', 'docs/20-operations/install.md'
[IO.File]::WriteAllText((Resolve-Path $p), $t, (New-Object Text.UTF8Encoding($false)))
```

9. Cập nhật `scripts/deploy_pineport.ps1` dòng 344:

```powershell
$t = $t -replace 'docs\\guides\\demo-execution\.md', 'docs\20-operations\demo-execution.md'
```

(Thực hiện bằng `Get-Content -Raw` + `[IO.File]::WriteAllText` như bước 8, chỉ đổi một chuỗi.)

10. Kiểm tra không còn đường dẫn cũ trong `scripts/`:

```powershell
Select-String -Path scripts\*.py,scripts\*.ps1 -Pattern 'docs[\\/](guides|reference|indicators|decisions|configurations|MASTER_ROADMAP)'
```

Kỳ vọng: **rỗng**.

11. Chạy toàn bộ cổng:

```powershell
.\.venv\Scripts\python.exe scripts\validate_demo_execution.py
.\.venv\Scripts\python.exe scripts\validate-project.py
foreach ($f in 'validate_pineport.py','validate_longkaco.py','validate_pamtf.py','validate_tmfz.py','validate_tmind2.py','validate_tmxau2.py') {
  .\.venv\Scripts\python.exe "scripts\$f"
}
.\.venv\Scripts\python.exe -m pytest -q
```

Kỳ vọng: `checks=13 fail=0`; `checks=14 fail=0`; 32/29/36/34/44/31 pass, 0 fail; `430 passed`.

12. Commit:

```powershell
git add -A
git commit -m "docs: move documentation into purpose-based tree"
```

**Verification:** `git status --porcelain` rỗng; `git log --stat -1` cho thấy rename (không phải
delete+add); 8 validator xanh. **Nếu bất kỳ validator đỏ → `git revert HEAD` và sửa lại bước 5–9.**

---

## Task 4 — `scripts/check_docs_links.py` + 6 test (TDD, chưa nối vào gate)

**Files:**
- Create: `python/tests/test_check_docs_links.py`
- Create: `scripts/check_docs_links.py`

**Interfaces:**
- Produces: `check_links(root: Path) -> tuple[list[str], int, int]` trả về
  `(issues, external, checked)`; `main(argv) -> int` với exit 0/1/2.
- Produces: định dạng issue `"<file>:<line>: broken link: <target>"` và
  `"<file>:<line>: file URI is not a link: <target>"`.

**Steps**

1. Viết test trước (nguyên văn):

```python
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
```

2. Chạy để thấy đỏ:

```powershell
.\.venv\Scripts\python.exe -m pytest python/tests/test_check_docs_links.py -q
```

Kỳ vọng: 6 failed (không tìm thấy module / file).

3. Viết `scripts/check_docs_links.py` (nguyên văn):

```python
"""Check every relative markdown link in the repository.

Only local targets are validated: a link must resolve to an existing file or
directory, with the exact case used on disk. External schemes (http, https,
mailto, tel) and same-page anchors are skipped and counted separately.
``file:`` URIs are reported as broken so documentation uses relative paths.

Exempt by design: ``docs/PROGRESS.md`` (append-only history) and the immutable
snapshots under ``docs/99-archive/`` and ``archive/``.

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

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
FENCE_RE = re.compile(r"^```.*?^```", re.MULTILINE | re.DOTALL)
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")
EXTERNAL_PREFIXES = ("http://", "https://", "mailto:", "tel:")


def _is_exempt(rel: str) -> bool:
    if rel in EXEMPT_FILES:
        return True
    return any(rel == d or rel.startswith(d + "/") for d in EXEMPT_DIRS)


def _iter_markdown(root: Path):
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = Path(dirpath).relative_to(root).as_posix()
        rel_dir = "" if rel_dir == "." else rel_dir
        dirnames[:] = [
            name for name in dirnames if not _is_exempt(f"{rel_dir}/{name}".lstrip("/"))
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
```

4. Chạy lại:

```powershell
.\.venv\Scripts\python.exe -m pytest python/tests/test_check_docs_links.py -q
```

Kỳ vọng: 6 passed.

5. Chạy toàn bộ pytest (checker **chưa** nối vào validator nên cổng vẫn xanh):

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

Kỳ vọng: `436 passed`.

6. Ghi lại baseline link (không dùng làm cổng): script sẽ đỏ vì Task 10 chưa chạy.

```powershell
.\.venv\Scripts\python.exe scripts\check_docs_links.py | Select-Object -Last 1
```

7. Commit:

```powershell
git add python/tests/test_check_docs_links.py scripts/check_docs_links.py
git commit -m "test: add markdown link checker"
```

**Verification:** 6 test mới xanh; `436 passed`; `scripts/check_docs_links.py` tồn tại và chạy được.

---

## Task 5 — `10-bots/`: danh mục 15 EA + 5 trang bot

**Files:**
- Create: `docs/10-bots/README.md`
- Create: `docs/10-bots/pa-trendrider.md`, `grid.md`, `dca.md`, `infinite-runner.md`, `wonderwhales.md`

**Interfaces:**
- Consumes: EA sources trong `mt5/Experts/`; preset `configs/demo/*.json`;
  nguồn lịch sử `docs/99-archive/MT5_EA_Lab_V1/`, `docs/99-archive/MT5_EA_Lab_V2/`.
- Produces: 5 trang bot mà Task 9 (`docs/README.md`) và Task 10 (link rewrite) trỏ tới.

**Steps**

1. Lấy bảng input **từ source thật** (không chép từ tài liệu cũ):

```powershell
foreach ($f in 'PATrendRiderXAUv1DemoEA','GridDemoEA','DCADemoEA','InfiniteRunnerXAUV2DemoEA','WonderwhalesDemoEA') {
  "=== $f"
  (Get-Content "mt5\Experts\$f.mq5" -Encoding UTF8 | Select-String '^\s*input\s').Line -replace '\s+',' '
}
```

Quy tắc bảng: giữ đúng thứ tự khai báo, chia theo `input group`, cột 3 là
`Tên chuẩn (phase C)` lấy từ `docs/10-bots/input-convention.md` (Task 6). **Không** in input không
tồn tại trong code.

2. Viết `docs/10-bots/README.md` (≤120 dòng) với bảng **15 EA** đúng thứ tự sau:

| EA | kind | magic | preset | trang | trạng thái |
|---|---|---|---|---|---|
| `PATrendRiderXAUv1DemoEA.mq5` | demo | 25002001 | `configs/demo/pa_trendrider_xau_demo.json` | `pa-trendrider.md` | `PARTIAL` |
| `GridDemoEA.mq5` | demo | 25004001 | `configs/demo/grid_demo.json` | `grid.md` | `NOT_RUN` |
| `DCADemoEA.mq5` | demo | 25005001 | `configs/demo/dca_demo.json` | `dca.md` | `NOT_RUN` |
| `InfiniteRunnerXAUV2DemoEA.mq5` | demo | 25006001 | `configs/demo/infinite_runner_demo.json` | `infinite-runner.md` | `NOT_RUN` |
| `WonderwhalesDemoEA.mq5` | demo | 25007001 | `configs/demo/wonderwhales_demo.json` | `wonderwhales.md` | `UNPROVEN` |
| `PATrendRiderXAUv1SimEA.mq5` | sim | N/A | `configs/sim/pa_trendrider_xau.json` | — | `NOT_RUN` ¹ |
| `RunnerTrailingLabEA.mq5` | sim | N/A | `configs/sim/runner_trailing.json` | — | `NOT_RUN` ¹ |
| `GridLabEA.mq5` | sim | N/A | `configs/sim/grid_lab.json` | — | `NOT_RUN` ¹ |
| `DCALabEA.mq5` | sim | N/A | `configs/sim/dca_lab.json` | — | `NOT_RUN` ¹ |
| `PinePlanSimEA.mq5` | sim | N/A | `configs/sim/pine_plan_lab.json` | — | `NOT_RUN` ¹ |
| `WonderwhalesSimEA.mq5` | sim | N/A | `configs/sim/wonderwhales_xauusdm.json` | — | `NOT_RUN` ¹ |
| `LabSignalEA.mq5` | signal | N/A | N/A | — | `PASS` (§48.5) |
| `PineSignalLabEA.mq5` | signal | N/A | N/A | — | `NOT_RUN` ¹ |
| `PineMultiSignalLabEA.mq5` | signal | N/A | N/A | — | `NOT_RUN` ¹ |
| `LabOnnxInference.mq5` | inference | N/A | N/A | — | `PARTIAL` (§50) |

¹ **Quy tắc nhãn cho 10 EA lab (bắt buộc):** nhãn phải dựa trên một mục `PROGRESS.md` có bằng chứng
chạy thật cho **chính EA đó**. Trước khi viết, chạy:

```powershell
foreach ($n in 'PATrendRiderXAUv1SimEA','RunnerTrailingLabEA','GridLabEA','DCALabEA','PinePlanSimEA','WonderwhalesSimEA','PineSignalLabEA','PineMultiSignalLabEA') {
  "=== $n"; Select-String -Path docs\PROGRESS.md -Pattern $n | Select-Object -Last 3 | ForEach-Object { $_.LineNumber }
}
```

- Tìm thấy mục ghi tester/run cụ thể → dùng đúng nhãn mục đó ghi, thêm `(§<số>)` vào ô.
- Không tìm thấy → **giữ `NOT_RUN`**. Không suy ra `PASS` từ việc "có validator xanh" hay "có test suite
  dùng chung": `SimCoreTests`/`SimPlanTests` là suite của thư viện, không phải bằng chứng của từng EA.
- `LabSignalEA` = `PASS` và `LabOnnxInference` = `PARTIAL` đã kiểm: §48.5 (tester PASS, 0 trade) và
  §50 (tester chạy được, parity Track B vẫn `BLOCKED`). Không đổi hai nhãn này.

Thêm footnote: script `ExecDemoProbe` dùng magic **25002002** (không phải EA, không tính vào 15).

3. Viết 5 trang bot, mỗi trang ≤200 dòng, **đúng 6 mục** theo thứ tự:

1. **Chiến lược** — 1 đoạn: vào lệnh thế nào, thoát thế nào.
2. **Cấu trúc code** — file EA + include liên quan (chỉ nêu file có thật).
3. **Bảng input** — từ bước 1, kèm cột `Tên chuẩn (phase C)`.
4. **Preset và magic** — JSON, `.set` (nếu có), magic, symbol/timeframe mặc định.
5. **Bằng chứng** — nhãn + số liệu + đường dẫn `reports/...` hoặc mục `PROGRESS.md`.
6. **Giới hạn / quirk đã biết** — không tô hồng.

Nguồn và dữ kiện bắt buộc:

| Trang | Nguồn | Dữ kiện bắt buộc |
|---|---|---|
| `pa-trendrider.md` | `docs/99-archive/MT5_EA_Lab_V1/PA_TrendRider_XAU_V1_Specification_Vietnamese.md`; `docs/99-archive/MT5_EA_Lab_V2/STRATEGIES/PA_TRENDRIDER_XAU_V1.md` | H1 bias / M15 structure / M5 entry; `InpTakeProfitR=3.0`; magic 25002001; nhãn `PARTIAL` — đường gửi lệnh có bằng chứng thật (§44/§45), **chưa có ENTRY trên chart** (§52), lợi nhuận `UNPROVEN`; thiếu `InpCloseOnKillSwitch` |
| `grid.md` | `docs/99-archive/MT5_EA_Lab_V2/STRATEGIES/GRID_EA.md` | lưới có chặn `InpMaxGridLevels=5`, `InpMaxLevelVolume=0.10`, `InpVolumeMultiplier=1.50`; basket SL/TP; magic 25004001; `NOT_RUN` |
| `dca.md` | `docs/99-archive/MT5_EA_Lab_V2/STRATEGIES/DCA_EA.md` | DCA theo thời gian vs theo biến động; `InpMaxDcaAdds`, `InpDcaDistancePoints`; basket caps; magic 25005001; `NOT_RUN` |
| `infinite-runner.md` | `docs/99-archive/MT5_EA_Lab_V2/STRATEGIES/InfiniteRunner_XAU_Upgrade_Pack/README.md` + `.../INFINITERUNNER_XAU_REVIEW_AND_UPGRADE_SPEC.md`; `docs/90-decisions/0005-infiniterunner-xau-demo-bot.md` | Legacy EMA vs direction mode; trailing `InpTrailStartPts`/`InpTrailDistancePts`/`InpTrailStepPts`; safety TP xa; magic 25006001; `NOT_RUN`; quirk: hậu tố `Pts` lệch 4 EA còn lại |
| `wonderwhales.md` | `docs/30-research/indicators/wonderwhales.md`; `docs/90-decisions/0007-wonderwhales-demo-bot.md` | PSAR single-position; guard; tester 2026.01.05→15: 41 ENTRY/41 EXIT, net **−625.72**, `HALTED`; magic 25007001; nhãn `UNPROVEN`; chưa có phiên demo chart (`NOT_RUN` cho phần đó) |

4. Kiểm tra nhanh không có tên input bịa. **Chỉ cột "tên hiện tại" phải tồn tại trong source**;
   cột `Tên chuẩn (phase C)` được phép chứa tên chưa có (ví dụ `InpMaxExposure` ở trang IR/WW):

```powershell
# mọi tên trong cột hiện tại của 5 trang phải có trong EA tương ứng
foreach ($p in 'pa-trendrider','grid','dca','infinite-runner','wonderwhales') {
  "=== $p"
  Select-String -Path "docs\10-bots\$p.md" -Pattern '\bInp[A-Za-z0-9]+\b' -AllMatches |
    ForEach-Object { $_.Matches.Value } | Sort-Object -Unique
}
```

Đối chiếu thủ công với output bước 1: mọi tên ở **cột 2** phải có; tên chỉ ở cột 3 thì ghi rõ
"phase C" trong ô, không được trộn vào cột 2. Tên sai → sửa trang, **không** sửa EA.

5. Commit:

```powershell
git add docs/10-bots
git commit -m "docs: add bot catalog and five bot pages"
```

**Verification:** `docs/10-bots/` có 6 file; mỗi trang ≤200 dòng; mọi `Inp*` trong trang tồn tại
trong EA tương ứng.

---

## Task 6 — `input-convention.md` + tách `ea-anatomy.md` / `ai-integration.md`

**Files:**
- Create: `docs/10-bots/input-convention.md`
- Modify: `docs/10-bots/ea-anatomy.md` (đã move từ `guides/ea-anatomy-and-ai.md`)
- Create: `docs/30-research/ai-integration.md`

**Interfaces:**
- Consumes: spec §9 (đã duyệt).
- Produces: cột `Tên chuẩn (phase C)` cho Task 5 và hợp đồng cho phase C.

**Steps**

1. Viết `docs/10-bots/input-convention.md` (150–400 dòng) với **đúng 7 mục**:

1. **Sáu nhóm cố định, đúng thứ tự** — chép nguyên bảng §9 của spec (group → input bắt buộc).
2. **Quy tắc đặt tên** — `Inp` + PascalCase; đơn vị trong tên (`Points`, `Minutes`, `Percent`, `R`);
   boolean đọc như mệnh đề; file `<BOT>_DEMO_STOP.txt`, `<bot>_demo*.csv`; không viết tắt ngoài
   `SL`, `TP`, `R`, `ATR`, `DCA`, `PSAR`; **tên input trong EA == key trong `configs/demo/*.json`,
   giữ nguyên tiền tố `Inp`**.
3. **SL/TP theo 4 loại bot** — chép bảng §9 (`single_position`, `runner_trailing`, `bounded_grid`,
   `bounded_dca`).
4. **Bất biến kiểm được bằng máy** — chép bảng §9 (magic, kill switch, `InpCloseOnKillSwitch`,
   `InpRiskPercent`/`InpMaxPositions`/`InpCooldownMinutes`, preset đủ key).
5. **Bảng gap hiện tại → chuẩn** — chép bảng §9, rồi **sửa bằng số liệu đã quét từ source** (ma trận
   dưới đây đã kiểm bằng `Select-String` trên 5 `*DemoEA.mq5`; nếu §9 khác thì ma trận này thắng):

   | Input chuẩn | PA | Grid | DCA | IR | WW |
   |---|---|---|---|---|---|
   | `InpMaxDailyLossPct` | **thiếu** (đang là `InpDailyLossLimitPct`) | có | có | có | có |
   | `InpMaxDrawdownPct` | có | có | có | có | có |
   | `InpMaxConsecutiveLosses` | có | có | có | có | có |
   | `InpMaxSpreadPoints` | có | có | có | có | có |
   | `InpMaxExposure` | **thiếu** | có | có | **thiếu** (dùng `InpMaxLots`) | **thiếu** (dùng `InpMaxLots`) |
   | `InpMaxPositions` | có | **thiếu** | **thiếu** | có | **thiếu** |
   | `InpRiskPercent` | có | **thiếu** | **thiếu** | có | có |
   | `InpCooldownMinutes` | có | **thiếu** | **thiếu** | có | có |
   | `InpCloseOnKillSwitch` | **thiếu** | có | có | có | có |
   | `InpHaltOnBreach` | **thiếu** | có | có | có | có |
   | `InpKillSwitchFile` | có | có | có | có | có |

   Ghi chú bắt buộc: `InpMaxLots` (IR, WW) không nằm trong chuẩn → phase C thay bằng `InpMaxExposure`;
   PA đổi `InpDailyLossLimitPct` → `InpMaxDailyLossPct`; Grid/DCA thêm `InpRiskPercent` /
   `InpMaxPositions` / `InpCooldownMinutes`; PA thêm `InpCloseOnKillSwitch` + `InpHaltOnBreach`.
   **Không** ghi "cả 5 EA đều có" cho bất kỳ dòng nào ngoài 4 dòng đã xác nhận.
6. **Ánh xạ preset** — `configs/demo/*.json` là nguồn sự thật; `.set` là dẫn xuất thủ công;
   đổi input phải đổi JSON + `.set` + chạy `validate-project.py` trong **cùng một commit**.
7. **Thứ tự migration phase C** — mỗi lần một EA: (a) thêm input thiếu, (b) đổi tên group,
   (c) đổi `Pts`→`Points` **cuối cùng** (vì phải sửa preset cùng lúc), (d) chạy validator + compile,
   (e) ghi `PROGRESS.md`.

2. Tách `docs/10-bots/ea-anatomy.md`. File hiện có 13 mục; xử lý **từng mục** theo bảng:

| Mục hiện tại | Hành động | Đích |
|---|---|---|
| 1. Sơ đồ tổng quan | Giữ | 1 |
| 2. Giải phẫu một file EA (2.1–2.3) | Giữ nguyên | 2 |
| 3. Thư viện dùng chung | Giữ nguyên | 3 |
| 4. Danh mục bot trong repo | **Thay bằng 3 dòng** trỏ `10-bots/README.md` | 4 |
| 5. Cài đặt | **Thay bằng 3 dòng** trỏ `20-operations/install.md` | 5 |
| 6. Cấu hình 4 tầng | **Thay bằng 3 dòng** trỏ `20-operations/presets.md` | 6 |
| 7. Bảng tham số theo bot | **Xóa hẳn** (đã có bảng input thật ở 5 trang bot) | — |
| 8. Cổng rủi ro | Giữ nguyên | 7 |
| 9. Thao tác GUI | Giữ nguyên | 8 |
| 10. Vòng đời vị thế | Giữ nguyên | 9 |
| 11. Ghép AI | **Cắt**, chuyển sang bước 3 | — |
| 12. Trạng thái bằng chứng | Giữ, thay số liệu cũ bằng nhãn hiện tại | 10 |
| 13. Đọc tiếp | Viết lại thành danh sách link mới | 11 |

- Đánh số lại 1–11 và **cập nhật mục lục ở dòng 15** cho khớp.
- Sửa mọi link nội bộ trong file sang đường dẫn mới (file này không do Task 10 xử lý).
- Độ dài đích 150–400 dòng. Không giữ bảng tham số cũ: đó là nguồn trùng lặp đã lỗi thời
  (ví dụ "PA 47 input, 7 nhóm" trong khi trang `pa-trendrider.md` lấy trực tiếp từ source).

3. Viết `docs/30-research/ai-integration.md` (150–400 dòng) từ mục 11 đã cắt:

1. Ba mức tích hợp AI (signal-only / hybrid / full) — ưu nhược điểm.
2. Pipeline B (offline train → export ONNX → `LabOnnxInference` → EA đọc tín hiệu) — sơ đồ ASCII.
3. Ràng buộc: bảng cấu hình phải khớp tuyệt đối giữa Python và MQL5 (feature order, scaler,
   threshold); lệch một cột là sai âm thầm.
4. Công thức ghép an toàn: AI chỉ được **lọc** tín hiệu, không được bỏ qua SL/TP/risk guard.
5. Trạng thái hiện tại: `READY_FOR_MANUAL_VALIDATION`, chưa có bằng chứng parity trên dữ liệu thật.

4. Commit:

```powershell
git add docs/10-bots docs/30-research/ai-integration.md
git commit -m "docs: add input convention and split EA anatomy"
```

**Verification:** `input-convention.md` có đủ 7 mục và 4 bảng của §9; `ea-anatomy.md` không còn
nội dung AI; `ai-integration.md` tồn tại.

---

## Task 7 — Chưng cất tài liệu vận hành

**Files:**
- Create: `docs/20-operations/README.md`
- Create: `docs/20-operations/troubleshooting.md`
- Create: `docs/20-operations/evidence.md`
- Modify: `docs/20-operations/presets.md` (đã move từ `configurations/README.md`)

**Interfaces:**
- Consumes: `docs/99-archive/MT5_EA_Lab_V2/TROUBLESHOOTING.md`, `EVIDENCE.md`, `TEST_REPORT.md`;
  `docs/99-archive/MT5_EA_Lab_V3/docs/ZERO_TRADE_DIAGNOSTICS.md`,
  `NO_TRADE_DIAGNOSIS_TEMPLATE.md`, `IMPLEMENTATION_STATUS.md`;
  `docs/PROGRESS.md` §66.4, §68, §69.
- Produces: 4 trang vận hành mà Task 9 trỏ tới.

**Steps**

1. `docs/20-operations/README.md` (≤30 dòng): bảng 7 file trong thư mục + 1 câu mô tả mỗi file +
   thứ tự đọc khi muốn chạy bot.

2. `docs/20-operations/troubleshooting.md` (150–400 dòng), đúng 5 mục:

1. **Nguyên tắc:** không nới gate, không đổi input mặc định để "cho có lệnh"; mọi kết luận phải
   kèm reason code và dòng log.
2. **Pipeline 10 bước** (chép từ `ZERO_TRADE_DIAGNOSTICS.md` §5, giữ nguyên thứ tự): context →
   history → direction → setup → filter → sizing → margin → request → reconcile → log.
3. **7 nguyên nhân đã gặp thật** — bảng `triệu chứng | cách xác nhận | cách sửa | nguồn`:

| # | Nguyên nhân | Xác nhận | Nguồn |
|---|---|---|---|
| 1 | Dry-run: `InpEnableExecution=false` | journal không có `ENTRY`, panel ghi `DRY_RUN` | ADR 0006 |
| 2 | File kill switch còn tồn tại | log `HALT|reason=kill_switch` | `docs/90-decisions/0004-...` |
| 3 | Halt phục hồi từ state file (`restored=1`) | `INIT` có `restored=1`, `state=HALTED` | §69.4 |
| 4 | Filter chặn entry (spread/bias/regime) | `RISK ENTRY_BLOCKED|reason=...` | §52.4 |
| 5 | Tester headless: `MQL_TESTER=0` → `context_denied|reason=terminal_trade_disabled` | journal `INIT_FAILED` | §68.1 |
| 6 | EA nhận vị thế lạc cùng magic → `InpMaxPositions` đầy | `ExecFindOwnPosition` thấy position, `g_have_pos=true` | chẩn đoán 2026-11-03 (**chưa chạy lại**, `NOT_RUN`) |
| 7 | `.set` không copy vào `MQL5\Profiles\Tester\` → tester dùng input mặc định | journal ghi tên log mặc định | §69.4 |

4. **Checklist trước khi kết luận "0 trade"** — 6 dòng, mỗi dòng yêu cầu một bằng chứng cụ thể.
5. **Regression test bắt buộc** — mỗi nguyên nhân phải có test/kiểm tra tạo đúng một blocker và
   assert đúng reason code.

3. `docs/20-operations/evidence.md` (150–400 dòng), đúng 4 mục:

1. **9 nhãn trạng thái** — bảng: nhãn | nghĩa | loại (hợp đồng / phụ).
   Hợp đồng: `DONE`, `PASS`, `PARTIAL`, `NOT_RUN`, `BLOCKED`, `UNPROVEN`.
   Phụ: `FAIL`, `BLOCKED_PENDING_ADR`, `READY_FOR_MANUAL_VALIDATION`.
2. **Bảng bằng chứng theo tuyên bố** — claim | bằng chứng (file + sha256 nếu có) | nhãn.
   Tối thiểu 6 dòng: compile 0/0; `validate_*` pass; tester PA; tester WW; `ExecDemoProbe` demo thật;
   parity Track B (`BLOCKED`).
3. **Bằng chứng bị cấm dùng:** ảnh không sha256; log không lưu; "chạy được trên máy tôi";
   kết quả tester không có file `.htm`/`.csv`; suy luận từ code.
4. **Nơi lưu:** `reports/build/tester-reports/<scenario>/` (gitignored), quy ước đặt tên.

4. Viết lại `docs/20-operations/presets.md` (150–400 dòng), đúng 6 mục:

1. **Nguồn sự thật:** `configs/demo/*.json`; key trong `inputs` trùng tên input EA (giữ `Inp`).
2. **`.set` là dẫn xuất thủ công.** Nói thẳng: **hiện không có script nào sinh hoặc validate `.set`**;
   `validate-project.py` chỉ kiểm JSON. Phase C mới thêm kiểm `.set`.
3. **Bảng 5 bot:**

| Bot | JSON | `.set` | magic |
|---|---|---|---|
| PA | `configs/demo/pa_trendrider_xau_demo.json` | `presets/pa_trendrider_xau.set` | 25002001 |
| Grid | `configs/demo/grid_demo.json` | `presets/grid_demo.set` | 25004001 |
| DCA | `configs/demo/dca_demo.json` | `presets/dca_demo.set` | 25005001 |
| IR | `configs/demo/infinite_runner_demo.json` | `presets/infinite_runner_v2.set` | 25006001 |
| WW | `configs/demo/wonderwhales_demo.json` | **không có** | 25007001 |

4. **Quy tắc đổi preset an toàn:** đổi JSON + `.set` + chạy `validate-project.py` + ghi `PROGRESS.md`
   trong cùng một commit; không đổi magic; không đặt `InpEnableExecution=false` trong preset demo
   (ADR 0006).
5. **Magic table** — 6 dòng, gồm probe 25002002.
6. **Trước khi chạy tester:** copy `.set` vào `MQL5\Profiles\Tester\`; nếu thiếu, tester dùng input
   mặc định (bằng chứng §69.4).

5. Commit:

```powershell
git add docs/20-operations
git commit -m "docs: distill operations documentation"
```

**Verification:** 4 file tồn tại; `presets.md` có câu khẳng định `.set` chưa được kiểm tự động;
`troubleshooting.md` có đủ 7 nguyên nhân và 5 mục.

---

## Task 8 — Research, decisions, archive: index + ADR 0008 + LINK_MAP

**Files:**
- Create: `docs/30-research/README.md`
- Create: `docs/30-research/open-source-research.md`
- Create: `docs/90-decisions/README.md`
- Create: `docs/90-decisions/0008-docs-information-architecture.md`
- Create: `docs/99-archive/README.md`
- Create: `docs/99-archive/LINK_MAP.md`

**Interfaces:**
- Consumes: 14 file đã move trong `docs/30-research/`; 7 ADR trong `docs/90-decisions/`;
  `docs/99-archive/MT5_EA_Lab_V3/research/GITHUB_RESEARCH_PROCESS.md`;
  `docs/99-archive/MT5_EA_Lab_V2/GITHUB_AUDIT.md`.
- Produces: `LINK_MAP.md` là hợp đồng cho Task 10.

**Steps**

1. `docs/30-research/README.md` (≤40 dòng): bảng 16 file (14 reference + `ai-integration.md` +
   `open-source-research.md`) + `indicators/` (8 file), mỗi dòng 1 câu mô tả.

2. `docs/30-research/open-source-research.md` (150–400 dòng), đúng 4 mục:
   1. Quy trình 5 bước tìm repo tham chiếu (search → đọc license → đọc kiến trúc → chạy thử →
      ghi quyết định).
   2. Tiêu chí chấm: license rõ ràng, còn maintain, không look-ahead/repaint, có test, kích thước
      đọc được.
   3. Bài học từ audit V2: 3–5 bài học cụ thể (không chép nguyên bảng).
   4. Quy tắc: không copy code không rõ license; ghi nguồn vào ADR/PROGRESS.

3. `docs/90-decisions/README.md` (≤40 dòng): bảng 8 ADR — số | tiêu đề | trạng thái | 1 câu.
   Trạng thái đọc từ dòng `**Trạng thái:**` của từng file, **không** tự suy đoán.

4. `docs/90-decisions/0008-docs-information-architecture.md` theo đúng khuôn ADR hiện có:

```markdown
# ADR 0008 — Kiến trúc thông tin tài liệu: một cây theo mục đích, một điểm vào

- **Ngày:** 2026-11-03
- **Trạng thái:** Accepted (chủ dự án duyệt 2026-11-03)
- **Liên quan:** ADR 0001; `docs/PROGRESS.md` §53 (v1→v2), §70

## Bối cảnh
Ba bộ tài liệu chồng nhau (V1/V2/V3), ba file cùng nhận là "điểm vào duy nhất", 119/340 link chết,
5 EA 5 kiểu input.

## Quyết định
1. `docs/README.md` là điểm vào duy nhất; mọi tài liệu còn hiệu lực reachable trong ≤2 lần bấm.
2. Cây theo mục đích: `00-start`, `10-bots`, `20-operations`, `30-research`, `90-decisions`, `99-archive`.
3. Mỗi tầng có `README.md` ≤40 dòng làm mục lục cục bộ.
4. `99-archive/` là bất biến; `LINK_MAP.md` ghi ánh xạ cũ → mới.
5. `scripts/check_docs_links.py` là cổng bắt buộc; miễn `PROGRESS.md`, `99-archive/`, `archive/`.
6. `configs/demo/*.json` là nguồn sự thật preset; `.set` là dẫn xuất.

## Hệ quả
- Không tạo "pack v4"; tài liệu mới phải vào cây hiện có.
- Thêm tài liệu = thêm vào README của tầng + `REQUIRED_FILES`.
- Link ngoài repo phải là câu trích dẫn văn bản, không phải link markdown.

## Không thuộc phạm vi
Chuẩn hóa input (phase C), thay đổi logic EA, chạy tester.
```

5. `docs/99-archive/README.md` (≤40 dòng): read-only; vì sao giữ (lịch sử + bằng chứng);
   V1 46 file / V2 20 file / V3 29 file; quy tắc "không sửa, không link từ luồng đọc chính";
   trỏ `LINK_MAP.md`.

6. `docs/99-archive/LINK_MAP.md`: hai bảng.

Bảng A — di chuyển thật (chép từ spec §7): 14 dòng `reference/*.md` giữ tên, 8 dòng `indicators/*.md`
giữ tên, 6 dòng `guides/*`, 4 `.set`, 7 ADR, 3 thư mục V1/V2/V3.

Bảng B — link cũ không tồn tại (chép từ spec §7.1): 15 dòng `v2/*` + 2 dòng `archive/v1/*`,
`archive/planning-inputs/*`, kèm ghi chú: `v2/` và `archive/v1/` **chưa từng tồn tại** trong cây
hiện tại (di sản đổi tên), nên ánh xạ theo nội dung chứ không theo đường dẫn.

7. Commit:

```powershell
git add docs/30-research docs/90-decisions docs/99-archive
git commit -m "docs: add research, decisions and archive indexes"
```

**Verification:** 6 file tồn tại; `LINK_MAP.md` có đủ 2 bảng; ADR 0008 có 4 mục
(Bối cảnh / Quyết định / Hệ quả / Không thuộc phạm vi).

---

## Task 9 — Viết lại tầng vào: `docs/README.md`, `00-start/`, `README.md` gốc

**Files:**
- Modify: `docs/README.md` (viết lại hoàn toàn)
- Create: `docs/00-start/README.md`
- Modify: `docs/00-start/roadmap.md` (đã move từ `MASTER_ROADMAP.md`, viết lại)
- Create: `docs/00-start/glossary.md`
- Modify: `README.md` gốc (viết lại, ≤60 dòng)

**Interfaces:**
- Consumes: toàn bộ trang của Task 5–8.
- Produces: entry point cho người đọc và cho Task 10 (link rewrite không đụng các file này).

**Steps**

1. `docs/README.md` (≤120 dòng), đúng 6 mục:
   1. Tiêu đề + 2 câu phạm vi + hộp ranh giới (demo/tester only, real forbidden, 5 EA demo).
   2. **Đọc theo thứ tự** — bảng 6 dòng: `00-start/README.md`, `10-bots/README.md`,
      `20-operations/README.md`, `30-research/README.md`, `90-decisions/README.md`,
      `99-archive/README.md`.
   3. **Tôi muốn…** — 6 dòng: chạy bot lần đầu → `00-start/first-run.md`; cấu hình input →
      `10-bots/input-convention.md`; chạy demo → `20-operations/demo-execution.md`;
      bot không vào lệnh → `20-operations/troubleshooting.md`; đổi preset →
      `20-operations/presets.md`; hiểu thuật ngữ → `00-start/glossary.md`.
   4. **5 bot demo** — bảng: bot | magic | preset | trang | nhãn.
   5. **Trạng thái cổng** — bảng 4 lệnh + kỳ vọng dạng `0 broken` / `0 fail` / `0 errors, 0 warnings`.
      Chưa biết số `external`/`checked`/`passed` ở thời điểm này, nên **không** bịa; Task 12 điền số thật.
   6. **Quy ước** — ngôn ngữ, 9 nhãn (trỏ glossary), `99-archive/` read-only.

2. `docs/00-start/README.md` (≤30 dòng): thứ tự đọc 3 file + mỗi file trả lời câu hỏi gì.

3. Viết lại `docs/00-start/roadmap.md` (150–400 dòng), đúng 4 mục:
   1. **Trạng thái hiện tại theo mảng** — bảng: tài liệu, 5 EA demo, 6 indicator validator,
      Python/sim, ML/ONNX, demo execution, cổng — mỗi dòng 1 nhãn + 1 câu.
   2. **Đã xong / đang dở / chưa làm** — 3 bảng ngắn.
   3. **3 phase tiếp theo:** A = tái cấu trúc tài liệu (task này, xong khi cổng xanh);
      B = chuẩn hóa input theo `input-convention.md` (5 EA, preset, validator);
      C = suite demo XAUUSD (5 bot × tester + chart demo) → sau đó mới tới bot AI.
   4. **Lịch sử:** trỏ bằng **text path** tới roadmap V1/V2/V3 trong `99-archive/`.

4. `docs/00-start/glossary.md` (150–300 dòng): 30 thuật ngữ, mỗi thuật ngữ 1–2 câu.
   Bắt buộc có: EA, magic number, preset JSON, `.set`, gate, ADR, `ExecBroker`, `ExecGuard`,
   kill switch, dry-run, state file, journal CSV, `config_hash`, spread (points), SL, TP,
   R-multiple, trailing stop, break-even, bounded grid, bounded DCA, basket, runner, PSAR,
   ONNX, parity, warm-up, reason code, và **9 nhãn trạng thái** (6 hợp đồng + 3 phụ).

5. Viết lại `README.md` gốc (≤60 dòng), đúng 4 mục:
   1. 1 đoạn mô tả repo.
   2. Bảng 5 bot demo (bot | magic | preset | nhãn).
   3. Link tới `docs/README.md` (dùng đường dẫn tương đối `docs/README.md`).
   4. Ranh giới an toàn 3 dòng + 1 dòng "không có roadmap ở đây, xem `docs/00-start/roadmap.md`".

   **Xóa** khỏi README gốc: roadmap dài, bảng phase, mọi link tới `docs/v2/`, `docs/reference/`,
   `docs/indicators/`, `docs/guides/`.

6. Commit:

```powershell
git add README.md docs/README.md docs/00-start
git commit -m "docs: rewrite entry points and roadmap"
```

**Verification:** `README.md` ≤60 dòng; `docs/README.md` ≤120 dòng và trỏ đúng 6 thư mục tầng;
`00-start/` có 4 file.

---

## Task 10 — Viết lại link toàn repo + nối checker vào cổng

**Files:**
- Create (tạm, không commit): `C:\Users\tuanmjnh\AppData\Local\Temp\opencode\rewrite_links.py`
- Modify: mọi `.md` còn link cũ (danh sách do script in ra)
- Modify: `scripts/validate-project.py` (nối `check_docs_links` + thêm 12 file IA vào `REQUIRED_FILES`)

**Interfaces:**
- Consumes: `check_links` từ Task 4; `LINK_MAP.md` từ Task 8.
- Produces: `python scripts\check_docs_links.py` → `broken=0`; `validate-project.py` → `checks=15 fail=0`.

**Baseline đo được bằng chính checker này (2026-11-03, trước khi sửa):**
`broken=131 external=22 checked=413`. Trong 131 link chết: **86** do `FILE_MAP`/`DIR_MAP`/`PHANTOM`
xử lý tự động; **31** là `file:` URI (bước 3 sửa tay); **14** còn lại nằm trong file mà Task 9 viết
lại hoặc trong `99-archive/` đã miễn. Nếu sau bước 2 mà `broken` còn khoảng 45, đó là bình thường —
đừng hoảng; cứ sửa theo danh sách `BROKEN:` còn lại.

**Steps**

1. Viết script một lần (nguyên văn) vào temp:

```python
"""One-shot link rewriter for the tm-fx docs reorg. Not committed."""

import os
import re
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(r"D:\Applications\tm-fx")

FILE_MAP = {
    "docs/MASTER_ROADMAP.md": "docs/00-start/roadmap.md",
    "docs/guides/beginner-first-run.md": "docs/00-start/first-run.md",
    "docs/guides/ea-anatomy-and-ai.md": "docs/10-bots/ea-anatomy.md",
    "docs/guides/install-and-test.md": "docs/20-operations/install.md",
    "docs/guides/strategy-tester.md": "docs/20-operations/strategy-tester.md",
    "docs/guides/demo-execution.md": "docs/20-operations/demo-execution.md",
    "docs/guides/toolchain.md": "docs/20-operations/toolchain.md",
    "docs/configurations/README.md": "docs/20-operations/presets.md",
    "docs/configurations/dca_demo.set": "docs/20-operations/presets/dca_demo.set",
    "docs/configurations/grid_demo.set": "docs/20-operations/presets/grid_demo.set",
    "docs/configurations/infinite_runner_v2.set": "docs/20-operations/presets/infinite_runner_v2.set",
    "docs/configurations/pa_trendrider_xau.set": "docs/20-operations/presets/pa_trendrider_xau.set",
    # Phantom: docs/archive/ không tồn tại; README của nó là 99-archive/README.md.
    "docs/archive/README.md": "docs/99-archive/README.md",
}

DIR_MAP = {
    "docs/decisions/": "docs/90-decisions/",
    "docs/reference/": "docs/30-research/",
    "docs/indicators/": "docs/30-research/indicators/",
    "docs/MT5_EA_Lab_V1/": "docs/99-archive/MT5_EA_Lab_V1/",
    "docs/MT5_EA_Lab_V2/": "docs/99-archive/MT5_EA_Lab_V2/",
    "docs/MT5_EA_Lab_V3/": "docs/99-archive/MT5_EA_Lab_V3/",
    "docs/archive/v1/": "docs/99-archive/MT5_EA_Lab_V1/",
    "docs/archive/planning-inputs/": "docs/99-archive/MT5_EA_Lab_V1/",
}

PHANTOM = {
    "docs/v2/README.md": "docs/00-start/roadmap.md",
    "docs/v2/ROADMAP.md": "docs/00-start/roadmap.md",
    "docs/v2/RISK_MODEL.md": "docs/30-research/risk.md",
    "docs/v2/EXECUTION_AND_SAFETY.md": "docs/20-operations/demo-execution.md",
    "docs/v2/CONFIGURATION.md": "docs/20-operations/presets.md",
    "docs/v2/TROUBLESHOOTING.md": "docs/20-operations/troubleshooting.md",
    "docs/v2/EVIDENCE.md": "docs/20-operations/evidence.md",
    "docs/v2/TEST_REPORT.md": "docs/20-operations/evidence.md",
    "docs/v2/GITHUB_AUDIT.md": "docs/30-research/open-source-research.md",
    "docs/v2/STRATEGIES/PA_TRENDRIDER_XAU_V1.md": "docs/10-bots/pa-trendrider.md",
    "docs/v2/STRATEGIES/GRID_EA.md": "docs/10-bots/grid.md",
    "docs/v2/STRATEGIES/DCA_EA.md": "docs/10-bots/dca.md",
    "docs/v2/BACKLOG_AI.md": "docs/99-archive/MT5_EA_Lab_V2/BACKLOG_AI.md",
    "docs/v2/DECISIONS_REQUIRED.md": "docs/99-archive/MT5_EA_Lab_V2/DECISIONS_REQUIRED.md",
    "docs/v2/PROMPT_AI_IMPLEMENT.md": "docs/99-archive/MT5_EA_Lab_V2/PROMPT_AI_IMPLEMENT.md",
    "docs/v2/ENVIRONMENT.md": "docs/99-archive/MT5_EA_Lab_V2/ENVIRONMENT.md",
}

PHANTOM_PREFIX = {
    "docs/v2/STRATEGIES/InfiniteRunner_XAU_Upgrade_Pack/": "docs/10-bots/infinite-runner.md",
}

SKIP = {
    "README.md", "docs/README.md", "docs/PROGRESS.md",
    "docs/00-start/README.md", "docs/00-start/roadmap.md", "docs/00-start/glossary.md",
    "docs/10-bots/README.md", "docs/10-bots/input-convention.md", "docs/10-bots/ea-anatomy.md",
    "docs/10-bots/pa-trendrider.md", "docs/10-bots/grid.md", "docs/10-bots/dca.md",
    "docs/10-bots/infinite-runner.md", "docs/10-bots/wonderwhales.md",
    "docs/20-operations/README.md", "docs/20-operations/presets.md",
    "docs/20-operations/troubleshooting.md", "docs/20-operations/evidence.md",
    "docs/30-research/README.md", "docs/30-research/ai-integration.md",
    "docs/30-research/open-source-research.md",
    "docs/90-decisions/README.md", "docs/90-decisions/0008-docs-information-architecture.md",
    "docs/99-archive/README.md", "docs/99-archive/LINK_MAP.md",
}

LINK_RE = re.compile(r"(\[[^\]]*\]\()([^)]+)(\))")
NEW_TO_OLD = {v: k for k, v in FILE_MAP.items()}
DIR_REVERSE = sorted(DIR_MAP.items(), key=lambda kv: len(kv[1]), reverse=True)


def old_location(new_rel: str) -> str:
    if new_rel in NEW_TO_OLD:
        return NEW_TO_OLD[new_rel]
    for src, dst in DIR_REVERSE:
        if new_rel.startswith(dst):
            return src + new_rel[len(dst):]
    return new_rel


def map_old(old: str):
    if old in FILE_MAP:
        return FILE_MAP[old]
    if old in PHANTOM:
        return PHANTOM[old]
    for src, dst in PHANTOM_PREFIX.items():
        if old.startswith(src):
            return dst
    for src, dst in DIR_MAP.items():
        if old.startswith(src):
            return dst + old[len(src):]
    # Link có thể trỏ tới thư mục mà không có dấu "/" cuối (ví dụ ../archive/v1).
    if old + "/" in DIR_MAP:
        return DIR_MAP[old + "/"].rstrip("/")
    return None


def rewrite_line(line: str, rel_new: str, old_rel: str):
    def repl(match):
        prefix, target, suffix = match.groups()
        t = target.strip()
        if t.startswith(("#", "http://", "https://", "mailto:", "tel:", "file:")):
            return match.group(0)
        anchor = ""
        if "#" in t:
            t, anchor = t.split("#", 1)
            anchor = "#" + anchor
        t = unquote(t)
        if t.startswith("/"):
            old_abs = t.lstrip("/")
        else:
            old_abs = os.path.normpath(os.path.join(os.path.dirname(old_rel), t)).replace("\\", "/")
        new_abs = map_old(old_abs)
        if new_abs is None:
            return match.group(0)
        rel = os.path.relpath(new_abs, os.path.dirname(rel_new)).replace("\\", "/")
        return f"{prefix}{rel}{anchor}{suffix}"

    return LINK_RE.sub(repl, line)


def main() -> None:
    changed = 0
    for path in sorted(ROOT.rglob("*.md")):
        rel = path.relative_to(ROOT).as_posix()
        if rel in SKIP or rel.startswith(("docs/99-archive/", "archive/", ".git/", ".venv/")):
            continue
        old_rel = old_location(rel)
        text = path.read_text(encoding="utf-8")
        out, in_fence = [], False
        for line in text.splitlines(keepends=True):
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                out.append(line)
                continue
            out.append(line if in_fence else rewrite_line(line, rel, old_rel))
        new_text = "".join(out)
        if new_text != text:
            path.write_text(new_text, encoding="utf-8")
            changed += 1
            print(f"rewritten: {rel}")
    print(f"files rewritten: {changed}")


if __name__ == "__main__":
    main()
```

2. Chạy:

```powershell
.\.venv\Scripts\python.exe C:\Users\tuanmjnh\AppData\Local\Temp\opencode\rewrite_links.py
```

3. Sửa tay các link ngoài repo thành trích dẫn văn bản. Quy tắc:
   `[T](file:///D:/...)` và `[T](../../tm-trading/...)` → thay bằng `` `D:/...` `` (giữ nguyên đường
   dẫn gốc trong backtick). Số lượng lớn nhất ở `docs/30-research/indicators/wonderwhales.md` (19).
   **Ngoại lệ:** `file:///docs/...` trỏ vào file **trong repo** phải thành link tương đối thật, không
   phải backtick. Bốn link như vậy nằm trong `docs/20-operations/presets.md` và đã được Task 7 viết
   lại; nếu còn chỗ khác thì tính đường dẫn tương đối từ file chứa nó.

```powershell
.\.venv\Scripts\python.exe scripts\check_docs_links.py
```

Lặp lại: sửa từng `BROKEN:` cho tới khi `broken=0`. **Không** sửa `docs/PROGRESS.md` hay
`docs/99-archive/` (đã miễn).

4. Sửa path trong code-span của `mt5/README.md` (không phải link markdown nên script trên bỏ qua):

```powershell
$p = 'mt5\README.md'
$t = Get-Content $p -Raw -Encoding UTF8
$t = $t -replace 'docs/reference/', 'docs/30-research/'
$t = $t -replace 'docs/indicators/', 'docs/30-research/indicators/'
$t = $t -replace 'docs/guides/install-and-test\.md', 'docs/20-operations/install.md'
$t = $t -replace 'docs/guides/strategy-tester\.md', 'docs/20-operations/strategy-tester.md'
$t = $t -replace 'docs/guides/toolchain\.md', 'docs/20-operations/toolchain.md'
$t = $t -replace 'docs/guides/demo-execution\.md', 'docs/20-operations/demo-execution.md'
$t = $t -replace 'docs/guides/beginner-first-run\.md', 'docs/00-start/first-run.md'
$t = $t -replace 'docs/MASTER_ROADMAP\.md', 'docs/00-start/roadmap.md'
[IO.File]::WriteAllText((Resolve-Path $p), $t, (New-Object Text.UTF8Encoding($false)))
```

5. Nối checker vào `scripts/validate-project.py`. Thêm ngay sau khối `REPO_ROOT = ...` (dòng ~35):

```python
SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from check_docs_links import check_links as check_docs_links  # noqa: E402
```

Trong `main()`, ngay sau `report("layout", check_layout(root))`:

```python
    report("docs links", check_docs_links(root)[0])
```

6. Thêm 12 file IA vào `REQUIRED_FILES` (cuối tuple, trước dòng `)` của tuple):

```python
    "docs/00-start/README.md",
    "docs/10-bots/README.md",
    "docs/10-bots/input-convention.md",
    "docs/20-operations/README.md",
    "docs/20-operations/presets.md",
    "docs/20-operations/troubleshooting.md",
    "docs/20-operations/evidence.md",
    "docs/30-research/README.md",
    "docs/90-decisions/README.md",
    "docs/90-decisions/0008-docs-information-architecture.md",
    "docs/99-archive/README.md",
    "docs/99-archive/LINK_MAP.md",
```

7. Chạy cổng:

```powershell
.\.venv\Scripts\python.exe scripts\check_docs_links.py
.\.venv\Scripts\python.exe scripts\validate-project.py
.\.venv\Scripts\python.exe -m pytest -q
```

Kỳ vọng: `SUMMARY: broken=0 external=N checked=M`; `SUMMARY: checks=15 fail=0`; `436 passed`.

8. Commit:

```powershell
git add -A
git commit -m "docs: rewrite links and gate markdown links"
```

**Verification:** `broken=0`; `checks=15 fail=0`; `436 passed`; `git status --porcelain` rỗng.
Nếu còn `BROKEN:` trong `docs/PROGRESS.md` hay `99-archive/` → đó là lỗi cấu hình exemption,
không phải lỗi link: kiểm tra `EXEMPT_DIRS`/`EXEMPT_FILES`.

---

## Task 11 — Cập nhật path trong comment MQL5 + tham chiếu Python, rồi compile

**Files:**
- Modify: comment/`#property description` trong `mt5/**/*.mq5`, `mt5/**/*.mqh`
  (chỉ chuỗi đường dẫn; **không** đổi code)
- Modify: `requirements.txt` (dòng 2), `python/tests/test_dca_vectors.py` (docstring dòng 8),
  `scripts/compare_pine_exports.py` (docstring dòng 9)

**Interfaces:**
- Consumes: cây mới từ Task 3.
- Produces: không còn đường dẫn docs cũ trong source; build/deploy vẫn 0/0.

**Steps**

1. Liệt kê các dòng cần sửa:

```powershell
git grep -n -E 'docs[/\\](decisions|guides|reference|indicators|configurations|MASTER_ROADMAP)' -- 'mt5/*.mq5' 'mt5/*.mqh' 'mt5/**/*.mq5' 'mt5/**/*.mqh'
```

2. Thay thế hàng loạt (chỉ văn bản, không đổi logic):

```powershell
Get-ChildItem mt5 -Recurse -Include *.mq5,*.mqh | ForEach-Object {
  $p = $_.FullName
  $t = Get-Content $p -Raw -Encoding UTF8
  $o = $t
  $t = $t -replace 'docs/decisions/', 'docs/90-decisions/'
  $t = $t -replace 'docs/indicators/', 'docs/30-research/indicators/'
  $t = $t -replace 'docs/reference/', 'docs/30-research/'
  $t = $t -replace 'docs/guides/install-and-test\.md', 'docs/20-operations/install.md'
  $t = $t -replace 'docs/guides/strategy-tester\.md', 'docs/20-operations/strategy-tester.md'
  $t = $t -replace 'docs/guides/demo-execution\.md', 'docs/20-operations/demo-execution.md'
  $t = $t -replace 'docs/guides/toolchain\.md', 'docs/20-operations/toolchain.md'
  $t = $t -replace 'docs/guides/beginner-first-run\.md', 'docs/00-start/first-run.md'
  $t = $t -replace 'docs/MASTER_ROADMAP\.md', 'docs/00-start/roadmap.md'
  $t = $t -replace 'docs/configurations/', 'docs/20-operations/presets/'
  if ($t -ne $o) {
    [IO.File]::WriteAllText($p, $t, (New-Object Text.UTF8Encoding($false)))
    "updated: $($_.FullName.Replace('D:\Applications\tm-fx\',''))"
  }
}
```

3. Sửa 3 tham chiếu Python:

```powershell
$edits = @{
  'requirements.txt' = @(@('docs/reference/simulation.md','docs/30-research/simulation.md'))
  'python\tests\test_dca_vectors.py' = @(@('docs/reference/simulation.md','docs/30-research/simulation.md'))
  'scripts\compare_pine_exports.py' = @(@('docs/indicators/wonderwhales.md','docs/30-research/indicators/wonderwhales.md'))
}
foreach ($file in $edits.Keys) {
  $t = Get-Content $file -Raw -Encoding UTF8
  foreach ($pair in $edits[$file]) { $t = $t.Replace($pair[0], $pair[1]) }
  [IO.File]::WriteAllText((Resolve-Path $file), $t, (New-Object Text.UTF8Encoding($false)))
}
```

4. Xác nhận không còn path cũ ngoài vùng bất biến:

```powershell
git grep -n -E 'docs[/\\](decisions|guides|reference|indicators|configurations|MASTER_ROADMAP)' -- . ':!docs/PROGRESS.md' ':!docs/99-archive/**' ':!archive/**'
```

Kỳ vọng: **rỗng**. `docs/PROGRESS.md` và `docs/99-archive/` được miễn vì là lịch sử bất biến;
nếu chúng xuất hiện thì pathspec loại trừ bị sai, không phải còn sót path.

5. Đóng MT5, build + deploy:

```powershell
.\scripts\deploy_pineport.ps1 -Apply -Force
```

Kỳ vọng: `DEPLOY_OK`, **0 errors / 0 warnings**. Nếu có warning → sửa nguyên nhân, không bỏ qua.

6. Chạy lại pytest + validator:

```powershell
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\python.exe scripts\validate-project.py
```

Kỳ vọng: `436 passed`; `checks=15 fail=0`.

7. Commit:

```powershell
git add -A
git commit -m "chore: update doc paths in MQL5 comments and python refs"
```

**Verification:** compile 0/0; `git diff HEAD~1 -- 'mt5/**'` chỉ có comment/`#property` thay đổi
(không có dòng `input` hay logic).

---

## Task 12 — Cổng cuối + điền số thật + ghi `PROGRESS.md` §70

**Files:**
- Modify: `docs/README.md` (chỉ bảng "Trạng thái cổng")
- Modify: `docs/PROGRESS.md` (append §70)

**Interfaces:**
- Consumes: mọi task trước.
- Produces: bằng chứng hoàn tất; mốc lịch sử cho phase C.

**Steps**

1. Chạy toàn bộ cổng, lưu output thật:

```powershell
.\.venv\Scripts\python.exe scripts\check_docs_links.py
.\.venv\Scripts\python.exe scripts\validate-project.py
.\.venv\Scripts\python.exe scripts\validate_demo_execution.py
foreach ($f in 'validate_pineport.py','validate_longkaco.py','validate_pamtf.py','validate_tmfz.py','validate_tmind2.py','validate_tmxau2.py') {
  .\.venv\Scripts\python.exe "scripts\$f"
}
.\.venv\Scripts\python.exe -m pytest -q
git status --porcelain
```

Kỳ vọng: `broken=0`; `checks=15 fail=0`; `checks=13 fail=0`;
32/29/36/34/44/31 pass 0 fail; `436 passed`; `git status` rỗng.

2. Điền số thật vào bảng "Trạng thái cổng" của `docs/README.md`: `broken=<thật>`,
   `checked=<thật>`, `external=<thật>`, `checks=15 fail=0`, `checks=13 fail=0`,
   `436 passed`, `0 errors / 0 warnings`. Không dùng số ước lượng.

3. Kiểm tra thủ công (ghi kết quả vào PROGRESS):
   - Từ `docs/README.md` bấm tới được 5 trang bot, 4 tài liệu vận hành, 8 ADR, `99-archive/README.md`.
   - Mỗi trang bot hiển thị đúng magic + preset + nhãn.
   - `docs/99-archive/LINK_MAP.md` mở được và có 2 bảng.
   - `README.md` gốc ≤60 dòng, không còn link `v2/`.

4. Append vào cuối `docs/PROGRESS.md`:

```markdown
## 70. Tái cấu trúc tài liệu theo mục đích + cổng chặn link chết — 2026-11-03

### 70.1 Việc đã làm

- Chuyển toàn bộ tài liệu còn hiệu lực sang cây `00-start` / `10-bots` / `20-operations` /
  `30-research` / `90-decisions` / `99-archive` bằng `git mv` (giữ lịch sử).
- Viết mới 5 trang bot, `input-convention.md` (hợp đồng phase C), `troubleshooting.md`,
  `evidence.md`, `open-source-research.md`, `glossary.md`, ADR 0008, `LINK_MAP.md`.
- Viết lại `docs/README.md`, `README.md` gốc, `00-start/roadmap.md`, `20-operations/presets.md`.
- Thêm `scripts/check_docs_links.py` + 6 test; nối vào `validate-project.py`.
- Cô lập `InfiniteRunnerXAUV3DemoEA.mq5` sang `archive/wip/2026-11-03_InfiniteRunnerXAUV3/`.
- Dọn rác gốc (`reportsbuild-allsuite/`, `pip-*`, `pytest-of-*`, `node_modules/`, log).

### 70.2 Cổng khi kết thúc

- `check_docs_links.py` → `broken=0 external=<N> checked=<M>`.
- `validate-project.py` → `checks=15 fail=0`.
- `validate_demo_execution.py` → `checks=13 fail=0`.
- 6 validator indicator → 32/29/36/34/44/31 pass, 0 fail.
- `pytest` → `436 passed`.
- `deploy_pineport.ps1 -Apply -Force` → `DEPLOY_OK`, 0 errors / 0 warnings.

### 70.3 Không đổi

- Không sửa `input`/logic EA, không sửa `configs/demo/*.json`, không nâng nhãn trạng thái nào.
- `99-archive/` và `PROGRESS.md` là bất biến; link bên trong không bị viết lại.

### 70.4 Còn mở (trung thực)

- Dọn vị thế lạc magic 25006001 trên chart demo: **chưa xác nhận đã đóng**; state file
  `MQL5\Files\infinite_runner_demo_state.csv` **chưa xóa**.
- Chạy lại tester IR để lấy bằng chứng sau chẩn đoán "vị thế lạc chiếm slot": **`NOT_RUN`**.
- Nhãn lợi nhuận của cả 5 bot demo vẫn là `UNPROVEN`; không có kết luận mới về hiệu quả chiến lược.
```

Điền `<N>`, `<M>` bằng số thật từ bước 1. **Không** ghi số ước lượng.

5. Commit:

```powershell
git add docs/README.md docs/PROGRESS.md
git commit -m "docs: record docs reorg in PROGRESS"
```

**Verification:** `git log --oneline -13` có đủ 13 commit của kế hoạch; `git status` rỗng.

---

## 3. Review Focus — chỗ dễ sai nhất

Khi review diff, kiểm 6 điểm sau:

1. **Case-exact path.** Windows che lỗi hoa/thường. `_resolves_case_exact` phải duyệt từng component
   bằng `os.scandir` và so khớp `entries.get(part)`; không dùng `Path.exists()` một mình.
2. **Percent-encoding.** `%20` phải được `unquote` **trước** khi kiểm tồn tại; nếu không,
   `b%20c.md` bị báo chết sai. Test `test_valid_links_are_counted_and_code_fences_are_ignored`
   bắt đúng điểm này.
3. **Target là thư mục.** Link tới `docs/99-archive/MT5_EA_Lab_V2/` phải hợp lệ; checker dùng
   `exists`-style (component walk) chứ không `is_file()`.
4. **Exemption đúng phạm vi.** `docs/PROGRESS.md`, `docs/99-archive/**`, `archive/**` không được
   sinh issue. `archive` ở gốc repo là lịch sử, không phải tài liệu sống.
5. **Không lọt link ngoài repo.** `../../tm-trading/...` resolve ra ngoài `root` → `external += 1`,
   không fail; nhưng Task 10 vẫn phải đổi chúng thành backtick (yêu cầu của spec).
6. **Validator path drift.** Sau Task 3, chạy `Select-String -Path scripts\*.py,scripts\*.ps1 -Pattern 'docs[\\/](guides|reference|indicators|decisions|configurations|MASTER_ROADMAP)'` — kết quả phải rỗng.
   Đây là thứ dễ bỏ sót nhất vì cổng vẫn xanh khi script trỏ sai.

Ngoài ra:
- `docs/30-research/parity.md` và `docs/30-research/indicators/parity.md` là **hai file khác nhau**;
  đừng gộp.
- `presets.md` phải nói thật là `.set` chưa được kiểm tự động.
- Không file nào trong `99-archive/` bị sửa nội dung (`git diff --stat` chỉ được thấy rename).

---

## 4. Rollback

| Task | Cách rollback |
|---|---|
| T0 | `git reset --soft HEAD~1` (giữ working tree) nếu cần chia lại baseline |
| T1 | `git revert HEAD` rồi `Move-Item` file về `mt5/Experts/` |
| T2 | `git revert HEAD` (file rác sinh lại được) |
| T3 | `git revert HEAD` — `git mv` được đảo nguyên trạng, nội dung chưa đổi |
| T4 | `git revert HEAD` |
| T5–T9 | `git revert HEAD` từng commit; các trang mới biến mất, trang cũ trở lại |
| T10 | `git revert HEAD` — link trở về trạng thái trước, checker bị tháo khỏi gate |
| T11 | `git revert HEAD` — comment trở lại; chạy lại `deploy_pineport.ps1 -Apply -Force` |
| T12 | `git revert HEAD` — chỉ mất mục PROGRESS |

Không bao giờ `git reset --hard` khi working tree còn việc chưa commit.

---

## 5. Definition of Done

- [ ] `python scripts\check_docs_links.py` → `broken=0`.
- [ ] `python scripts\validate-project.py` → `checks=15 fail=0`.
- [ ] `python scripts\validate_demo_execution.py` → `checks=13 fail=0`.
- [ ] 6 validator indicator → pass, 0 fail.
- [ ] `python -m pytest -q` → `436 passed`.
- [ ] `deploy_pineport.ps1 -Apply -Force` → `DEPLOY_OK`, 0 errors / 0 warnings.
- [ ] `git status --porcelain` rỗng; 13 commit mới.
- [ ] `docs/README.md` là điểm vào duy nhất; `README.md` gốc ≤60 dòng.
- [ ] 5 trang bot tồn tại, mỗi trang ≤200 dòng, đúng magic + preset + nhãn.
- [ ] `input-convention.md` có 6 nhóm, 4 bảng của §9, bảng gap.
- [ ] `99-archive/` không bị sửa nội dung (chỉ rename).
- [ ] `PROGRESS.md` §70 đã append, số liệu là số thật.
- [ ] Không có thay đổi nào trong `mt5/**` ngoài comment/`#property`.
- [ ] Không có thay đổi nào trong `configs/demo/*.json`, `configs/sim/*.json`.
