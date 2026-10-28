# Parity MQL5 ↔ Python

- **Phạm vi:** Phase 5. So sánh tín hiệu của baseline EMA crossover giữa `SignalEngine.mqh` và
  `signals/ema_crossover.py` trên cùng một fixture.
- **Không bao gồm:** execution, Strategy Tester, dữ liệu broker thật, ML/ONNX.
- **Trạng thái hiện tại:** comparator và hai exporter đã có test; MQL5 export **chưa được chạy** trong
  terminal. Vì vậy chưa có tuyên bố tương đương MQL5/Python.

## 1. Fixture chung

`datasets/samples/parity_ema_cross.csv` là fixture **synthetic** 12 nến M5 EURUSD, fast=2, slow=3:

| Bar | Timestamp (UTC) | Close | Kỳ vọng |
|---|---|---|---|
| 0–2 | 00:00–00:10 | 1.10 → 1.08 | `UNKNOWN` / `INSUFFICIENT_HISTORY` |
| 3 | 00:15 | 1.07 | `HOLD` / `NO_CROSS` |
| 4 | 00:20 | 1.06 | `HOLD` / `NO_CROSS` |
| 5 | 00:25 | 1.09 | `BUY` / `OK` |
| 6–8 | 00:30–00:40 | 1.10 → 1.13 | `HOLD` / `NO_CROSS` |
| 9 | 00:45 | 1.10 | `SELL` / `OK` |
| 10–11 | 00:50–00:55 | 1.07 → 1.04 | `HOLD` / `NO_CROSS` |

Fixture không phải dữ liệu thị trường và không dùng để đánh giá hiệu năng. Cùng fixture được dùng cho cả
hai implementation; không sinh timestamp hoặc giá khác nhau cho từng phía.

## 2. Export schema

Cả hai phía ghi CSV với đúng thứ tự cột:

```text
timestamp,symbol,timeframe,signal,reason,fast_prev,slow_prev,fast,slow
```

| Cột | Ý nghĩa |
|---|---|
| `timestamp` | ISO 8601 UTC, ví dụ `2024-01-01T00:25:00Z` |
| `symbol`, `timeframe` | Lấy từ fixture |
| `signal` | `UNKNOWN`, `HOLD`, `BUY`, `SELL` |
| `reason` | `OK`, `NO_CROSS`, `INSUFFICIENT_HISTORY`, ... |
| `fast_prev`, `slow_prev`, `fast`, `slow` | EMA trên nến trước và nến hiện tại; để trống nếu không đánh giá được |

Mỗi bar có đúng một dòng, kể cả bar warm-up. Không bỏ qua bar `UNKNOWN`, vì làm vậy sẽ che lỗi
warm-up/boundary.

## 3. Quy trình chạy

### 3.1 Phía Python (đã chạy thực tế)

```powershell
.\.venv\Scripts\python.exe scripts\export_python_signals.py
```

Mặc định đọc `datasets/samples/parity_ema_cross.csv` và ghi
`reports/parity/parity_signals_python.csv`. Exit code `0` khi ghi thành công, `1` khi config/loader lỗi,
`2` khi validation lỗi, `3` khi sinh tín hiệu lỗi.

### 3.2 Phía MQL5 (thủ công)

Agent không tự mở terminal vì terminal có thể kết nối tài khoản broker. Các bước do người dùng thực hiện:

1. Sync `mt5/Scripts/LabSignalExport.mq5` và các file `mt5/Include/*.mqh` vào data folder, giữ nguyên
   cấu trúc `Scripts/` và `Include/`.
2. Compile trong MetaEditor (`F7`), xác nhận 0 errors/0 warnings.
3. Copy `datasets/samples/parity_ema_cross.csv` vào
   `%APPDATA%\MetaQuotes\Terminal\Common\Files\parity_ema_cross.csv`.
4. Mở một chart bất kỳ, kéo `LabSignalExport` vào chart, giữ input mặc định:
   `InpFastPeriod=2`, `InpSlowPeriod=3`, `InpAllowLong=true`, `InpAllowShort=true`,
   input `parity_ema_cross.csv`, output `parity_signals_mql5.csv`.
5. Chọn OK. Script không đọc dữ liệu thị trường, không truy cập tài khoản, không giao dịch; chỉ đọc/ghi
   file trong `Common\Files`.
6. Đọc tab **Experts**, kỳ vọng dòng:
   `event=export_done rows=12 buy=1 sell=1 hold=7 unknown=3 ...`
7. Copy `parity_signals_mql5.csv` từ `Common\Files` về `reports\parity\parity_signals_mql5.csv`.

Nếu input không khớp (fast/slow/allow long/short), export vẫn chạy nhưng kết quả không dùng để so sánh.

### 3.3 So sánh

