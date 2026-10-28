# ONNX inference — Phase 8

- **Trạng thái:** `READY_FOR_MANUAL_VALIDATION` (2026-10-27).
- **Đã chạy thật:** export ONNX, kiểm tra graph, parity Python–ONNX trên 24 hàng fixture, compile EA.
- **Chưa chạy:** EA trong MT5 terminal/Strategy Tester; ONNX Runtime bên trong MT5 chưa được xác minh.
- **Phạm vi:** model logistic Phase 7, một input `float32`, một output xác suất; không có execution.
- **Mã nguồn:** `python/src/mt5_ea_ai_lab/models/onnx_export.py`,
  `scripts/export_onnx_model.py`, `mt5/Experts/LabOnnxInference.mq5`.
- **Fixture:** `python/tests/fixtures/onnx_feature_fixture.csv` (24 hàng test synthetic),
  `mt5/Files/onnx_feature_fixture.csv` (12 feature, dùng cho EA).

## 1. Graph

Model JSON của Phase 7 được chuyển thành graph ONNX tường minh, không dùng pickle và không cần
`skl2onnx`:

```text
features [batch, 12] float32
        │
        ├─ Sub(mean) → Div(scale)        # StandardScaler nhúng trong graph
        ├─ MatMul(coefficients) → Add(intercept)
        └─ Sigmoid → probability [batch, 1] float32
```

| Thuộc tính | Giá trị |
|---|---|
| Opset | `13` |
| IR version | `8` |
| Input | `features`, `float32`, graph `[batch, 12]`; inference shape `[1, 12]` |
| Output | `probability`, `float32`, `[batch, 1]` |
| Threshold | 0.5 (lấy từ model JSON) |
| Preprocessing | mean/scale nhúng trong graph, không cần bước Python |
| Tolerance parity | `1e-5` tuyệt đối |
| Kích thước demo | 566 bytes |

Feature order là thứ tự trong `metadata.input.feature_names` và phải khớp tuyệt đối với
`feature_schema.json` của Phase 7:

`return_1`, `return_3`, `return_5`, `return_10`, `ema_gap`, `ema_slope`, `volatility`, `return_z`,
`stochastic`, `range_ratio`, `body_ratio`, `volume_z`.

## 2. Lệnh export và kết quả thực tế

```powershell
.\.venv\Scripts\python.exe scripts\export_onnx_model.py `
  --model reports\ml\demo-phase7-ml\model.json `
  --out-dir models\candidates\demo-phase7-ml `
  --fixture python\tests\fixtures\onnx_feature_fixture.csv
