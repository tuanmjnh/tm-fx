# Báo cáo Phase 0 — Khởi tạo và kiểm kê môi trường

- **Ngày:** 2026-10-27
- **Trạng thái:** DONE
- **Phạm vi:** chỉ Phase 0; không triển khai EA, signal engine, data pipeline hay backtest.

## 1. Tóm tắt

Repository ban đầu chỉ có `docs/ROADMAP_MT5_EA_AI_LAB.md` và `docs/PROMPT_AI_IMPLEMENT_ROADMAP.md`,
không phải Git repository, không có code hay thay đổi chưa commit của người dùng. Phase 0 đã:

- Kiểm kê OS, Python, Git, MT5/MetaEditor và các package Python liên quan (chỉ đọc, không cài hệ thống).
- Tạo skeleton repository theo roadmap, giữ tách biệt data/validation/features/signals/backtest/...
- Tạo tài liệu kiến trúc, rủi ro, kiểm kê môi trường và ADR baseline.
- Tạo `.gitignore` loại trừ venv, secret, dữ liệu lớn, model artifact, log, output thí nghiệm.
- Tạo `.venv` Python 3.11.9, cài dependency đã pin và chạy smoke test thật.
- Khởi tạo Git trên nhánh `main`, **chưa commit**, chưa cấu hình remote.

Không có secret, thông tin tài khoản hay code gửi lệnh giao dịch trong repository.

## 2. File đã tạo

| Nhóm | File |
|---|---|
| Root | `README.md`, `.gitignore`, `requirements.txt`, `pyproject.toml` |
| Config mẫu | `configs/data.example.yaml`, `configs/strategy.example.yaml`, `configs/experiment.example.yaml` |
| Tài liệu | `docs/architecture.md`, `docs/environment.md`, `docs/risk-and-limitations.md`, `docs/decisions/0001-project-baseline.md`, `docs/phase-reports/phase-0.md` |
| Python package | `python/src/mt5_ea_ai_lab/__init__.py` và `__init__.py` cho 10 subpackage: `data`, `validation`, `features`, `labels`, `signals`, `backtest`, `models`, `evaluation`, `reporting`, `experiment_store` |
| Test | `python/tests/test_package_smoke.py` |
| Thư mục dữ liệu/model | `datasets/raw/.gitkeep`, `datasets/processed/.gitkeep`, `datasets/samples/README.md`, `models/candidates/.gitkeep`, `models/registry.json` |
| Output local | `experiments/README.md`, `reports/README.md` |
| MQL5/scripts placeholder | `mt5/Experts/.gitkeep`, `mt5/Include/.gitkeep`, `scripts/.gitkeep` |

Không sửa nội dung hai tài liệu roadmap/prompt. Không có file người dùng bị xóa hoặc ghi đè.

## 3. Lệnh và kết quả kiểm thử thực tế

