# Phase 8 — ONNX/MQL5 inference

- **Trạng thái:** `READY_FOR_MANUAL_VALIDATION` (2026-10-27).
- **Phạm vi:** export model logistic Phase 7 sang ONNX, metadata/hash, đối chiếu Python–ONNX trên fixture
  cố định và EA MQL5 chỉ suy luận, không giao dịch.
- **Không bao gồm:** chạy EA trong terminal/Strategy Tester, ONNX model phi tuyến, lấy feature từ bar
  hiện tại, execution thật, kết nối broker.
- **Cảnh báo:** fixture và model đều dẫn xuất từ dữ liệu **synthetic**; không phải kết quả thị trường.
- **Lý do chưa `DONE`:** ONNX Runtime bên trong MT5 chưa được chạy; compile chỉ chứng minh mã hợp lệ.

## 1. Deliverables

| Deliverable | Vị trí |
|---|---|
| Export graph ONNX + metadata/parity | `python/src/mt5_ea_ai_lab/models/onnx_export.py` |
| Validate artifact dùng chung với `load_model` | `python/src/mt5_ea_ai_lab/models/logistic.py` |
| CLI export/parity | `scripts/export_onnx_model.py` |
| Fixture parity 24 hàng (có `expected_probability`) | `python/tests/fixtures/onnx_feature_fixture.csv` |
| Fixture 12 feature cho EA | `mt5/Files/onnx_feature_fixture.csv` |
| EA inference-only | `mt5/Experts/LabOnnxInference.mq5` |
| Test export/parity/CLI | `python/tests/test_onnx_export.py` |
| Hướng dẫn ONNX và kiểm tra thủ công | `docs/reference/onnx.md` |
| Dependency pin | `requirements.txt` (`onnx==1.23.2`, `onnxruntime==1.31.1`) |
| Báo cáo Phase 8 | `docs/phase-reports/phase-8.md` |

Artifact sinh ra (gitignored): `models/candidates/demo-phase7-ml/model.onnx`,
`model_metadata.json`, `onnx_parity.json`, `onnx_parity.csv`.

## 2. Quyết định thiết kế

- **Dựng graph trực tiếp từ `model.json`, không dùng pickle/skl2onnx:** 5 node tường minh
  `Sub(mean) → Div(scale) → MatMul(coefficients) → Add(intercept) → Sigmoid`; dễ audit và không phụ
  thuộc phiên bản scikit-learn khi export.
- **Preprocessing nhúng trong graph:** caller truyền feature thô; mean/scale lấy từ artifact JSON, nên
  không có bước Python nào có thể bị bỏ quên khi chạy MQL5.
- **Opset 13 / IR 8 / float32:** mức thấp, phổ biến với ONNX Runtime trong MT5; batch động trong graph
  nhưng inference shape cố định `[1, 12]` → `[1, 1]` cho EA.
- **Feature order là contract bắt buộc:** ghi trong `model_metadata.json`; export từ chối model thiếu
  feature, sai số feature, scale không dương hoặc giá trị không hữu hạn.
- **Metadata + SHA-256:** lưu hash của `model.json` và `model.onnx` để phát hiện artifact bị thay thế
  trước khi copy sang MT5.
- **Parity theo tolerance tuyệt đối `1e-5`:** Python dùng `float64`, ONNX Runtime dùng `float32`; so sánh
  xác suất trên fixture thật của test segment, không so bitwise.
- **Fixture tách khỏi nhãn:** file cho EA chỉ có 12 feature + header; `expected_probability` chỉ nằm ở
  fixture Python để audit, không đưa sang MQL5.
- **EA fail closed:** `OnnxCreate`/`OnnxSetInputShape`/`OnnxRun` lỗi → `INIT_FAILED`; không chạy tiếp với
  dự đoán giả. `OnTick()` rỗng; không có API order/trade.
- **CLI giữ artifact khi parity fail:** ghi `onnx_parity.json/csv` để điều tra nhưng trả exit `2`.

## 3. Lệnh và kết quả thực tế

