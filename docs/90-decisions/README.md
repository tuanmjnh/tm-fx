# Quyết định — ADR

Mọi quyết định thay đổi phạm vi, ranh giới hay kiến trúc của lab được ghi ở đây dưới dạng ADR.

| # | Tiêu đề | Trạng thái | Tóm tắt |
|---|---|---|---|
| [0001](0001-project-baseline.md) | Baseline dự án và môi trường Phase 0 | Accepted | Repo độc lập, Python 3.11 + MT5 5.0.0.6249, MVP signal-only, local-first. |
| [0002](0002-execution-boundary.md) | Ranh giới execution và chạy trên Exness MT5 | Accepted, thay thế một phần bởi ADR 0003 | Không execution trong repo; "chạy trên Exness" = compile/tester offline; cấm live, credential. |
| [0003](0003-demo-execution-scope.md) | Phạm vi execution chỉ tài khoản demo | Accepted; mục 1 và câu "không grid/DCA" đã được thay bởi ADR 0004 | Mở execution demo qua một EA duy nhất + `ExecGuard`/`ExecBroker`; live vẫn cấm. |
| [0004](0004-all-bots-demo-execution.md) | Mọi bot được execution đầy đủ trên tài khoản demo | Accepted (được sửa đổi bởi ADR 0006) | Mỗi chiến lược có EA demo riêng qua `mt5/Include/Exec/*`; grid/DCA bounded được phép. |
| [0005](0005-infiniterunner-xau-demo-bot.md) | InfiniteRunner_XAU trở thành bot demo thứ tư | Accepted (mục 3 preset fail-closed được sửa đổi bởi ADR 0006) | Canonical = `InfiniteRunnerXAUV2DemoEA`; nguồn V1 giữ nguyên bất biến. |
| [0006](0006-demo-default-execution-enabled.md) | Bot demo mặc định bật execution | Accepted | `InpEnableExecution=true` là mặc định; dry-run là override tường minh `false`. |
| [0007](0007-wonderwhales-demo-bot.md) | Wonderwhales trở thành bot demo thứ năm | Accepted | Hai file: `WonderwhalesSimEA` giữ nguyên cho Tester, thêm `WonderwhalesDemoEA` qua guard. |
| [0008](0008-docs-information-architecture.md) | Kiến trúc thông tin tài liệu: một cây theo mục đích, một điểm vào | Accepted (chủ dự án duyệt 2026-11-03) | Cây docs theo mục đích, một điểm vào, `99-archive/` bất biến, link-check là gate. |

Quy tắc: ADR mới thêm vào đây bằng một dòng; trạng thái đọc từ dòng `**Trạng thái:**` của từng file,
không suy đoán. ADR nào sửa ADR khác thì cả hai đều giữ nguyên và ghi rõ quan hệ trong đầu mỗi file.
