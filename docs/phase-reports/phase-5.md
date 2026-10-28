# Báo cáo Phase 5 — So sánh tín hiệu MQL5 và Python

- **Ngày:** 2026-10-27
- **Trạng thái:** `READY_FOR_MANUAL_VALIDATION`
- **Lý do:** exporter/comparator đã có và đã test; MQL5 `LabSignalExport.mq5` compile 0 errors/0 warnings
  nhưng **chưa chạy** trong terminal, nên chưa có export MQL5 thật và chưa thể kết luận parity.
- **Phạm vi:** cùng fixture, cùng cửa sổ EMA, schema CSV chung, tolerance số học, báo cáo mismatch.
- **Không bao gồm:** execution, Strategy Tester, dữ liệu broker thật, ML/ONNX.

## 1. Tóm tắt

Phase 5 thống nhất cửa sổ EMA giữa EA/Python là `slow_period + 1` nến đóng, thay cho fixture full-history
cũ. Fixture chung 12 nến synthetic được thêm; phía Python export và comparator đã chạy thật. Phía MQL5
đã có script export và compile sạch, nhưng chưa chạy vì cần thao tác terminal thủ công. Vì vậy báo cáo
này **không** tuyên bố MQL5 và Python tương đương.

## 2. Deliverables

| Deliverable | Vị trí | Trạng thái |
|---|---|---|
| Fixture chung | `datasets/samples/parity_ema_cross.csv` | Có; validation pass |
| MQL5 signal export | `mt5/Scripts/LabSignalExport.mq5` | Compile 0/0; chưa chạy |
| Python signal export | `scripts/export_python_signals.py` | Đã chạy thật |
| Comparator package | `python/src/mt5_ea_ai_lab/evaluation/parity.py` | Có |
| Comparator CLI | `scripts/compare_signals.py` | Đã chạy thật |
| Unit test comparator/fixture | `python/tests/test_parity.py`, `python/tests/test_signals.py` | Pass |
| Tài liệu quy trình/tolerance/sai khác | `docs/parity.md` | Có |
| Self-check report | `reports/parity/self_check/` (gitignored) | Match 12/12 |
| Negative comparator report | `reports/parity/mismatch_selftest/` (gitignored) | 3 mismatch đúng như kỳ vọng |
| Báo cáo Phase 5 | `docs/phase-reports/phase-5.md` | File này |

## 3. Quyết định thiết kế

- **Một cửa sổ EMA:** cả EA, Python `generate_signals` và MQL5 exporter đánh giá trên đúng
  `slow_period + 1` close; EMA seed lại bằng SMA ở đầu mỗi cửa sổ. Đây là baseline, không phải EMA
  full-history hay EMA mặc định của MT5.
- **Mỗi bar một dòng:** bar warm-up vẫn xuất `UNKNOWN`/`INSUFFICIENT_HISTORY` với EMA để trống. Không lọc
  bar `UNKNOWN`, vì lọc sẽ che lỗi warm-up.
- **Schema chung:** `timestamp,symbol,timeframe,signal,reason,fast_prev,slow_prev,fast,slow`.
- **Text exact, numeric tolerant:** `signal`/`reason` so sánh chính xác; EMA dùng sai khác tuyệt đối
  `1e-9`. MQL5 ghi 12 chữ số thập phân.
- **Key-based comparison:** merge theo `(timestamp, symbol, timeframe)`; thứ tự dòng không ảnh hưởng.
  Duplicate key hoặc key rỗng là lỗi input, fail closed.
- **Không so sánh mẫu:** comparator đọc toàn bộ hai file; report có `rows_mql5`, `rows_python`,
  `rows_compared`.
- **Fail closed:** thiếu cột, timestamp sai, numeric không hợp lệ, NaN một phía, thiếu hàng đều được báo
  rõ; không tự sửa dữ liệu.

## 4. Fixture và kỳ vọng

`parity_ema_cross.csv`: 12 nến M5 EURUSD synthetic, fast=2, slow=3.

