# Parity Pine vs MQL5 cho PinePort

> Tài liệu tổng hợp, giữ nguyên nội dung gốc; tiêu đề đã hạ một cấp để thống nhất một cây tài liệu. Nguồn: `PINE_PARITY_Wonderwhales.md`, `PINE_PARITY_MULTI_SOURCE.md`.

Nội dung:
1. Pine ↔ MQL5 parity — Wonderwhales
2. Pine ↔ MQL5 parity — multi-source EA

---
## Pine ↔ MQL5 parity — Wonderwhales

- **Trạng thái:** comparator và unit test `PASS`; parity dữ liệu thật `BLOCKED`.
- **Lý do `BLOCKED`:** chưa có CSV reference do chính Pine xuất trên cùng symbol/timeframe/input.
  Không được tạo CSV giả để thay thế.
- **Phạm vi so sánh:** tín hiệu đã đóng nến (signal-only), không so execution/backtest.

### 1. Hai nguồn dữ liệu

| Nguồn | File | Cách tạo |
|---|---|---|
| Pine | CSV reference | Xuất từ TradingView sau khi chạy indicator với input đã chốt |
| MQL5 | `MQL5/Files/pine_signal_log.csv` | `PineSignalLabEA` ghi khi có tín hiệu mới |

Comparator không đọc Pine source, không chạy TradingView và không sửa một trong hai file.

### 2. Schema CSV

Cột bắt buộc:

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `bar_open_time` | ISO-8601 UTC | Khóa chính cùng symbol/timeframe; ví dụ `2026-01-05T10:00:00Z` |
| `symbol` | text | Phải khớp chính xác, ví dụ `EURUSD` |
| `timeframe` | text | `M1`…`H12`, `D1`, `W1`, `MN1`; chấp nhận cả `PERIOD_M5` |
| `signal_id` | text | Một trong 8 ID ở mục 3 |
| `side` | text | `BUY` hoặc `SELL`, phải khớp `signal_id` |
| `sar_dir` | int | `1` cho BUY, `-1` cho SELL |
| `psar` | float | Có thể để trống nếu cả hai phía đều trống |
| `fast` | float | EMA nhanh tại nến tín hiệu |
| `slow` | float | EMA chậm tại nến tín hiệu |
| `atr_pct` | float | ATR/close × 100 |

Cột tùy chọn:

| Cột | Kiểu | Hành vi |
|---|---|---|
| `confirmed_at` | ISO-8601 UTC | Nếu có, comparator kiểm tra `bar_open_time + timeframe` cho M1–H12 |
| `input_hash` | text | Nếu cả hai file đều có, so khớp chính xác |
| `mode` | text | Được giữ lại nhưng không so sánh (Pine và EA dùng tên khác nhau) |
| `detected_at` | ISO-8601 UTC | Không so sánh; chỉ là thời điểm ghi log |

Thứ tự cột không quan trọng. Dòng trống bị bỏ qua. Khóa trùng là lỗi.

EA ghi `bar_open_time`/`confirmed_at` bằng giờ server broker, định dạng `YYYY.MM.DD HH:MM:SS`.
Comparator parse cả định dạng này và ISO-8601, sau đó trừ `--mql5-offset-minutes` để về UTC trước khi
ghép khóa. Pine export phải là UTC; nếu không, dùng `--pine-offset-minutes`.

### 3. Signal ID

| Mode | BUY | SELL |
|---|---|---|
| `SAR` | `WW_BUY_SAR_FLIP` | `WW_SELL_SAR_FLIP` |
| `EMA` | `WW_BUY_EMA_CROSS` | `WW_SELL_EMA_CROSS` |
| `SAR_EMA` | `WW_BUY_SAR_EMA` | `WW_SELL_SAR_EMA` |
| `SAR_EMA_ATR` | `WW_BUY_SAR_EMA_ATR` | `WW_SELL_SAR_EMA_ATR` |

`BLOCKED_FILTER` không phải tín hiệu và không xuất hiện trong CSV của EA.

### 4. Quy tắc so sánh

- Khóa: `(bar_open_time, symbol, timeframe)` sau khi chuẩn hóa UTC; thứ tự dòng không ảnh hưởng.
- `signal_id`, `side`, `sar_dir`: so khớp chính xác.
- `psar`, `fast`, `slow`: sai số tuyệt đối, mặc định `1e-8`. EA ghi 8 chữ số thập phân.
- `atr_pct`: sai số tuyệt đối, mặc định `1e-6`. EA ghi 10 chữ số thập phân.
- Một phía trống, phía kia có số → `nan_mismatch`.
- Cả hai trống → bỏ qua, không tính mismatch.
- Thiếu dòng ở MQL5 → `missing_in_mql5`; thiếu ở Pine → `missing_in_pine`.

Sai số tuyệt đối được dùng vì giá trị là giá/oscillator, không phải tỷ lệ. Với symbol 5 chữ số, sai
khác làm tròn của broker có thể vượt `1e-8`; khi đó ghi rõ tolerance đã dùng trong báo cáo, không tự
nới tolerance để che lỗi logic.

