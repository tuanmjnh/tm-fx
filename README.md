# MT5 EA & AI Lab

Repository nghiên cứu độc lập để phát triển EA MQL5, pipeline dữ liệu/ML bằng Python và quy trình
backtest có thể tái lập cho MetaTrader 5.

- **Trạng thái:** Phase 0 — Khởi tạo và kiểm kê môi trường (**DONE**, 2026-10-27).
- **Phạm vi hiện tại:** signal-only. Không gửi lệnh giao dịch thật, không kết nối tài khoản môi giới,
  không lưu thông tin đăng nhập.
- **Tài liệu nguồn:** [`docs/ROADMAP_MT5_EA_AI_LAB.md`](docs/ROADMAP_MT5_EA_AI_LAB.md) và
  [`docs/PROMPT_AI_IMPLEMENT_ROADMAP.md`](docs/PROMPT_AI_IMPLEMENT_ROADMAP.md).

> Kết quả backtest/mô phỏng không đảm bảo lợi nhuận trong tương lai. Mọi con số phải ghi rõ dữ liệu,
> khoảng thời gian, giả định chi phí và trạng thái dữ liệu (thực, sample hay synthetic).

## Yêu cầu môi trường

| Thành phần | Yêu cầu | Đã xác minh trong Phase 0 |
|---|---|---|
| OS | Windows 10/11 64-bit | Windows 10.0.19045.6456 |
| Python | 3.11 64-bit | 3.11.9 (64-bit) |
| Git | 2.x | 2.53.0.windows.3 |
| MT5 + MetaEditor | Bản cài chính thức | MT5 5.0.0.6249 (bản EXNESS), có `MetaEditor64.exe`, `metatester64.exe` |

Chi tiết kiểm kê, trạng thái từng mục và các bước xác minh thủ công còn lại:
[`docs/environment.md`](docs/environment.md).

## Thiết lập môi trường (PowerShell)

```powershell
# Từ thư mục gốc repository
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1

# venv dùng pip đi kèm (pip 24.0); nâng cấp pip là tùy chọn
pip install -r requirements.txt

# Chạy kiểm thử
python -m pytest
```

Nếu PowerShell chặn script kích hoạt, dùng trực tiếp interpreter của venv thay vì đổi chính sách
thực thi toàn hệ thống:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m pytest
```

## Cấu trúc repository

```text
tm-fx/                             # tên thư mục hiện tại; nội dung theo roadmap "mt5-ea-ai-lab"
├── README.md
├── requirements.txt
├── pyproject.toml                 # cấu hình pytest; chưa đóng gói package
├── configs/                       # ví dụ cấu hình (chưa có loader)
├── docs/
│   ├── ROADMAP_MT5_EA_AI_LAB.md
│   ├── PROMPT_AI_IMPLEMENT_ROADMAP.md
│   ├── architecture.md
│   ├── environment.md
│   ├── risk-and-limitations.md
│   ├── decisions/
│   └── phase-reports/
├── mt5/
│   ├── Experts/                   # EA MQL5 (Phase 1)
│   └── Include/                   # Indicators/SignalEngine/Logger (Phase 2)
├── python/
│   ├── src/mt5_ea_ai_lab/         # package skeleton, chưa có logic nghiệp vụ
│   └── tests/                     # smoke tests Phase 0
├── datasets/{raw,processed,samples}/
├── models/{candidates/,registry.json}
├── experiments/                   # metadata/output local (Phase 6)
├── reports/                       # báo cáo sinh ra (Phase 4+)
└── scripts/                       # CLI (Phase 3–5)
```

Các thư mục `data/`, `validation/`, `features/`, `labels/`, `signals/`, `backtest/`, `models/`,
`evaluation/`, `reporting/`, `experiment_store/` hiện chỉ có `__init__.py` mô tả phạm vi. Chưa có
logic xử lý dữ liệu, tín hiệu hay backtest.

## Cấu hình mẫu

- [`configs/data.example.yaml`](configs/data.example.yaml)
- [`configs/strategy.example.yaml`](configs/strategy.example.yaml)
- [`configs/experiment.example.yaml`](configs/experiment.example.yaml)

Đây là tài liệu mẫu, **chưa có loader/validator** trong Phase 0. Mọi giá trị (symbol, timeframe, chi phí)
là placeholder, không phải kết quả thị trường.

## Lệnh dự kiến (chưa khả dụng)

Các lệnh dưới đây thuộc phase sau và **chưa chạy được** cho đến khi file tương ứng được triển khai:

```powershell
# Phase 3
python scripts/validate_dataset.py --input datasets/samples/example.csv

# Phase 4
python scripts/run_backtest.py --config configs/experiment.example.yaml

# Phase 5
python scripts/compare_signals.py --help
```

## An toàn và giới hạn

- Không có `OrderSend`, `CTrade.Buy`, `CTrade.Sell` hoặc đường thực thi lệnh nào trong repository.
- Không commit `.env`, mật khẩu, token, `accounts.dat`, `servers.dat` hay dữ liệu tài khoản.
- Dữ liệu lớn, model artifact, log và output thí nghiệm bị loại khỏi Git (xem `.gitignore`).
- Không kết nối Exness hay bất kỳ tài khoản môi giới nào.

Danh sách rủi ro đầy đủ: [`docs/risk-and-limitations.md`](docs/risk-and-limitations.md).
Báo cáo Phase 0: [`docs/phase-reports/phase-0.md`](docs/phase-reports/phase-0.md).