| Kết quả | Số bar | Bar |
|---|---|---|
| `UNKNOWN` / `INSUFFICIENT_HISTORY` | 3 | 0–2 |
| `HOLD` / `NO_CROSS` | 7 | 3, 4, 6, 7, 8, 10, 11 |
| `BUY` / `OK` | 1 | 5 (00:25 UTC) |
| `SELL` / `OK` | 1 | 9 (00:45 UTC) |

Fixture pass validation với 0 error và 1 warning `synthetic_dataset`. Đây không phải dữ liệu thị trường.

## 5. Lệnh và kết quả thực tế

| Lệnh | Kết quả thực tế |
|---|---|
| `MetaEditor64.exe /compile:...\LabSignalEngineTests.mq5 /log:...\compile_tests.log` | Log 0 errors, 0 warnings, 872 ms; `.ex5` 18,504 bytes; exit code 1 (hành vi CLI đã biết) |
| `MetaEditor64.exe /compile:...\LabSignalExport.mq5 /log:...\export.compile.log` | Log 0 errors, 0 warnings, 959 ms; `.ex5` 22,906 bytes; exit code 1 |
| `.venv\Scripts\python.exe -m pytest -q` | **79 passed in 2.03s** |
| `.venv\Scripts\python.exe scripts\export_python_signals.py` | Exit 0; `rows=12 buy=1 sell=1 hold=7 unknown=3 fast=2 slow=3` |
| `.venv\Scripts\python.exe scripts\compare_signals.py --mql5 reports\parity\parity_signals_python.csv --python reports\parity\parity_signals_python.csv --out-dir reports\parity\self_check` | Exit 0; 12/12 hàng, 0 mismatch; **self-comparison**, không phải parity |
| Comparator với bản copy chỉ sửa 1 EMA, 1 signal, 1 reason | Exit 1; 3 mismatch: `fast` tại 00:25, `signal` + `reason` tại 00:45; JSON + CSV được ghi |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit 0 |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |

Report self-check: `reports/parity/self_check/mismatch_report.json` có `status=match`,
`mismatch_count=0`. Report negative test: `reports/parity/mismatch_selftest/mismatch_report.csv` liệt kê
đúng timestamp/field. Cả hai nằm trong `reports/` (gitignored).

### MQL5 export chưa chạy

Không có `parity_signals_mql5.csv` thật. Agent không tự mở terminal vì terminal có thể kết nối tài khoản
broker. Quy trình thủ công đầy đủ ở [`docs/parity.md`](../parity.md) mục 3.2–3.3. Sau khi chạy, kỳ vọng
log `event=export_done rows=12 buy=1 sell=1 hold=7 unknown=3`; chỉ khi đó mới có dữ liệu để kết luận
parity.

## 6. Tiêu chí nghiệm thu

| Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|
| Chuẩn hóa EMA/warm-up/nến đóng/rounding | Đạt | Cửa sổ `slow+1` trong spec, EA, MQL5 export, Python; MQL5 12 chữ số; tolerance `1e-9` |
| Dùng một fixture chung | Đạt | `parity_ema_cross.csv`; test Python đọc đúng fixture và chuỗi signal |
| Xuất tín hiệu MQL5 hoặc quy trình thủ công rõ hạn chế | Một phần | Script compile 0/0; quy trình và giới hạn đã ghi; runtime **chưa chạy** |
| `compare_signals.py` so sánh timestamp/feature/signal | Đạt | CLI + 15 test trong `test_parity.py`; so sánh key, text, numeric |
| Định nghĩa tolerance, không dùng để che lỗi logic | Đạt | Text exact; numeric `1e-9`; test signal case-sensitive và ngoài tolerance |
| Báo cáo mismatch | Một phần | Generator chạy thật với self-check và negative test; chưa có report MQL5 thật |
| Mismatch liệt kê theo timestamp và field | Đạt (cho comparator) | Negative report: 00:25/`fast`, 00:45/`signal`, 00:45/`reason` |
| Không tuyên bố tương đương khi chỉ so sánh vài hàng | Đạt | So sánh toàn bộ 12 hàng; self-comparison được ghi rõ không phải parity |
| Ghi rõ hạn chế chạy terminal tự động | Đạt | `docs/parity.md`, mục 5–6 báo cáo này |

Kết luận: deliverables tooling và tài liệu đạt; nghiệm thu parity thực tế **chưa đạt** cho đến khi chạy
MQL5 export và comparator trên output thật.