```powershell
.\.venv\Scripts\python.exe scripts\compare_signals.py `
  --mql5 reports\parity\parity_signals_mql5.csv `
  --python reports\parity\parity_signals_python.csv `
  --out-dir reports\parity\mql5_vs_python `
  --tolerance 1e-9
```

Exit code `0` = mọi hàng khớp; `1` = có mismatch; `2` = input/argument không hợp lệ. Report được ghi vào
`mismatch_report.json` và `mismatch_report.csv`.

## 4. Chính sách tolerance

- `signal` và `reason`: so sánh **chính xác**, phân biệt hoa/thường. Tolerance không áp dụng cho text.
- Bốn trường EMA: sai khác tuyệt đối `<= tolerance` (mặc định `1e-9`).
- MQL5 ghi 12 chữ số thập phân; sai số làm tròn với giá quanh 1.0 nhỏ hơn `5e-13`, thấp hơn tolerance.
- Timestamp được parse và chuẩn hóa về UTC trước khi dùng làm key; `Z` và `+00:00` tương đương.
- Ô trống ở trường số được coi là `NaN`. Hai bên cùng trống = khớp; một bên trống = `nan_mismatch`.
- `symbol`, `timeframe` được trim và so sánh chính xác.
- Duplicate key `(timestamp, symbol, timeframe)` là lỗi input, không silently lấy dòng cuối.
- Comparator so sánh **toàn bộ** hàng trong cả hai file, không lấy mẫu. Kết quả `match` chỉ có nghĩa với
  đúng hai file đã so sánh; không suy rộng cho symbol/timeframe/khoảng thời gian khác.

Không tăng tolerance để che mismatch `signal`/`reason`; nếu text lệch, đó là lỗi logic hoặc input khác
nhau, không phải sai số số học.

## 5. Nguồn sai khác đã biết

| Nguồn | Ảnh hưởng | Cách xử lý |
|---|---|---|
| Cửa sổ EMA | EMA seed lại mỗi cửa sổ `slow+1`, không phải EMA full-history | Cả hai phía dùng cùng cửa sổ; đã ghi trong `strategy-signal-spec.md` |
| Nguồn dữ liệu | Broker bar khác fixture → close khác → signal khác | Parity chỉ dùng đúng một file CSV; không trộn nguồn |
| Timezone/DST | Cùng thời điểm bị lệch key | Fixture dùng UTC `Z`; comparator chuẩn hóa UTC |
| Rounding/float | Sai khác nhỏ ở EMA | MQL5 12 chữ số; tolerance tuyệt đối `1e-9` |
| Thứ tự dòng | Có thể khác giữa hai exporter | Merge theo key, không so sánh theo vị trí |
| Warm-up | Dễ bỏ sót bar `UNKNOWN` | Mỗi bar đều có dòng; thiếu dòng bị báo `missing_in_*` |
| Config khác nhau | `allow_long/short` hoặc period khác → tín hiệu khác | Ghi rõ input hai phía; config sai bị abort/validate |
| Bar alignment | Export MQL5 đánh giá lại từng bar lịch sử, không mô phỏng `CopyRates` live | Đây là parity của signal engine trên cùng bar, không thay thế test EA runtime |

## 6. Trạng thái xác minh

| Hạng mục | Trạng thái | Bằng chứng |
|---|---|---|
| Fixture validation | Đạt | 12 bar, 0 error, warning `synthetic_dataset` |
| Python exporter | Đã chạy | 12 dòng: 1 BUY, 1 SELL, 7 HOLD, 3 UNKNOWN |
| Comparator | Đã test | 79 Python test pass; self-comparison 12/12 match; negative test báo 3 mismatch theo timestamp/field |
| MQL5 exporter compile | Đạt | 0 errors, 0 warnings; `.ex5` được tạo |
| MQL5 exporter runtime | **Chưa chạy** | Cần thao tác thủ công mục 3.2 |
| Parity thực tế MQL5/Python | **Chưa xác lập** | Chưa có `parity_signals_mql5.csv` thật |

Self-comparison chỉ chứng minh comparator và Python exporter ổn định; **không phải** bằng chứng MQL5 và
Python tương đương. Không đánh dấu parity `DONE` cho đến khi chạy mục 3.2–3.3 và ghi kết quả thật.

## 7. Khi có mismatch

1. Mở `mismatch_report.csv`; lọc theo `timestamp`, `symbol`, `timeframe`.
2. Kiểm tra `field`: text mismatch → so input/config và logic; numeric mismatch → kiểm tra window, seed,
   rounding và dữ liệu đầu vào.
3. Xác nhận hai file có cùng số hàng và cùng key; thiếu hàng là lỗi exporter, không phải tolerance.
4. Ghi mismatch vào báo cáo phase; không sửa fixture để làm mismatch biến mất nếu fixture vẫn hợp lệ.
5. Chỉ tuyên bố parity khi report có `status=match`, `rows_compared` bằng số bar của fixture và
   `mismatch_count=0`.
