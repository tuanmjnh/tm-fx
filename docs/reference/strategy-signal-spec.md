# Đặc tả chiến lược và tín hiệu — baseline EMA crossover

- **Phạm vi:** Phase 2, cập nhật ở Phase 5. Chỉ mô tả quy tắc tín hiệu; **không** mô tả hay triển khai
  thực thi lệnh.
- **Mục đích:** baseline minh họa để kiểm tra tính tất định và tách biệt indicator/signal. Không ngụ ý
  chiến lược có lợi nhuận.
- **Mã nguồn:** `mt5/Include/Indicators.mqh`, `mt5/Include/SignalEngine.mqh`.
- **Kiểm thử:** `mt5/Scripts/LabSignalEngineTests.mq5`.

## 1. Hợp đồng dữ liệu đầu vào

- Hàm indicator nhận mảng **chronological** (index 0 = nến cũ nhất, index cuối = nến mới nhất).
- Signal engine chỉ nhận **nến đã đóng**. Nến đang hình thành không được đưa vào mảng.
- EA lấy dữ liệu bằng `CopyRates(_Symbol,_Period,1,needed,...)`: shift `1` đảm bảo không lấy nến hiện tại.
- **Cửa sổ baseline:** EA truyền đúng `slow_period + 1` nến đóng gần nhất. Vì vậy EMA trong EA là EMA
  trên cửa sổ cuộn, seed lại bằng SMA ở đầu mỗi cửa sổ; đây là quy ước của baseline, không phải EMA mặc
  định của MT5. Python `generate_signals` dùng cùng cửa sổ cuộn.
- Mọi giá phải hữu hạn và `> 0`; nếu không, indicator trả `false` và engine trả `UNKNOWN` thay vì tạo
  tín hiệu.

## 2. Indicator

### SMA

```
SMA[t] = mean(price[t-period+1 .. t])
```

- Trả `false` nếu `period <= 0` hoặc `count < period`.
- Các index `< period-1` trong mảng output bằng `0` và không được dùng.

### EMA

Seed bằng SMA của `period` giá trị đầu tiên, sau đó:

```
alpha  = 2 / (period + 1)
EMA[period-1] = SMA(price[0 .. period-1])
EMA[t] = alpha * price[t] + (1 - alpha) * EMA[t-1]     với t >= period
```

- Trả `false` nếu `period <= 0`, `count < period`, hoặc có giá không hợp lệ.
- Các index `< period-1` trong mảng output bằng `0` và không được dùng.

## 3. Quy tắc tín hiệu

Cấu hình:

| Trường | Ý nghĩa | Ràng buộc |
|---|---|---|
| `fast_period` | Chu kỳ EMA nhanh | `> 0` |
| `slow_period` | Chu kỳ EMA chậm | `> fast_period` |
| `allow_long` | Cho phép BUY | bool |
| `allow_short` | Cho phép SELL | bool |

Warm-up: cần tối thiểu `slow_period + 1` nến đóng, vì crossover cần EMA nhanh/chậm trên **hai** nến liên
tiếp (`t-1` và `t`).

Tại nến đóng cuối cùng `t`:

| Điều kiện | Kết quả | Reason |
|---|---|---|
| `fast[t-1] <= slow[t-1]` và `fast[t] > slow[t]` | `BUY` nếu `allow_long`, ngược lại `HOLD` | `OK` / `LONG_DISABLED` |
| `fast[t-1] >= slow[t-1]` và `fast[t] < slow[t]` | `SELL` nếu `allow_short`, ngược lại `HOLD` | `OK` / `SHORT_DISABLED` |
| Các trường hợp còn lại | `HOLD` | `NO_CROSS` |
| Không đủ lịch sử | `UNKNOWN` | `INSUFFICIENT_HISTORY` |
| Config sai | `UNKNOWN` | `INVALID_CONFIG` |
| Giá không hữu hạn/`<= 0` | `UNKNOWN` | `INDICATOR_FAILED` |
| Giá trị EMA truyền vào hàm crossover không hợp lệ | `UNKNOWN` | `INVALID_INPUT` |

Điểm quan trọng:

- **`HOLD` khác `UNKNOWN`.** `HOLD` là quyết định hợp lệ sau khi đã tính đủ indicator. `UNKNOWN` là
  không thể đưa ra quyết định do thiếu dữ liệu/config sai/dữ liệu bẩn.
- Không có look-ahead: tín hiệu tại `t` chỉ dùng `t-1` và `t`; EA chỉ gọi sau khi nến `t` đã đóng.
- Tín hiệu không phụ thuộc và không kích hoạt bất kỳ API giao dịch nào.

## 4. Fixture và expected output

Các giá trị dưới đây đã được tính độc lập bằng Python (cùng công thức seed SMA) và được hard-code trong
`LabSignalEngineTests.mq5`. Dung sai so sánh `1e-9`.

