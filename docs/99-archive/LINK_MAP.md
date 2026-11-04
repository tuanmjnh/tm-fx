# LINK_MAP — ánh xạ link cũ → mới

Hợp đồng cho việc viết lại link trong toàn bộ tài liệu (bảng A chép từ spec §7, bảng B chép từ spec
§7.1 của `docs/superpowers/specs/2026-11-03-tm-fx-docs-reorg-design.md`). Trước khi thay một link cũ,
tra bảng; nếu không có trong bảng thì **không di chuyển** — và một link không có ở đây cũng không được
suy ra đường dẫn mới.

## Bảng A — di chuyển thật (git mv, giữ tên file)

| Cũ | Mới |
|---|---|
| `docs/MASTER_ROADMAP.md` | `docs/00-start/roadmap.md` (viết lại) |
| `docs/guides/beginner-first-run.md` | `docs/00-start/first-run.md` |
| `docs/guides/ea-anatomy-and-ai.md` | tách: `docs/10-bots/ea-anatomy.md` + `docs/30-research/ai-integration.md` |
| `docs/guides/install-and-test.md` | `docs/20-operations/install.md` |
| `docs/guides/strategy-tester.md` | `docs/20-operations/strategy-tester.md` |
| `docs/guides/demo-execution.md` | `docs/20-operations/demo-execution.md` |
| `docs/guides/toolchain.md` | `docs/20-operations/toolchain.md` |
| `docs/configurations/README.md` | `docs/20-operations/presets.md` (viết lại) |
| `docs/configurations/*.set` (4) | `docs/20-operations/presets/*.set` |
| `docs/decisions/0001…0007` | `docs/90-decisions/` (giữ tên) |
| `docs/reference/*.md` (14) | `docs/30-research/` (giữ tên) |
| `docs/indicators/**` (8) | `docs/30-research/indicators/` (giữ tên) |
| `docs/MT5_EA_Lab_V1/` | `docs/99-archive/MT5_EA_Lab_V1/` |
| `docs/MT5_EA_Lab_V2/` | `docs/99-archive/MT5_EA_Lab_V2/` |
| `docs/MT5_EA_Lab_V3/` | `docs/99-archive/MT5_EA_Lab_V3/` |

Ghi chú: `docs/reference/parity.md` và `docs/indicators/parity.md` là hai tài liệu khác nhau; bản
indicators nằm trong `indicators/` nên không xung đột tên.

## Bảng B — link cũ không tồn tại trong cây hiện tại

Các link `v2/*` và `archive/v1/*` trỏ tới thư mục **chưa từng tồn tại** trong cây hiện tại (di sản
của lần đổi tên `v2/` → `MT5_EA_Lab_V2/`). Không thể map máy móc; ánh xạ theo **nội dung** chứ không
theo đường dẫn. Bảng này phải phủ cả tên cũ (`v2/`, `archive/v1/`) lẫn tên hiện tại
(`MT5_EA_Lab_V2/`).

| Link cũ | Trỏ về |
|---|---|
| `v2/README.md`, `v2/ROADMAP.md` | `00-start/roadmap.md` |
| `v2/RISK_MODEL.md` | `30-research/risk.md` |
| `v2/EXECUTION_AND_SAFETY.md` | `20-operations/demo-execution.md` |
| `v2/CONFIGURATION.md` | `20-operations/presets.md` |
| `v2/TROUBLESHOOTING.md` | `20-operations/troubleshooting.md` |
| `v2/EVIDENCE.md`, `v2/TEST_REPORT.md` | `20-operations/evidence.md` |
| `v2/STRATEGIES/PA_TRENDRIDER_XAU_V1.md` | `10-bots/pa-trendrider.md` |
| `v2/STRATEGIES/GRID_EA.md` | `10-bots/grid.md` |
| `v2/STRATEGIES/DCA_EA.md` | `10-bots/dca.md` |
| `v2/STRATEGIES/InfiniteRunner_XAU_Upgrade_Pack/*` | `10-bots/infinite-runner.md` |
| `v2/GITHUB_AUDIT.md` | `30-research/open-source-research.md` |
| `v2/BACKLOG_AI.md`, `v2/DECISIONS_REQUIRED.md`, `v2/PROMPT_AI_IMPLEMENT.md`, `v2/ENVIRONMENT.md` | `99-archive/MT5_EA_Lab_V2/` (kế hoạch cũ, không chưng cất) |
| `archive/v1/*`, `archive/planning-inputs/*` | `99-archive/MT5_EA_Lab_V1/` (bản gốc lịch sử) |
| `file:///docs/...` | đổi thành đường dẫn tương đối tới file mới tương ứng |
| `file:///D:/...`, `../../tm-trading/...` | câu trích dẫn văn bản, không phải link |