### 5. Warm-up và khoảng so sánh

Contract đề xuất bắt đầu so từ bar 300 để tránh seed EMA/ATR/RSI/BB khác nhau. Hai cách:

- `--start 2026-01-05T10:00:00Z`: bỏ mọi dòng trước mốc này ở cả hai file.
- `--warmup-bars 300 --bar-times bars.csv`: bỏ 300 bar đầu tiên trong timeline. `bars.csv` chỉ cần cột
  `bar_open_time`, có thể lấy từ dataset đã dùng để chạy Pine.

Không dùng `--warmup-bars` khi chỉ có file tín hiệu thưa, vì không thể suy ra 300 bar từ vài dòng tín hiệu.

### 6. Lệnh

```powershell
.venv\Scripts\python.exe scripts\compare_pine_exports.py `
  --pine reports\pine_parity\pine_reference.csv `
  --mql5 "$env:APPDATA\MetaQuotes\Terminal\<hash>\MQL5\Files\pine_signal_log.csv" `
  --out-dir reports\pine_parity `
  --mql5-offset-minutes 180
```

`--mql5-offset-minutes` là độ lệch server broker so với UTC, tính theo phút và theo hướng đông
(GMT+3 = `180`, GMT+2 = `120`). EA ghi giờ server; comparator trừ offset để về UTC. Nếu bỏ qua, giá trị
mặc định là `0` và mọi timestamp MQL5 được coi là UTC — chỉ đúng khi server chạy UTC.

Ví dụ có warm-up:

```powershell
.venv\Scripts\python.exe scripts\compare_pine_exports.py `
  --pine reports\pine_parity\pine_reference.csv `
  --mql5 reports\pine_parity\pine_signal_log.csv `
  --warmup-bars 300 --bar-times reports\pine_parity\bars.csv `
  --tolerance-price 1e-8 --tolerance-oscillator 1e-6 `
  --mql5-offset-minutes 180
