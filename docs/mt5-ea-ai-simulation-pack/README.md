# MT5 EA Lab — Grid, DCA & Runner (Simulation-Only)

Bộ tài liệu để AI coding agent xây dựng ba EA nghiên cứu chạy trong **MetaTrader 5 Strategy Tester/visual simulation** và một pipeline Python để đánh giá kết quả.

> **Phạm vi an toàn:** bộ khởi tạo này chỉ dành cho lập trình, backtest và mô phỏng. Không tạo chức năng gửi lệnh thật, không kết nối để điều khiển tài khoản môi giới, không chứa thông tin đăng nhập. Không tự đổi chế độ sang live. Grid/DCA có thể tích lũy mức phơi nhiễm và drawdown nhanh; các giới hạn rủi ro là điều kiện bắt buộc chứ không phải bảo đảm lợi nhuận.

## Đọc theo thứ tự

1. `ROADMAP_MT5_EA_LAB.md` — kế hoạch triển khai theo phase và tiêu chí nghiệm thu.
2. `PROMPT_AI_IMPLEMENT.md` — prompt chính để giao cho AI coding agent.
3. `docs/INSTALL_AND_TEST.md` — cài môi trường, build và test.
4. `docs/ARCHITECTURE.md` — kiến trúc mô phỏng và quy ước dữ liệu.
5. `docs/STRATEGY_SPEC.md` — đặc tả Grid, DCA và Runner Trailing Stop.
6. `docs/RISK_AND_VALIDATION.md` — quản trị rủi ro, kiểm định và các ca test bắt buộc.

## Cấu trúc

```text
mt5-ea-ai-simulation-pack/
├── ROADMAP_MT5_EA_LAB.md
├── PROMPT_AI_IMPLEMENT.md
├── configs/project.example.json
├── docs/
├── scripts/
├── MQL5/Experts/MT5EALab/   # AI tạo EA MQL5 ở các phase tương ứng
├── python/tests/            # AI tạo kiểm thử Python
└── reports/                 # báo cáo test, không commit dữ liệu nhạy cảm
```

## Scripts có sẵn

- `scripts/check-environment.ps1` — kiểm tra Python, MetaEditor path và cấu trúc dự án.
- `scripts/build-mql5.ps1` — biên dịch từng file `.mq5` bằng MetaEditor; không khởi chạy giao dịch.
- `scripts/run-python-tests.ps1` — chạy pytest.
- `scripts/validate-project.py` — kiểm tra cấu hình SIMULATION_ONLY và quét một số API gửi lệnh thật khỏi mã MQL5.
- `scripts/package-source.ps1` — đóng gói mã nguồn/tài liệu để chuyển giao, bỏ qua `.venv`, data và log lớn.

## Lệnh nhanh (PowerShell)

```powershell
# Trong thư mục dự án
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install pytest pandas numpy matplotlib scikit-learn

Copy-Item configs/project.example.json configs/project.local.json
python scripts/validate-project.py --config configs/project.local.json
.\scripts\check-environment.ps1 -ProjectRoot .
.\scripts\run-python-tests.ps1 -ProjectRoot .
```

Biên dịch MQL5, sau khi AI tạo file `.mq5`:

```powershell
.\scripts\build-mql5.ps1 -ProjectRoot . -MetaEditorPath "C:\path\to\MetaEditor64.exe"
```

Tham số `-MetaEditorPath` phải trỏ tới MetaEditor đi kèm terminal MT5 bạn đang dùng. Script chỉ biên dịch source và đọc log; việc chạy Strategy Tester vẫn thực hiện trong giao diện MT5.

## Nguồn tham khảo chính thức

- MetaTrader 5 Strategy Tester: https://www.metatrader5.com/en/terminal/help/algotrading/testing
- MQL5 `CTrade` reference (để hiểu API giao dịch; **không được dùng API này trong code của pack**): https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade
- MQL5 Python integration: https://www.mql5.com/en/docs/python_metatrader5

Chi tiết UI và hành vi terminal có thể thay đổi theo phiên bản. Hãy kiểm tra log và phiên bản MT5 thực tế trước khi coi một build là thành công.