| Lệnh | Kết quả thực tế |
|---|---|
| `.venv\Scripts\python.exe -m pip install onnx==1.23.2 onnxruntime==1.31.1` | Cài trong venv: onnx 1.23.2, onnxruntime 1.31.1 (+ protobuf 7.36.2, ml_dtypes 0.6.0, flatbuffers 25.12.19, typing_extensions 4.16.0) |
| `.venv\Scripts\python.exe scripts\export_onnx_model.py --model reports\ml\demo-phase7-ml\model.json --out-dir models\candidates\demo-phase7-ml --fixture python\tests\fixtures\onnx_feature_fixture.csv` | Exit code **0**; `model.onnx` 566 bytes; SHA-256 `a7ae4a25695e0f6dd215615e31acb83bde2ca1483d566ac0530043b04964f9d3`; parity 24/24 hàng PASS |
| ONNX graph checker | Pass; opset 13, IR 8, input `[batch,12]`, output `[batch,1]`, float32 |
| `MetaEditor64.exe /compile:"...\mt5\Experts\LabOnnxInference.mq5" /log:"...\mt5\onnx.compile.log"` | Log: **0 errors, 0 warnings**, 700 ms; `.ex5` 12,284 bytes; CLI exit code `1` (hành vi đã biết) |
| `.venv\Scripts\python.exe -m pytest -q` | **150 passed in 8.76s** |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |

### Kết quả parity (synthetic fixture)

| Hạng mục | Giá trị |
|---|---|
| Model JSON SHA-256 | `5c5260f3daec807c1c67b23ec691e1c9047a60ce78c96f311f9a03bf4be859e8` |
| Số feature | 12 |
| Số hàng parity | 24 (chọn đều từ test segment Phase 7) |
| Max abs diff | `4.673e-08` |
| Mean abs diff | `1.953e-08` |
| Tolerance | `1e-05` |
| Kết luận | **PASS** |

Parity này chỉ chứng minh graph ONNX khớp artifact Python trên fixture offline. Nó **không** chứng minh
ONNX Runtime trong MT5 chạy được hoặc cho cùng kết quả.

## 4. Tiêu chí nghiệm thu

| Tiêu chí (roadmap) | Kết quả | Bằng chứng |
|---|---|---|
| Chọn model/operations export ONNX được | Đạt | Sub/Div/MatMul/Add/Sigmoid; opset 13; graph checker pass |
| Kiểm tra schema, thứ tự feature, kiểu, normalization, output | Đạt | `model_metadata.json`; validation trong `onnx_export.py`; test export |
| Đối chiếu dự đoán Python–ONNX trên fixture cố định | Đạt | 24 hàng; max abs diff `4.673e-08` < `1e-5`; `onnx_parity.json/csv` |
| EA inference-only, chỉ đọc input và in prediction | Đạt (mã nguồn) | `LabOnnxInference.mq5`; `OnTick()` rỗng; không có API order/trade |
| Dùng `OnnxCreate`/`OnnxSetInputShape`/`OnnxRun` | Đạt (compile) | 0 errors/0 warnings; chưa chạy runtime |
| Kiểm thử ONNX trong Strategy Tester, ghi build/runtime | **Chưa đạt** | Cần người dùng chạy thủ công; xem `docs/reference/onnx.md` mục 4 |
| Sai schema/feature/missing model dừng an toàn | Đạt (Python + thiết kế EA) | Export/load fail closed; test sai shape/feature; `OnInit` trả `INIT_FAILED` |
| Không có execution code | Đạt | Không có `OrderSend`/`CTrade` trong EA hoặc repo |

Phase 8 giữ `READY_FOR_MANUAL_VALIDATION` vì tiêu chí runtime MT5 chưa đạt. Không tuyên bố tương thích
ONNX/MQL5 hay parity runtime.

## 5. Test đã bổ sung

- `test_onnx_export.py` (7 test): export/hash/metadata; metadata roundtrip và threshold; từ chối sai
  shape/feature không hữu hạn; từ chối scale âm; từ chối tolerance âm; CLI export + parity pass; CLI
  thiếu feature exit `1`.

Tổng: **7 test Phase 8**; toàn bộ suite **150 passed** (143 test Phase 7 + 7 test Phase 8).