| Lệnh | Kết quả |
|---|---|
| `cmd /c ver` | Windows 10.0.19045.6456 |
| `python --version` | Python 3.11.9 |
| `py -0p` | Chỉ có CPython 3.11 (mặc định) |
| `git --version` | git 2.53.0.windows.3 |
| Kiểm tra `C:\Program Files\MetaTrader 5 EXNESS` | Có `terminal64.exe`, `MetaEditor64.exe`, `metatester64.exe`; version 5.0.0.6249 |
| `py -3.11 -m venv .venv` | Thành công; `.venv` Python 3.11.9 |
| `.venv\Scripts\python.exe -m pip install --upgrade pip` | **Không hoàn tất** sau ~2 phút (tiến trình quay CPU, không output); đã dừng chủ động. Không ảnh hưởng các bước sau. |
| `.venv\Scripts\python.exe -m pip install -r requirements.txt` | Thành công; cài numpy 2.4.6, pandas 2.3.3, scikit-learn 1.9.1, matplotlib 3.11.2, pytest 9.1.1 |
| `.venv\Scripts\python.exe -m pytest` | **11 passed in 0.05–0.07s** |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests` | Exit code 0 |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |
| `git init -b main` | Khởi tạo repo; nhánh `main`; chưa có commit |
| `git status --short --ignored` | `.venv/` bị ignore đúng; các file skeleton untracked |
| Quét secret và execution | Không có secret thật; không có `OrderSend`/`CTrade.Buy`/`CTrade.Sell` trong code |

Cảnh báo ghi nhận: khi import matplotlib, cache mặc định `%LOCALAPPDATA%\matplotlib` không ghi được và
matplotlib tạo cache tạm trong repo. Cache tạm đã được xóa, mẫu `matplotlib-*/` đã thêm vào `.gitignore`;
cách đặt `MPLCONFIGDIR` được ghi trong `docs/environment.md`.

## 4. Xác minh thủ công còn lại

Phase 0 không có file MQL5 nên **không có compile hay Strategy Tester nào được chạy**. Các bước sau thuộc
Phase 1 hoặc do người dùng quyết định:

1. Kích hoạt venv bằng `.\.venv\Scripts\Activate.ps1` nếu PowerShell cho phép; Phase 0 dùng trực tiếp
   `.venv\Scripts\python.exe` nên chưa kiểm tra Execution Policy.
2. Tùy chọn nâng cấp pip (đã thất bại một lần trong môi trường này; không bắt buộc).
3. Phase 1: sync EA vào `MQL5/Experts` của terminal, compile bằng MetaEditor, chạy Strategy Tester và đọc
   Journal/Experts. Quy trình chi tiết ở `docs/environment.md`, mục 4.
4. Quyết định commit/push và cấu hình remote (Phase 0 không commit).

## 5. Tiêu chí nghiệm thu Phase 0

| Tiêu chí | Kết quả | Ghi chú |
|---|---|---|
| Người khác đọc README biết cách chuẩn bị môi trường và chạy test | Đạt | Lệnh đã chạy thật; có phương án dự phòng khi PowerShell chặn activate |
| Không có bí mật hoặc dữ liệu tài khoản trong Git | Đạt (hiện tại) | Chưa có commit; quét working tree không thấy secret; `.gitignore` chặn `.env`, `accounts.dat`, `servers.dat` |
| Chưa có logic giao dịch thật | Đạt | Không có file `.mq5`/`.mqh`; quét không thấy lệnh execution |
| Skeleton repository + tài liệu + dependency list + checklist môi trường | Đạt | Xem mục 2 và `docs/environment.md` |

**Kết luận:** Phase 0 đạt các tiêu chí nghiệm thu và được đánh dấu `DONE`. Việc compile/tester MQL5 không
thuộc Phase 0; khi sang Phase 1, trạng thái MQL5 sẽ chỉ là `DONE` nếu có kết quả MetaEditor/Strategy Tester thật.

## 6. Hạn chế và rủi ro đã biết

- Thư mục repository là `tm-fx`, không phải `mt5-ea-ai-lab`. Roadmap cho phép điều chỉnh tên thư mục miễn giữ
  phân tách chức năng; cấu trúc bên trong giữ nguyên.
- OS là Windows 10, trong khi roadmap khuyến nghị Windows 11. Chưa thấy hành vi phụ thuộc phiên bản.
- MetaEditor/Strategy Tester mới được xác minh là **hiện diện**, chưa chạy. Terminal ID và thông tin tài khoản
  không được ghi vào repo.
- `requirements.txt` pin top-level dependency; transitive dependency chưa khóa bằng lock file.
- Chưa có CI, chưa có remote, chưa có commit.
- Chưa có dữ liệu lịch sử MT5; chưa kiểm tra symbol/khoảng ngày có sẵn trong terminal.

## 7. Phase tiếp theo đề xuất

Phase 1 — EA signal-only đầu tiên (`LabSignalEA.mq5`, `mt5/README.md`, hướng dẫn sync/compile/tester).
Chưa bắt đầu cho đến khi người dùng yêu cầu.