```

Exit code:

| Code | Ý nghĩa |
|---|---|
| `0` | Tất cả dòng khớp |
| `1` | Có ít nhất một mismatch |
| `2` | File/argument không hợp lệ (schema, timestamp, khóa trùng, filter rỗng) |

Output: `pine_mismatch_report.json` và `pine_mismatch_report.csv` trong `--out-dir`.

### 7. Unit test

```powershell
.venv\Scripts\python.exe -m pytest python\tests\test_pine_parity.py -q
```

Test dùng CSV tổng hợp trong `tmp_path` để kiểm tra comparator: khớp, thiếu/thừa dòng, lệch ID/side/
direction, tolerance, NaN, hash, filter, warm-up, timestamp sai, khóa trùng, thiếu cột, file rỗng.
**Đây không phải bằng chứng parity Pine-MQL5.**

### 8. Giới hạn đã biết

1. Không tự động xuất CSV từ TradingView; người dùng phải export và đặt file đúng schema.
2. `confirmed_at` chỉ kiểm tra M1–H12; D1/W1/MN1 bị bỏ qua vì session gap.
3. EA chỉ ghi tín hiệu, không ghi mọi bar; comparator không đối chiếu PSAR/EMA/RSI/BB trên toàn chuỗi.
4. `detected_at` phụ thuộc tick và không được so sánh.
5. EA ghi giờ server broker (định dạng `YYYY.MM.DD HH:MM:SS`); phải truyền `--mql5-offset-minutes`
   đúng. Offset có thể đổi theo DST; nếu khoảng test đi qua mốc đổi giờ, chia run hoặc kiểm tra lại offset.
   Pine export phải là UTC; nếu không, dùng `--pine-offset-minutes`.
6. Symbol/timeframe chuẩn vẫn chưa chốt; parity thật cần chốt trước khi chạy.
7. Không có kết quả parity thật cho đến khi có reference CSV; mọi báo cáo phải ghi `BLOCKED`, không
   được suy ra từ unit test.

### 9. Checklist trước khi chạy parity thật

- [ ] Chốt symbol, timeframe, khoảng ngày và toàn bộ 13 input.
- [ ] Chạy indicator Pine trên TradingView với đúng input; export tín hiệu.
- [ ] Chuẩn hóa timestamp về UTC, xác định offset server và kiểm tra `confirmed_at`.
- [ ] Chạy `PineSignalLabEA` trên cùng symbol/timeframe/input trong MT5.
- [ ] Xác nhận EA dùng đúng indicator `PinePort\Wonderwhales` và đọc `shift=1`.
- [ ] Chạy comparator với `--start` hoặc `--warmup-bars` sau warm-up.
- [ ] Lưu JSON/CSV report và ghi số mismatch, mẫu timestamp, max absolute error.
- [ ] Nếu mismatch, phân loại: dữ liệu, seed indicator, làm tròn, thiếu bar, hay lỗi logic.

## Pine ↔ MQL5 parity — multi-source EA

- **Trạng thái:** comparator và 21 unit test `PASS`; parity dữ liệu thật `BLOCKED`.
- **Lý do `BLOCKED`:** chưa có CSV reference do chính Pine xuất trên cùng symbol/timeframe/input cho
  sáu indicator. Không được tạo CSV giả để thay thế.
- **Phạm vi:** tín hiệu đã đóng nến do `PineMultiSignalLabEA` ghi; không so execution/backtest.

### 1. Hai nguồn dữ liệu

| Nguồn | File | Cách tạo |
|---|---|---|
| Pine | CSV reference | Xuất từ TradingView với đúng symbol/timeframe/input đã chốt |
| MQL5 | `MQL5/Files/pine_multi_signal_log.csv` | EA ghi khi một nguồn có tín hiệu mới |

Comparator chỉ đọc hai CSV; không đọc Pine source, không chạy TradingView, không sửa file.

### 2. Schema

Cột bắt buộc (thứ tự không quan trọng):

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `source` | text | Một trong 6 tên ở mục 3, phân biệt hoa thường |
| `bar_open_time` | ISO-8601 UTC | Khóa chính cùng `source`/`symbol`/`timeframe` |
| `symbol` | text | Khớp chính xác |
| `timeframe` | text | `M1`…`H12`, `D1`… hoặc `PERIOD_M5` |
| `signal_id` | text | So khớp chính xác |
| `side` | text | `BUY` hoặc `SELL` |
| `dir` | int | So khớp chính xác |
| `score` | float | Có thể trống; trống hai phía được coi là bằng nhau |
| `entry`, `sl`, `tp1`, `tp2`, `tp3` | float | Có thể trống; sai số tuyệt đối |

Cột tùy chọn:

| Cột | Hành vi |
|---|---|
| `confirmed_at` | Nếu có giá trị, kiểm tra `bar_open_time + timeframe` cho M1–H12 |
| `contract_version`, `reason`, `input_hash` | Chỉ so khớp khi **cả hai** file đều có cột |
| `detected_at` | Không so sánh; chỉ là thời điểm ghi log |

Dòng trống bị bỏ qua. Khóa `(source, bar_open_time, symbol, timeframe)` trùng là lỗi.

EA ghi `bar_open_time`/`confirmed_at` bằng giờ server broker, định dạng `YYYY.MM.DD HH:MM:SS`.
Comparator parse cả định dạng đó và ISO-8601, sau đó trừ `--mql5-offset-minutes` để về UTC.
Pine export phải là UTC; nếu không, dùng `--reference-offset-minutes`.

### 3. Tên nguồn

`Wonderwhales`, `LongKacoVSA`, `TMFusionZones`, `PriceActionMTF`, `TMXAUSignals2`, `TMIndicator2`.

Tên khác bị từ chối để tránh so nhầm file của EA khác.

### 4. Quy tắc so sánh

- Khóa ghép ngoài (outer join): dòng chỉ có ở reference → `missing_in_mql5`; chỉ có ở MQL5 →
  `missing_in_reference`.
- `signal_id`, `side`, `dir`: so khớp chính xác.
- `score`: sai số tuyệt đối, mặc định `1e-6`.
- `entry`, `sl`, `tp1`–`tp3`: sai số tuyệt đối, mặc định `1e-8`.
- Một phía trống, phía kia có số → `nan_mismatch`. Cả hai trống → bỏ qua.
- Lệch số → `value_mismatch` kèm `difference = reference - mql5`.

### 5. Chạy

```bash
.venv/Scripts/python.exe scripts/compare_multi_signal_exports.py \
  --reference tests/fixtures/<pine-export>.csv \
  --mql5 "C:/Users/<user>/AppData/Roaming/MetaQuotes/Terminal/<id>/MQL5/Files/pine_multi_signal_log.csv" \
  --mql5-offset-minutes 180 \
  --out-dir reports/multi_source_parity
```

Exit codes:

| Code | Ý nghĩa |
|---|---|
| 0 | `match` — mọi tín hiệu khớp |
| 1 | `mismatch` — có ít nhất một khác biệt |
| 2 | File/schema/đối số không hợp lệ |
| 3 | `BLOCKED` — thiếu một trong hai file; không tạo dữ liệu giả |

### 6. Báo cáo

- `reports/multi_source_parity/multi_source_parity.json`: trạng thái, số dòng, tolerance, offset, tổng
  hợp theo từng nguồn và danh sách mismatch.
- `reports/multi_source_parity/multi_source_parity_mismatches.csv`: cùng danh sách mismatch dạng bảng.

Mỗi nguồn có `reference_rows`, `mql5_rows`, `compared_rows`, `mismatch_count` để biết nguồn nào lệch.

### 7. Chưa làm

| Hạng mục | Trạng thái |
|---|---|
| CSV reference thật từ Pine | `BLOCKED` — người dùng phải xuất và đặt vào `tests/fixtures/` |
| Chạy comparator trên dữ liệu thật | `NOT_RUN` |
| Chạy EA trong terminal để sinh CSV MQL5 | `NOT_RUN` |
| Diễn giải warm-up/repaint/intrabar | Chưa có dữ liệu để phân tích |

Unit test dùng fixture tổng hợp chỉ để kiểm tra comparator, **không** phải bằng chứng parity.