> **Cửa sổ fixture:** các fixture dưới đây có đúng `slow_period + 1 = 4` giá, tương đương cửa sổ mà EA
> truyền vào signal engine. Đây là expected value theo cùng công thức; parity runtime MQL5/Python vẫn
> phải được kiểm chứng bằng export thật (xem mục 5).

### 4.1 Indicator

| Input | Period | Expected |
|---|---|---|
| `[1,2,3,4,5]` | SMA 3 | `out[2]=2`, `out[3]=3`, `out[4]=4` |
| `[1,2,3,4,5]` | EMA 3 | `out[2]=2`, `out[3]=3`, `out[4]=4` |
| `[1,2,3]` | EMA 5 | `false` (thiếu dữ liệu) |
| `[1,0,2]` | EMA 2 | `false` (giá không hợp lệ) |

### 4.2 EMA crossover (fast=2, slow=3)

**BUY — `[1.10,1.09,1.05,1.12]` (4 nến):**

| Giá trị | Kết quả |
|---|---|
| `fast[t-1]` | `1.065` |
| `slow[t-1]` | `1.08` |
| `fast[t]` | `1.101666666667` |
| `slow[t]` | `1.10` |
| Signal | `BUY` |
| Reason | `OK` |

**SELL — `[1.05,1.06,1.12,1.00]` (4 nến):**

| Giá trị | Kết quả |
|---|---|
| `fast[t-1]` | `1.098333333333` |
| `slow[t-1]` | `1.076666666667` |
| `fast[t]` | `1.032777777778` |
| `slow[t]` | `1.038333333333` |
| Signal | `SELL` |
| Reason | `OK` |

**HOLD — `[1.10,1.09,1.08,1.07]` (4 nến):** `fast` và `slow` đều giảm, `fast < slow` ở cả hai nến →
`HOLD`, reason `NO_CROSS`.

**Case biên:**

| Case | Expected |
|---|---|
| `[1.10,1.09,1.05]` (3 nến), slow=3 | `UNKNOWN` / `INSUFFICIENT_HISTORY` |
| fast=3, slow=3 | `UNKNOWN` / `INVALID_CONFIG` |
| `[1.10,1.09,1.05,0.0]` | `UNKNOWN` / `INDICATOR_FAILED` |
| BUY cross với `allow_long=false` | `HOLD` / `LONG_DISABLED` |
| SELL cross với `allow_short=false` | `HOLD` / `SHORT_DISABLED` |
| Cùng input gọi hai lần | Cùng signal/reason/giá trị |

## 5. Parity MQL5/Python

- Fixture chung: `datasets/samples/parity_ema_cross.csv` (12 nến M5 synthetic, fast=2, slow=3). Kỳ vọng:
  3 `UNKNOWN`, 7 `HOLD`, 1 `BUY` tại 00:25, 1 `SELL` tại 00:45.
- MQL5 export: `mt5/Scripts/LabSignalExport.mq5`, đọc CSV từ `Common\Files` và đánh giá lại cửa sổ cuộn
  `slow_period + 1` cho từng bar.
- Python export: `scripts/export_python_signals.py`.
- So sánh: `scripts/compare_signals.py`; logic nằm trong
  `python/src/mt5_ea_ai_lab/evaluation/parity.py`. Text (`signal`, `reason`) so sánh chính xác; EMA dùng
  tolerance tuyệt đối `1e-9`; thiếu hàng/duplicate key là lỗi input.
- MQL5 export mới chỉ **compile** 0 errors/0 warnings, **chưa chạy** trong terminal. Chưa có kết luận
  tương đương MQL5/Python. Quy trình thủ công và trạng thái xác minh: [`parity.md`](parity.md).

## 6. Cách chạy kiểm thử

Script `mt5/Scripts/LabSignalEngineTests.mq5` chạy một lần trên chart và in kết quả:

```
TEST|PASS|engine_buy_signal
...
TEST|SUMMARY|pass=N fail=0
TEST|RESULT|ALL_PASS
```

Agent chỉ xác minh **compile** (0 errors, 0 warnings). Script **chưa được chạy** trong terminal; cần chạy
thủ công và đọc log thật trước khi coi Phase 2 là `DONE`.

## 7. Giới hạn

- Baseline chỉ dùng EMA crossover; không có stop/target, không có position sizing, không có execution.
- Chưa mô hình hóa spread/slippage/commission trong tín hiệu (thuộc backtester Phase 4).
- EMA seed bằng SMA là lựa chọn có chủ đích để tất định và dễ đối chiếu; không nhất thiết khớp EMA mặc
  định của MT5.
- Chưa xử lý symbol/timeframe thay đổi giữa chừng.