```

Kết quả thực tế:

| Hạng mục | Giá trị |
|---|---|
| Exit code | `0` |
| ONNX SHA-256 | `a7ae4a25695e0f6dd215615e31acb83bde2ca1483d566ac0530043b04964f9d3` |
| Model JSON SHA-256 | `5c5260f3daec807c1c67b23ec691e1c9047a60ce78c96f311f9a03bf4be859e8` |
| Số feature | 12 |
| Số hàng parity | 24 (các hàng test synthetic) |
| Max abs diff | `4.673e-08` |
| Mean abs diff | `1.953e-08` |
| Tolerance | `1e-05` |
| Kết luận parity | **PASS** |

Artifacts (gitignored): `models/candidates/demo-phase7-ml/model.onnx`,
`model_metadata.json`, `onnx_parity.json`, `onnx_parity.csv`.

Exit code: `0` export + parity đạt; `1` model/fixture/output không đọc/ghi được; `2` ONNX validation
hoặc parity thất bại. Khi parity thất bại, artifact vẫn được ghi để điều tra nhưng CLI trả `2`.

## 3. EA inference-only

`mt5/Experts/LabOnnxInference.mq5`:

- `OnInit`: `OnnxCreate` model, `OnnxSetInputShape([1, 12])`, `OnnxSetOutputShape([1, 1])`, đọc fixture
  CSV và gọi `OnnxRun` cho từng hàng.
- In `onnx_row=<n> probability=<p>` vào log; không lưu file, không tạo tín hiệu giao dịch.
- `OnTick` rỗng; **không có** `OrderSend`, `CTrade.Buy`, `CTrade.Sell`, không kết nối tài khoản.
- Nếu model/file/shape lỗi, `OnInit` trả `INIT_FAILED` hoặc `INIT_PARAMETERS_INCORRECT`; không chạy
  tiếp với dự đoán giả.

Kết quả compile thực tế:

| Lệnh | Kết quả |
|---|---|
| `MetaEditor64.exe /compile:"...\LabOnnxInference.mq5" /log:"...\onnx.compile.log"` | Log: **0 errors, 0 warnings**, 700 ms; tạo `LabOnnxInference.ex5` 12,284 bytes; CLI exit code `1` (hành vi đã biết của MetaEditor) |

Compile **không** chứng minh ONNX Runtime trong MT5 chạy được. EA chưa được chạy trong terminal.

## 4. Quy trình kiểm tra thủ công

1. Copy `models\candidates\demo-phase7-ml\model.onnx` vào `<MT5 Data Folder>\MQL5\Files\model.onnx`.
2. Copy `mt5\Files\onnx_feature_fixture.csv` vào `<MT5 Data Folder>\MQL5\Files\`.
3. Copy `mt5\Experts\LabOnnxInference.mq5` vào `<MT5 Data Folder>\MQL5\Experts\` (hoặc sync thư mục).
4. Mở MetaEditor, compile `LabOnnxInference.mq5`; xác nhận log 0 errors/0 warnings.
5. Trong MT5, chạy EA trên một chart bất kỳ (không cần account thật; không chọn execution). EA không
   giao dịch; chỉ đọc fixture và in log.
6. So sánh `probability` trong log với cột `expected_probability` của
   `python/tests/fixtures/onnx_feature_fixture.csv`; dùng tolerance `1e-5`.
7. Nếu MT5 báo lỗi `OnnxCreate`, `OnnxSetInputShape` hoặc `OnnxRun`, ghi lại mã lỗi, build terminal và
   không kết luận tương thích. Không tạo workaround chưa được xác minh.

## 5. Tiêu chí nghiệm thu Phase 8

| Tiêu chí | Trạng thái | Bằng chứng |
|---|---|---|
| Chọn model/operations export ONNX được | Đạt | Sub/Div/MatMul/Add/Sigmoid, opset 13, graph checker pass |
| Kiểm tra schema, thứ tự feature, kiểu, normalization, output | Đạt | `model_metadata.json`; test export; parity trên fixture |
| Đối chiếu Python–ONNX trên fixture cố định | Đạt | 24 hàng, max diff `4.673e-08` < `1e-5` |
| EA inference-only, không gửi lệnh | Đạt (mã nguồn) | `OnTick` rỗng; không có API order/trade |
| Dùng `OnnxCreate`/`OnnxRun` nếu build hỗ trợ | Đạt (compile) | 0 errors/0 warnings; chưa chạy runtime |
| Kiểm thử ONNX trong Strategy Tester | **Chưa đạt** | Cần người dùng chạy thủ công; ghi build terminal |
| Sai schema/feature/model dừng an toàn | Đạt (Python + thiết kế EA) | `load_model`/`export` fail closed; `OnInit` trả lỗi |
| Không có execution code | Đạt | Không có `OrderSend`/`CTrade` trong EA |

Phase 8 giữ trạng thái `READY_FOR_MANUAL_VALIDATION` vì chưa có kết quả runtime MT5. Không tuyên bố
tương thích ONNX/MQL5 hoặc parity runtime khi chưa chạy bước 5–6.

## 6. Giới hạn

- Chỉ hỗ trợ graph logistic tuyến tính + sigmoid; chưa có model phi tuyến, LSTM hay ensemble.
- Input/output `float32`; sai lệch với Python `float64` được chấp nhận trong `1e-5`, không phải bitwise.
- Chưa kiểm tra ONNX Runtime version, CPU/GPU provider hoặc giới hạn opset của build MT5 5.0.0.6249.
- EA dùng đường dẫn tương đối trong `MQL5/Files`; chưa tự động copy model/fixture.
- EA chỉ đọc fixture tĩnh, chưa lấy feature từ bar hiện tại; đây là harness kiểm tra inference, không
  phải chiến lược live.
- Không có execution, không có kết luận lợi nhuận, không có kết nối broker.