## 7. Lỗi đã gặp và cách xử lý

- **MQL5 compile lần đầu 17 errors:** dùng `input`/`output` làm tên biến cục bộ (trùng keyword) và gọi
  `StringToLower` như hàm trả về string, trong khi MQL5 biến đổi tại chỗ. Đổi thành
  `input_handle`/`output_handle`, thêm `LowerCopy`, compile lại 0/0.
- **Pytest fail ở test tolerance:** CSV round-trip làm `1.10 + 2e-9` sai khác khoảng `5.7e-17`; sửa
  assertion dùng `rel=1e-6` thay vì `abs=1e-20`. Không nới tolerance của comparator.
- **Warning parse timestamp:** chỉ định `format="ISO8601"` khi parse key; report vẫn chấp nhận `Z` và
  offset UTC.

## 8. File đã tạo/sửa

Tạo mới:

- `datasets/samples/parity_ema_cross.csv`
- `mt5/Scripts/LabSignalExport.mq5`
- `python/src/mt5_ea_ai_lab/evaluation/parity.py`
- `python/tests/test_parity.py`
- `scripts/export_python_signals.py`
- `scripts/compare_signals.py`
- `docs/parity.md`
- `docs/phase-reports/phase-5.md`

Cập nhật:

- `mt5/Scripts/LabSignalEngineTests.mq5` (fixture 4-bar, cửa sổ `slow+1`; compile lại)
- `python/tests/test_signals.py` (test fixture chung)
- `python/src/mt5_ea_ai_lab/evaluation/__init__.py`
- `docs/strategy-signal-spec.md` (cửa sổ cuộn, fixture mới, mục parity)
- `datasets/samples/README.md` (mô tả fixture parity; sửa vị trí BUY của demo)
- `mt5/README.md` (script export, compile results, quy trình thủ công, an toàn)
- `README.md`, `docs/architecture.md`, `docs/environment.md`, `docs/risk-and-limitations.md`

Không thêm dependency mới ở Phase 5.

## 9. Vấn đề còn tồn tại

1. **MQL5 export chưa chạy** → chưa có parity thực tế; trạng thái phase là
   `READY_FOR_MANUAL_VALIDATION`.
2. **Self-check script MQL5 và Strategy Tester vẫn chưa chạy** từ Phase 1/2; compile không chứng minh
   runtime.
3. **Chỉ có một fixture ngắn, synthetic.** Parity trên 12 bar không chứng minh cho dữ liệu dài, gap,
   spread biến động, symbol khác hoặc timeframe khác.
4. **Comparator chỉ so CSV**, không kiểm tra EA đọc đúng nến live; hành vi `CopyRates`/bar alignment vẫn
   cần Strategy Tester hoặc manual run.
5. **MQL5 CSV parser đơn giản:** không hỗ trợ quoted comma; header và cột bắt buộc.
6. **Report gitignored** và chứa đường dẫn tuyệt đối; không dùng làm artifact tái lập lâu dài cho đến
   Phase 6.

## 10. Kiểm tra thủ công gợi ý

1. Compile lại `LabSignalEngineTests.mq5` và chạy trên chart; kỳ vọng `TEST|RESULT|ALL_PASS`.
2. Làm theo [`docs/parity.md`](../parity.md) mục 3.2 để tạo `parity_signals_mql5.csv`.
3. Kiểm tra `event=export_done rows=12 buy=1 sell=1 hold=7 unknown=3` trong Experts.
4. Chạy Python export và comparator; kỳ vọng exit 0, `rows_compared=12`, `mismatch_count=0`.
5. Nếu có mismatch, lưu report và điều tra theo mục 7 của `docs/parity.md`; không sửa tolerance để che
   text mismatch.
6. Ghi build terminal và kết quả thật vào báo cáo này trước khi đổi trạng thái thành `DONE`.

## 11. Bước tiếp theo

Phase 6 — experiment store/SQLite metadata, config hash, data fingerprint và trạng thái run. Parity
runtime vẫn là hạng mục thủ công mở; không tuyên bố tương đương MQL5/Python cho đến khi hoàn tất mục 10.
