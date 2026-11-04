# Vận hành — chạy bot an toàn

Thư mục này gom mọi thứ cần để **chạy được** bot: cài đặt, preset, tester, xử lý sự cố và chuẩn bằng chứng.

| File | Vai trò |
|---|---|
| [install.md](install.md) | Cài đặt MT5, deploy PinePort, compile và kiểm chứng lần đầu. |
| [demo-execution.md](demo-execution.md) | Ranh giới an toàn và quy trình chạy 5 bot demo (ADR 0004–0007). |
| [presets.md](presets.md) | Preset JSON là nguồn sự thật; `.set` là dẫn xuất; magic number của từng bot. |
| [strategy-tester.md](strategy-tester.md) | Chạy Strategy Tester headless và đọc report + CSV đúng cách. |
| [toolchain.md](toolchain.md) | Năm script build/validate/test, không script nào chạm terminal. |
| [troubleshooting.md](troubleshooting.md) | Pipeline chẩn đoán 10 bước và 7 nguyên nhân "0 trade" đã gặp thật. |
| [evidence.md](evidence.md) | 9 nhãn trạng thái, bảng bằng chứng theo tuyên bố, nơi lưu report. |

Thứ tự đọc khi muốn chạy bot:

1. [install.md](install.md) — môi trường và compile.
2. [demo-execution.md](demo-execution.md) — điều kiện an toàn trước khi bật bot.
3. [presets.md](presets.md) — nạp đúng preset, đúng magic.
4. [strategy-tester.md](strategy-tester.md) — backtest trong tester trước, demo thật sau.
5. Kẹt ở đâu → [troubleshooting.md](troubleshooting.md); muốn kết luận gì → [evidence.md](evidence.md).

Các file `.set` nằm trong [presets/](presets/). Định nghĩa nhãn trạng thái: mục 1 của [evidence.md](evidence.md).
