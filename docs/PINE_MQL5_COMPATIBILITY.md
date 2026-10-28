# Pine ↔ MQL5 compatibility — Wonderwhales

Tài liệu này liệt kê các khác biệt đã biết giữa Pine gốc và bản MQL5 trong repo. Không có khác biệt nào
được coi là "đã kiểm chứng runtime" nếu chưa có log/CSV thật.

- **Pine nguồn:** `D:\Applications\tm-trading\pine\dist\Wonderwhales.pine` (read-only).
- **Chiến lược tham chiếu:** `Wonderwhales Backtest.pine` (chỉ đọc để hiểu execution; **không port**).
- **MQL5:** `mt5/Indicators/PinePort/Wonderwhales.mq5`, `mt5/Experts/PineSignalLabEA.mq5`.
- **Contract:** [`BUFFER_CONTRACT_Wonderwhales.md`](BUFFER_CONTRACT_Wonderwhales.md).

## 1. Bảng khác biệt

| # | Chủ đề | Pine | MQL5 | Ảnh hưởng | Trạng thái |
|---|---|---|---|---|---|
| D1 | PSAR | `ta.sar(start, inc, max)` | `iSAR(symbol, tf, step, max)` | Giá trị có thể lệch ở bar đầu | Chấp nhận; so từ warm-up |
| D2 | EMA seed | Seed bằng giá trị đầu | `iMA(MODE_EMA)` seed khác | Lệch nhỏ tắt dần | Warm-up 300 bar |
| D3 | ATR | Wilder/RMA | `iATR` Wilder | Có thể lệch vài bar đầu | Warm-up |
| D4 | RSI | Wilder | `iRSI` Wilder | Display-only | Không chặn tín hiệu |
| D5 | Bollinger | SMA + population stdev | `iBands` | Display-only | Không chặn tín hiệu |
| D6 | Volume | `volume` của sàn | `tick_volume` | VSA chỉ hiển thị, không gate | Ghi rõ |
| D7 | Fill timing | `process_orders_on_close` | Không có execution | Không port | N/A |
| D8 | Sizing | Equity / close | Không có execution | Không port | N/A |
| D9 | Intrabar SL/TP | Broker emulator | Không có execution | Không port | N/A |
| D10 | Ladder | 2 entry cùng bar, `pyramiding=0` | Không có execution | Hai lỗi Pine đã biết | Không port |
| D11 | Reversal | `strategy.close("Long")` | Không có execution | Không port | N/A |
| D12 | Commission | 0.05%/chiều | Không có execution | Không port | N/A |
| D13 | Timezone | UTC/exchange | Server time broker | Ảnh hưởng timestamp CSV | Chuẩn hóa UTC khi so |
| D14 | History | `max_bars_back=1000` | History terminal | Có thể thiếu bar | Kiểm tra `BarsCalculated` |
| D15 | Alerts | `freq_once_per_bar_close` | Không có alert native | Không port | EA chống trùng theo bar |
| D16 | `confirmOnClose=false` | Marker bật/tắt trong nến | **Không port** | Tránh repaint không kiểm chứng | Chỉ hỗ trợ confirmed |
| D17 | Render | Chart window, nhiều plot | 3 plot + 15 buffer ẩn | Khác giao diện | Chấp nhận |
| D18 | Volume SMA | `ta.sma(volume, len)` | Tự cộng `tick_volume` | Display-only | Chấp nhận |

## 2. Điểm giữ nguyên có chủ đích

- `sar_dir`: PSAR `< close` là bull; `== close` là bear (so sánh nghiêm ngặt).
- Flip chỉ khi `dir` đổi từ `-1` sang `1` hoặc ngược lại; `dir_prev = 0` không tạo flip.
- EMA cross dùng `prev <=` và `now >` (cross up), `prev >=` và `now <` (cross down).
- Mode gate:
  - `SAR`: raw flip.
  - `EMA`: EMA cross.
  - `SAR_EMA`: flip + EMA trend cùng chiều.
  - `SAR_EMA_ATR`: flip + EMA trend + `atr_pct >= min_atr_pct`.
- Tín hiệu chỉ phát trên nến đã đóng; buffer tín hiệu tại nến đang chạy = 0.
- `blocked` là chẩn đoán, không phải tín hiệu.
- Missing value: PSAR/EMA/RSI/BB/Volume MA = `EMPTY_VALUE`; ATR%/Volume ratio = `0.0`.

## 3. Khác biệt về dữ liệu và độ chính xác

- EA ghi `psar`, `fast`, `slow` với 8 chữ số thập phân; `atr_pct` với 10 chữ số.
- Pine export có thể dùng độ chính xác đầy đủ; comparator mặc định `1e-8` cho giá và `1e-6` cho ATR%.
- Nếu broker dùng ít chữ số hoặc giá trị PSAR được làm tròn theo tick, tolerance cần ghi rõ trong báo cáo.
- Volume khác nguồn (tick vs real) có thể làm `VOL_RATIO` khác; trường này không tham gia tín hiệu.

## 4. Điều chưa được kiểm chứng

| Hạng mục | Trạng thái |
|---|---|
| 36 test vector hợp đồng | Đã compile; **chưa chạy** |
| Indicator trong MT5 (buffer, iCustom) | **Chưa chạy** |
| EA runtime (log, CSV, dedupe) | **Chưa chạy** |
| Strategy Tester / backtest | **Chưa chạy**; không có execution |
| Parity Pine-vs-MQL5 | `BLOCKED` — thiếu CSV reference |
| Hành vi Pine runtime E1–E8 | `PENDING` |

## 5. Quy tắc cập nhật

Khi phát hiện khác biệt mới:

1. Thêm dòng vào bảng trên với ID tiếp theo.
2. Ghi rõ ảnh hưởng tới tín hiệu hay chỉ hiển thị.
3. Nếu ảnh hưởng tín hiệu, cập nhật contract và test vector trước khi sửa code.
4. Không nới tolerance hoặc sửa Pine để che khác biệt.
