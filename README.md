# MT5 EA & AI Lab (tm-fx)

Repository nghiên cứu độc lập cho Expert Advisor (EA) MQL5: 6 bot demo gửi lệnh thật **chỉ trên tài
khoản demo** hoặc Strategy Tester, các EA mô phỏng vị thế ảo, pipeline Python (dữ liệu, backtest,
ML, ONNX) và bộ tài liệu tiếng Việt tổ chức theo tầng mục đích. Mọi kết quả là **đơn vị mô hình** trên
dữ liệu backtest/mô phỏng — lợi nhuận của mọi chiến lược là `UNPROVEN`, không có tuyên bố nào ngược lại.

## 6 bot demo

| Bot | Magic | Preset | Nhãn |
|---|---|---|---|
| `PATrendRiderXAUv1DemoEA` | 25002001 | `configs/demo/pa_trendrider_xau_demo.json` | `PARTIAL` |
| `GridDemoEA` | 25004001 | `configs/demo/grid_demo.json` | `NOT_RUN` |
| `DCADemoEA` | 25005001 | `configs/demo/dca_demo.json` | `NOT_RUN` |
| `InfiniteRunnerXAUV2DemoEA` | 25006001 | `configs/demo/infinite_runner_demo.json` | `NOT_RUN` |
| `WonderwhalesDemoEA` | 25007001 | `configs/demo/wonderwhales_demo.json` | `UNPROVEN` |
| `WonderwhalesXAU2ModeEA` | 25008001 | `configs/demo/wonderwhales_xau_2mode_demo.json` | `NOT_RUN` |

Nghĩa của nhãn: [docs/00-start/glossary.md](docs/00-start/glossary.md). Danh mục đầy đủ 16 EA
(6 demo + 10 lab; thêm 1 EA dump tester không tính là bot):
[docs/10-bots/README.md](docs/10-bots/README.md).

## Tài liệu

Điểm vào duy nhất của toàn bộ tài liệu: [docs/README.md](docs/README.md) — thứ tự đọc, bảng
"Tôi muốn…", trạng thái 5 bot và các cổng kiểm tra. Người mới bắt đầu:
[docs/00-start/first-run.md](docs/00-start/first-run.md).

## Ranh giới an toàn

- Chỉ tài khoản **demo** hoặc Strategy Tester; tài khoản real/live bị cấm và bị code từ chối tại `OnInit`.
- Mọi lệnh đi qua `mt5/Include/Exec/ExecBroker.mqh`; SL/TP bắt buộc trên mọi lệnh; kill switch; không credential, không login automation.
- Không commit dữ liệu tài khoản hay secret; không tuyên bố lợi nhuận từ kết quả backtest/mô phỏng.

Roadmap không nằm ở đây — xem [docs/00-start/roadmap.md](docs/00-start/roadmap.md).