## 6. File đã tạo/sửa

Tạo mới:

- `python/src/mt5_ea_ai_lab/models/onnx_export.py`
- `scripts/export_onnx_model.py`
- `python/tests/test_onnx_export.py`
- `python/tests/fixtures/onnx_feature_fixture.csv`
- `mt5/Experts/LabOnnxInference.mq5`
- `mt5/Files/onnx_feature_fixture.csv`
- `docs/reference/onnx.md`
- `docs/phase-reports/phase-8.md`

Cập nhật:

- `python/src/mt5_ea_ai_lab/models/logistic.py` (tách `validate_model_artifact` dùng chung)
- `python/src/mt5_ea_ai_lab/models/__init__.py`
- `requirements.txt` (`onnx`, `onnxruntime`)
- `README.md`, `docs/reference/architecture.md`, `docs/guides/install-and-test.md`, `docs/reference/testing.md`,
  `docs/reference/risk.md`, `docs/reference/data-dictionary.md`, `mt5/README.md`

Không thêm execution, không thay đổi signal engine/EA Phase 1–5, không kết nối broker.

## 7. Vấn đề còn tồn tại

1. **ONNX Runtime trong MT5 chưa chạy:** chưa biết `OnnxCreate`/`OnnxRun` có hoạt động với build
   5.0.0.6249 không; chưa có parity runtime.
2. **Chưa chạy Strategy Tester:** không có log `onnx_row=... probability=...` thật.
3. **Float32:** sai lệch với Python `float64` được chấp nhận trong `1e-5`, không phải bitwise.
4. **Chỉ graph logistic tuyến tính:** chưa hỗ trợ model phi tuyến/LSTM/ensemble.
5. **EA chỉ đọc fixture tĩnh:** chưa nối feature pipeline MQL5 với bar hiện tại; đây là harness, không
   phải chiến lược live.
6. **Opset/IR/provider chưa kiểm tra theo build MT5:** nâng cấp terminal hoặc onnx có thể phá tương thích.
7. **Fixture/model synthetic:** kết quả chỉ minh họa cơ chế, không phải hiệu năng.
8. **Worktree dirty:** các thay đổi Phase 1–8 chưa commit; chưa thể coi là bằng chứng tái lập mạnh.

## 8. Kiểm tra thủ công gợi ý

1. Export lại model:
   `.\.venv\Scripts\python.exe scripts\export_onnx_model.py --model reports\ml\demo-phase7-ml\model.json --out-dir models\candidates\demo-phase7-ml --fixture python\tests\fixtures\onnx_feature_fixture.csv`;
   xác nhận exit `0`, parity PASS, SHA-256 khớp metadata.
2. Copy `model.onnx` + `mt5/Files/onnx_feature_fixture.csv` vào `<Data Folder>/MQL5/Files/`.
3. Sync `LabOnnxInference.mq5` vào `<Data Folder>/MQL5/Experts/`, compile trong MetaEditor; xác nhận
   0 errors/0 warnings.
4. Kéo EA vào chart bất kỳ (không cần account/execution); đọc tab **Experts**.
5. Đối chiếu từng `probability` với `expected_probability` trong
   `python/tests/fixtures/onnx_feature_fixture.csv`, tolerance `1e-5`; ghi build terminal và kết quả.
6. Nếu lỗi ONNX, ghi mã lỗi/build và giữ trạng thái `READY_FOR_MANUAL_VALIDATION`; không tạo workaround
   chưa xác minh.
7. Không đặt secret trong log/config; không commit model artifact, `.ex5` hay fixture sinh tự động ngoài
   file fixture nhỏ đã chọn.

## 9. Bước tiếp theo

Phase 9 — giả lập tiến trình end-to-end và đánh giá cuối: chạy pipeline cố định từ dữ liệu → validate →
feature/signal → backtest/ML → experiment store → report; thử dữ liệu lỗi/model thiếu để xác minh
fail-safe; kiểm tra tái lập sau commit sạch; viết limitation report. Phase 9 không mở rộng sang execution
thật. ONNX runtime MT5 vẫn là hạng mục thủ công mở, không chặn pipeline Python end-to-end.
