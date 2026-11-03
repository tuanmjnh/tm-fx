# Hướng dẫn cho người mới: chạy bot EA đầu tiên và xem bot vận hành

**Dành cho:** người chưa từng mở MetaTrader 5 (MT5) hoặc chưa từng chạy Expert Advisor (EA).
**Thời gian dự kiến:** 30–60 phút cho Phần 3 + Phần 4 (lần chạy đầu tiên).
**Máy tham chiếu:** Windows, MT5 EXNESS build 6292, repo ở `D:\Applications\tm-fx`.
Nếu máy bạn khác, chỉ cần thay 3 đường dẫn ở §2.4 — mọi bước còn lại giống nhau.

> **An toàn trước khi đọc tiếp (đọc thật kỹ, 30 giây)**
> - Bot trong hướng dẫn này là **bot mô phỏng** (`PinePlanSimEA`): nó tự ghi sổ lệnh ảo, **không gửi
>   lệnh thật, không đụng tiền thật**. Chuỗi log luôn có dòng
>   `LAB|INFO|plan|simulation_only|no_orders_are_sent`.
> - Muốn bot gửi lệnh thật thì **chỉ** được dùng tài khoản **demo** (tiền giả của sàn) và **chỉ** EA
>   `PATrendRiderXAUv1DemoEA` (Phần 6). **Tài khoản real/live bị cấm hoàn toàn** theo
>   [`../decisions/0003-demo-execution-scope.md`](../decisions/0003-demo-execution-scope.md).
> - Không có hướng dẫn nào ở đây chứng minh bot "có lãi". Mọi số liệu trong repo đều là **đơn vị mô
>   hình**; trạng thái lợi nhuận của mọi chiến lược là `UNPROVEN`
>   ([`../v2/EVIDENCE.md`](../v2/EVIDENCE.md) §2.5).

---

## 1. Năm khái niệm đủ để bắt đầu

| Khái niệm | Nghĩa thật đơn giản | Bạn gặp nó ở đâu |
|---|---|---|
| **MT5 / terminal** | Phần mềm xem biểu đồ giá và kết nối sàn. Đây là "cửa sổ chính". | `terminal64.exe` |
| **Chart / Symbol / Timeframe** | Biểu đồ của một món hàng (`XAUUSDm` = vàng quy đổi ra USD) theo một bước thời gian (`M15` nghĩa là mỗi nến tổng kết 15 phút). | Cửa sổ chart, góc trên trái |
| **EA (Expert Advisor)** | Con bot: đoạn code chạy mỗi khi có nến/tick mới, tự quyết định "mở vị thế ảo / đóng / bỏ qua". | Navigator → Expert Advisors |
| **Strategy Tester** | Máy thời gian: cho bot chạy lại quá khứ, nhanh hơn nhiều lần, có ô "Visual mode" để **xem nến chạy và xem bot hành động**. | `Ctrl+R` |
| **Journal / CSV** | "Sách kế toán" của bot. Tab *Journal* (hoặc *Experts*) ghi log từng dòng; bot còn ghi file CSV chứa mọi quyết định. | Toolbox (dưới cùng) và `MQL5\Files` |

Ba cửa sổ bạn sẽ dùng nhiều:

```text
+--------------------------------------------+
|  Menu / toolbar (có nút "Algo Trading")    |
+------------------+-------------------------+
|                  |                         |
|   CHART          |   Navigator (Ctrl+N)    |
|   (biểu đồ)      |   - Indicators          |
|                  |   - Expert Advisors     |
+------------------+-------------------------+
|  TOOLBOX (Ctrl+T): Journal | Experts | Tester ...
+--------------------------------------------+
```

---

## 2. Chuẩn bị một lần (khoảng 10 phút)

### 2.1 Mở MT5

Chạy `C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe`. Nếu MetaEditor (trình soạn code,
`MetaEditor64.exe`) mở cùng thì cứ đóng nó, không cần thiết cho các bước sau.

### 2.2 Đăng nhập tài khoản **demo** (tiền giả)

1. Menu **File → Open an Account…**
2. Trong danh sách nhà môi giới, chọn **Exness Technologies Ltd** → *Demo* (server có chữ `Trial`).
3. Tạo/đăng nhập một tài khoản demo và đặt mật khẩu **cho riêng bạn** — mình không cần và **không được
   ghi** login/password của bạn vào bất kỳ file nào trong repo.
4. Trên cùng bên phải phải thấy số tài khoản demo + cân bằng ảo (ví dụ `10 000 USD`).

Máy này đang có sẵn tài khoản demo `Exness-MT5Trial17` (số `464140826`), nên bạn cũng có thể chỉ cần
đăng nhập lại tài khoản đó.

**Không** đăng nhập tài khoản real. Repo này cấm, và bot ở Phần 3–5 cũng không dùng tới lệnh thật.

### 2.3 Cho `XAUUSDm` xuất hiện

Bảng **Market Watch** (trái, `Ctrl+M`) → chuột phải → **Show All** → gõ `XAUUSDm` vào ô lọc → chuột
phải `XAUUSDm` → **Chart** (hoặc kéo nó vào vùng chart trống). Đây là biểu đồ bot sẽ nhìn.

### 2.4 Đồng bộ bot + indicator từ repo vào MT5

MT5 không đọc code từ `D:\Applications\tm-fx`; nó đọc từ **Data Folder** của chính nó.

Cách lấy đường dẫn Data Folder: trong MT5, **File → Open Data Folder** → cửa sổ Explorer hiện ra, thư
mục đang mở chính là `<DATA_FOLDER>`. Máy này:

```text
C:\Users\tuanmjnh\AppData\Roaming\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06
```

Mở **PowerShell** (Start → gõ `powershell`) và chạy lần lượt:

```powershell
cd D:\Applications\tm-fx

# 1) Xem trước sẽ copy gì (không ghi gì cả)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1

# 2) Copy thật + compile (tắt MT5 trước khi chạy để tránh file bị khoá)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1 -Apply
```

Kết quả đạt trông như sau (đọc trong log compile, file nằm ở `reports\build\deploy\`):

```text
Result: 0 errors, 0 warnings, ...
```

Nếu bạn thấy `error` khác 0, xem §7.1.

Kiểm tra nhanh bằng mắt: mở Data Folder, vào `MQL5\Experts` phải thấy `PinePlanSimEA.ex5`, và
`MQL5\Indicators\PinePort` phải có `PriceActionMTF.ex5`.

`.ex5` = bản đã biên dịch, là thứ MT5 thật sự chạy; `.mq5` = nguồn.

### 2.5 Làm mới Navigator

Trong MT5: nhấn **F5** khi con trỏ đang ở cửa sổ **Navigator**. Danh sách *Expert Advisors* giờ phải có:

- `PinePlanSimEA` ← **bot chính ta sẽ chạy**
- `WonderwhalesSimEA`, `RunnerTrailingLabEA`, `GridLabEA`, `DCALabEA`, `PATrendRiderXAUv1SimEA` (mô phỏng)
- `PATrendRiderXAUv1DemoEA` (bot demo có gửi lệnh — **chưa đụng tới ở Phần 3–5**)

Nếu không thấy, nghĩa là §2.4 chưa chạy hoặc MT5 đang mở khiến file bị khoá → tắt MT5, chạy lại, mở lại.

---

## 3. Lần chạy đầu: Strategy Tester có hình (bot "mô phỏng" chạy lại quá khứ)

Chọn bot `PinePlanSimEA`: nó đọc một indicator giá (Price Action MTF), tự tạo "kế hoạch vào lệnh"
(entry, stop-loss, take-profit), mô phỏng kết quả và ghi **journal 18 cột** — dễ quan sát nhất cho người mới.

**Vì sao chạy 1 tháng trước, không chạy 9 tháng:** chạy 9 tháng mất ~7 phút và tua hình rất lâu. Một
tháng (2026.09) đủ để bạn thấy bot mở/đóng lệnh vài lần.

| Bước | Thao tác chính xác | Lưu ý |
|---|---|---|
| 3.1 | `Ctrl+R` mở **Strategy Tester** | Tab bên trái Toolbox |
| 3.2 | **Expert** = `PinePlanSimEA` | Nếu danh sách rỗng → về §2.5 |
| 3.3 | **Symbol** = `XAUUSDm`, **Period** = `M15` | Bot mô phỏng vàng; đổi symbol khác sẽ cho số khác |
| 3.4 | **Dates** = `2026.09.01` → `2026.09.30` | Ngày dạng YYYY.MM.DD |
| 3.5 | **Modeling** = `Every tick based on real ticks` | Chậm nhất, sát thực nhất. Repo dùng đúng mode này (report mẫu: `Bars: 17595`, `Ticks: 1053473`) |
| 3.6 | **Deposit** = `10000`, **Currency** = `USD`, **Leverage** = `1:100` | EA tự giữ cân bằng ảo riêng 10 000 trong CSV; ô deposit chỉ là khung của tester |
| 3.7 | **Optimization** = `Disabled` (Single run) | Ta chỉ muốn chạy 1 lần |
| 3.8 | Tab **Inputs**: nhấn **Load** → chọn file `D:\Applications\tm-fx\reports\build\tester-sets\plan_rr2.set` → **Save** | Bước **bắt buộc**, xem mục "Hai cái bẫy" ngay dưới bảng |
| 3.9 | Tích **Visual mode** (chỉ hiện khi Single run) | Đây là ô cho phép *xem* nến chạy |
| 3.10 | **Start** | Nến bắt đầu chạy với các hộp lệnh ảo trên biểu đồ |
| 3.11 | Kéo thanh trượt tốc độ (gần nút Start) để nhanh/chậm | Bạn có thể tạm dừng bằng **Pause** |
| 3.12 | **Stop** khi thấy đủ, hoặc để nó tự chạy hết ngày | |

### Hai cái bẫy khiến bot "im re" (lý do bắt buộc Load file `.set` ở bước 3.8)

1. **`InpPaRr1 = 1.0` mặc định nhỏ hơn `InpPaRrMin = 1.5`** ⇒ mọi kế hoạch bị coi là không hợp lệ, bot
   **0 lệnh** dù bạn chờ bao lâu. Đây là hành vi gốc của indicator nguồn (quirk `Q2`), không phải lỗi.
   File `plan_rr2.set` đặt `InpPaRr1=2.0`, nhờ đó cửa điều kiện mở.
2. **`InpMaxSpreadPoints = 50.0` mặc định** trong khi `XAUUSDm` có spread thật 160–280 points ⇒ bot ghi
   `RISK|ENTRY_BLOCKED` thay vì vào lệnh. `plan_rr2.set` đặt `600.0`.

Bạn có thể kiểm tra bot đã nhận cấu hình đúng chưa ngay khi chạy: trong tab **Journal** của Tester, dòng
đầu tiên của EA phải có `pa_bridge|rr1=2.00|rr_min=1.50`. Ba dòng dưới là nguyên văn chuỗi log EA in ra
lúc khởi động (`mt5\Experts\PinePlanSimEA.mq5:778-784`), với `hash=D6CEF886` là hash của đúng
`plan_rr2.set`:

```text
LAB|INFO|plan|initialized|source=PriceActionMTF|hash=D6CEF886|log=sim_plan_rr2.csv|tester=1
LAB|INFO|plan|pa_bridge|rr1=2.00|rr_min=1.50
LAB|INFO|plan|simulation_only|no_orders_are_sent
```

Dòng cuối là "bảo hiểm" của repo: EA tự tuyên bố không gửi lệnh.

### Điều bạn sẽ thấy trên màn hình (và điều bạn *không* thấy)

- **Thấy**: nến chạy từ trái sang phải; trên vài nến xuất hiện nhãn/marker `BUY`; khi đủ điều kiện thì
  vị thế đóng và bot bắt đầu tìm kế hoạch mới.
- **Không thấy**: tab **Results** sẽ hiện `Deals: 0`, `Total Net Profit: 0.00`, đường equity **phẳng**.
  Đây là **đúng**, không phải lỗi: vị thế của bot mô phỏng chỉ tồn tại trong đầu bot và trong file CSV
  của nó, MT5 không nhận lệnh nào nên không có deal. Bằng chứng thật nằm ở Phần 4.

Nếu bạn thấy kết quả tester "0 lệnh" nhưng CSV có dòng `ENTRY` → bạn đang đọc đúng chỗ.

---

## 4. Đọc "sách kế toán" của bot (CSV 18 cột) — phần lý thú nhất

### 4.1 File nằm ở đâu

| Bạn chạy ở đâu | File CSV sinh ra ở |
|---|---|
| Strategy Tester | `C:\Users\tuanmjnh\AppData\Roaming\MetaQuotes\Tester\53785E099C927DB68A545C249CDBCE06\Agent-127.0.0.1-3000\MQL5\Files\sim_plan_rr2.csv` |
| Gắn EA lên chart (Phần 5) | `<DATA_FOLDER>\MQL5\Files\sim_plan_log.csv` (mặc định) |
| Bản mẫu đã lưu trong repo (dùng để thực hành §4.5) | `D:\Applications\tm-fx\reports\build\tester-reports\plan_rr2\sim_plan_rr2.csv` |

Cách chung không cần thuộc đường dẫn: **File → Open Data Folder** rồi vào `MQL5\Files`.
(Riêng Tester là "Data Folder tạm" của agent; dễ nhất là mở Explorer, dán đường dẫn ở bảng trên.)

Tên file do input `InpLogFile` quyết định (`plan_rr2.set` đặt là `sim_plan_rr2.csv` để không ghi đè
lần chạy trước).

### 4.2 18 cột nghĩa là gì

Header thật (dòng 1 của file):

```text
logged_at,bar_time,ea,version,config_hash,symbol,timeframe,event,side,price,volume,entry,sl,tp,exposure,equity,drawdown_pct,reason
```

| Cột | Nghĩa |
|---|---|
| `logged_at` | Thời điểm bot ghi dòng này (theo giờ server) |
| `bar_time` | Nến mà quyết định áp dụng; `INIT` dùng epoch `1970.01.01` vì không gắn nến nào |
| `ea` / `version` | `PinePlanSimEA` / `1.00` |
| `config_hash` | "vân tay" của toàn bộ input. **Cả file phải cùng một hash**; đổi input = đổi hash |
| `symbol` / `timeframe` | `XAUUSDm` / `PERIOD_M15` |
| `event` | `INIT` khởi động · `ENTRY` mở vị thế ảo · `EXIT` đóng · `RISK` bị cổng rủi ro chặn · `SUMMARY` tổng kết cuối run |
| `side` | `BUY` / `SELL` / `NONE` |
| `price` | Giá khớp lệnh (entry của nến đóng lệnh với `EXIT`) |
| `volume` | Khối lượng ảo (`InpVolume`, ở đây 1.0) |
| `entry`/`sl`/`tp` | Giá vào / cắt lỗ / chốt lãi của kế hoạch |
| `exposure` | Độ hở hiện tại (số vị thế ảo đang mở, theo đơn vị volume) |
| `equity` | Cân bằng ảo sau quyết định |
| `drawdown_pct` | Mực rút lui hiện tại, % |
| `reason` | **Vì sao** — chuỗi token `LABEL\|key=value\|...` |

### 4.3 Đọc ba dòng thật, hiểu bot đang nghĩ gì

Lấy nguyên văn từ lần chạy 9 tháng `plan_rr2` (file `sim_plan_rr2.csv`):

```text
INIT   reason=SIMULATION_ONLY|source=PriceActionMTF|config_hash=D6CEF886
ENTRY  BUY 4420.439  sl=4403.034 tp=4454.415  reason=PLAN_ENTRY|source=PriceActionMTF|ref_entry=4420.161|risk=ACTIVE|spread_points=160.0
EXIT   BUY 4618.333  entry=4507.175          reason=TARGET_HIT|mode=TP1|bars=88|pnl=111.1578|commission=0.0000
```

Dịch:

1. `INIT`: bot khởi động, tự khai "chỉ mô phỏng", nguồn tín hiệu là Price Action MTF, hash `D6CEF886`.
2. `ENTRY`: bot mở vị thế MUA ảo tại 4420.439, cắt lỗ 4403.034, chốt lãi 4454.415; `spread_points=160.0`
   cho biết chênh lệch giá lúc đó; `risk=ACTIVE` nghĩa cổng rủi ro chưa halt.
   Chú ý `entry` ≠ `ref_entry`: `ref_entry` là giá *lý thuyết* của kế hoạch, còn `price`/`entry` là giá
   bot khớp sau khi mô hình cộng chi phí chênh lệch giá (spread). Preset này đặt
   `InpSlippagePoints=0.0` và `InpCommissionPerVolume=0.0`, nên phần chênh còn lại là spread.
3. `EXIT`: vị thế đóng vì chạm chốt lãi TP1 sau 88 nến, lãi ảo `pnl=111.1578` (đơn vị mô hình).

Dòng `SUMMARY` cuối run (nguyên văn):

```text
SUMMARY  reason=source=PriceActionMTF|entries=93|rejected=0|trades=93|wins=26|losses=67|flats=0|net=-333.11|realized=-333.11|max_dd=5.0210|blocks=99|halted=HALTED
```

Đọc là: 93 lần vào lệnh, 93 lệnh đóng, 26 thắng / 67 thua, lỗ ròng **−333.11 đơn vị mô hình**, rút lui
lớn nhất 5.02 % nên RiskGuard **HALTED** (dừng bot khi vượt `InpMaxDrawdownPct=5.0`) — đó là hành vi
đúng thiết kế, không phải crash. 99 dòng `RISK|ENTRY_BLOCKED` là bot từ chối vào lệnh vì cổng rủi ro
(phổ biến nhất: spread). **Bot lỗ trong mô phỏng; đừng diễn thành "bot tệ" hay "bot tốt".**

### 4.4 Một chi tiết đáng học: bot này *chỉ mua*

Journal trên có **93 BUY, 0 SELL**. Lý do không phải thị trường, mà là cổng `okScore` của indicator
nguồn: `okScore = score100 > 49` ⇔ `rawScore ≥ -0.01`, còn hướng `SELL` đòi `rawScore < 0`; hai điều
kiện chỉ gặp nhau trong dải rất hẹp `[-0.01, 0)`.

Hôm nay (2026-10-30) dải đó đã được **đo bằng buffer**, không còn là suy luận, trên đúng 17 595 nến
của kỳ trên: phía down chỉ 188/8 414 nến qua cổng (2,23 %), `score100` tối đa đúng bằng 50, **0 tín hiệu
bán**; phía up 9 181/9 181 qua cổng, 302 tín hiệu mua. Chi tiết:
[`../indicators/price-action-mtf.md`](../indicators/price-action-mtf.md) §10.5 (quirk `Q11`) và
[`../PROGRESS.md`](../PROGRESS.md) §60.

Bài học cho người mới: **bot luôn có "cửa" ẩn**. Đọc log/CSV để biết nó *từ chối* vì lý do gì, thay vì
đoán "sao hôm nay bot không chạy".

### 4.5 Xác nhận file CSV không bị corrupted — 1 lệnh

Lần chạy mẫu 9 tháng `plan_rr2` đã được lưu sẵn trong repo, nên bạn copy-paste được ngay mà không cần
đổi đường dẫn:

```powershell
cd D:\Applications\tm-fx
.venv\Scripts\python.exe scripts\audit_plan_csv.py --csv "reports\build\tester-reports\plan_rr2\sim_plan_rr2.csv" --offset-minutes 180
```

Output nguyên văn (chụp ngày 2026-10-30):

```text
status=ok rows=287 hash=D6CEF886 symbols=XAUUSDm timeframes=PERIOD_M15 first_bar=2026-01-05T04:00:00Z last_bar=2026-09-30T20:45:00Z events=ENTRY=93,EXIT=93,INIT=1,RISK=99,SUMMARY=1 entry_sides=BUY=93 exit_reasons=SL_GAP=67,TARGET_HIT=26 open_at_end=0 net=-333.11 issues=0
report_json=D:\Applications\tm-fx\reports\plan_audit\plan_audit.json
```

Đọc từng nhóm số:

| Cái gì | Bạn thấy | Nghĩa |
|---|---|---|
| `rows=287` | `1 + 93 + 93 + 99 + 1` | 1 `INIT` + 93 `ENTRY` + 93 `EXIT` + 99 `RISK` + 1 `SUMMARY` — đủ, không thiếu dòng nào |
| `hash=D6CEF886` | một hash duy nhất | toàn file do **cùng một bộ input** sinh ra; nếu trộn hai lần chạy vào một file, bạn sẽ thấy `mixed_config_hash` |
| `events=…` | `ENTRY=93, EXIT=93` | số lệnh mở = số lệnh đóng; `open_at_end=0` xác nhận không còn vị thế treo |
| `entry_sides=BUY=93` | không có `SELL` | chính là cổng `Q11` đã giải thích ở §4.4 |
| `exit_reasons=SL_GAP=67,TARGET_HIT=26` | 67 + 26 = 93 | 26 lệnh chốt lãi, 67 lệnh bị cắt lỗ — đúng bằng `wins=26` / `losses=67` trong dòng `SUMMARY` ở §4.3 |
| `net=-333.11` | bằng con số ở `SUMMARY` | tool cộng lại `pnl` từ CSV rồi so với `SUMMARY`, không tin con số bot tự khai |
| `issues=0` + `report_json=…` | không có dòng `issue …` | file nhất quán; bản JSON đầy đủ (từng dòng + từng issue) nằm ở đường dẫn cuối |

Muốn kiểm tra **CSV của chính bạn** (lần chạy ở Phần 3), giữ nguyên lệnh trên nhưng thay `--csv` bằng
đường dẫn trong bảng §4.1 — nhớ bọc dấu nháy kép vì đường dẫn có khoảng trắng:

```powershell
.venv\Scripts\python.exe scripts\audit_plan_csv.py --csv "C:\Users\tuanmjnh\AppData\Roaming\MetaQuotes\Tester\53785E099C927DB68A545C249CDBCE06\Agent-127.0.0.1-3000\MQL5\Files\sim_plan_rr2.csv" --offset-minutes 180
```

Ba trạng thái có thể xảy ra:

- `status=ok`, `issues=0`, exit code `0` → file nhất quán (cặp ENTRY/EXIT đủ, không SL/TP sai phía,
  `SUMMARY` khớp số dòng thật, timestamp đúng grid 15 phút).
- `status=issues`, exit code `1` → bên dưới in thêm mỗi dòng một `issue kind=<tên> detail=<nội dung>`,
  ví dụ `kind=stop_on_wrong_side` (cắt lỗ nằm sai phía giá vào), `kind=off_grid` (múi giờ/thời gian lệch
  grid), `kind=orphan_exit` (có EXIT không có ENTRY), `kind=mixed_config_hash` (hai lần chạy trộn một
  file). Đây là tín hiệu để bạn *đọc hiểu* bot, không phải lỗi MT5.
- `audit_error: …` in ra stderr, exit code `2` → không đọc được file (sai đường dẫn, file chưa sinh ra).

`--offset-minutes 180`: khoảng lệch giữa giờ máy (GMT+7) và giờ server của **lần chạy mẫu**. Giữ 180 khi
kiểm lại đúng file mẫu; nếu máy/server của bạn khác múi giờ, thử `0` rồi tăng dần cho tới khi hết
`off_grid`. Tool kiểm tra những gì, xem [`install-and-test.md`](install-and-test.md) §4.1 Track C.

---

## 5. Xem bot vận hành *trực tiếp* trên chart (không phải quá khứ)

Đây là cách "ngồi cạnh bot". Vẫn là **mô phỏng**: bot chỉ ghi log + CSV.

1. Mở chart `XAUUSDm`, timeframe **M15** (§2.3).
2. Kéo `PinePlanSimEA` từ **Navigator → Expert Advisors** thả vào chart.
3. Hộp thoại hiện ra, tab **Common**:
   - Tích **Allow Algo Trading** (nếu không tích, `OnTick` của bot không chạy).
   - Không cần cho phép gửi lệnh, vì bot mô phỏng không gửi lệnh.
4. Tab **Inputs**: vẫn phải sửa **`InpPaRr1 = 2.0`** (hoặc `Load` file `.set` như §3.8), và để
   `InpLogFile = sim_chart.csv` để không lẫn với file tester. Nhấn **OK**.
5. Bật nút **Algo Trading** trên toolbar terminal (nút màu xanh = đang bật). Có **hai công tắc** phải
   cùng bật: công tắc global này (và `Tools → Options → Expert Advisors → Allow Algorithmic Trading`)
   cùng với tick **Allow Algo Trading** ở tab *Common* của riêng EA (bước 3).
6. Icon trạng thái bot ở **góc trên bên phải** chart: màu xanh = bot đang chạy, xám/gạch chéo = bị tắt.
   Dấu hiệu chắc chắn nhất vẫn là log ở bước 7.
7. Mở **Toolbox → tab Experts** (`Ctrl+T`): ngay khi gắn bot vào, bạn thấy log khởi động, rồi mỗi nến đã
   đóng bot ghi thêm quyết định của nó:

```text
LAB|INFO|plan|initialized|source=PriceActionMTF|hash=...|log=sim_chart.csv|tester=0
LAB|INFO|plan|pa_bridge|rr1=2.00|rr_min=1.50
LAB|INFO|plan|simulation_only|no_orders_are_sent
```

   Muốn thấy bot *quyết định từng nến* (giá vào, sl, target, lý do đọc buffer): bật `InpDebug = true`,
   log sẽ thêm dòng `LAB|DEBUG|plan|entry|side=BUY|fill=...|ref=...|sl=...|target=...`.
8. Mở `<DATA_FOLDER>\MQL5\Files\sim_chart.csv` bằng Notepad++/Excel: file lớn dần theo từng quyết định,
   mỗi nến đã đóng một dòng.
9. **Dừng bot**: tắt **Algo Trading** (tạm dừng) hoặc chuột phải chart → **Expert Advisors → Remove**
   (gỡ hẳn). Khi gỡ, bot ghi nốt `LAB|INFO|plan|deinit|reason=...|trades=...|net=...`.

Chờ bao lâu để thấy `ENTRY`? Không chắc — cùng kỳ 9 tháng mới có 93 lệnh, tức trung bình vài ngày một
lệnh; và `RISK|ENTRY_BLOCKED` (spread) còn thường xuyên hơn. Đây là **bình thường**, không phải bot hỏng:
bằng chứng bot sống là log `initialized` + file CSV có dòng `INIT`.

---

## 6. Khi nào thì bot gửi lệnh thật (đọc trước khi làm, **không** làm ở lần đầu)

Bot `PATrendRiderXAUv1DemoEA` là EA **duy nhất** trong repo được phép gọi API lệnh, và bị guard chặn
mặc định ở chế độ **dry-run** (chỉ log ý định, không gửi). Toàn bộ quy trình — điều kiện, cách bật
guarded execution, panel trạng thái trên chart, kill switch, giám sát journal, đối soát tab History —
nằm ở [`demo-execution.md`](demo-execution.md). Tóm tắt ranh giới:

| Được | Bị cấm |
|---|---|
| Tài khoản **demo** (tiền giả của sàn) và Strategy Tester | Tài khoản **real/live** — cấm tuyệt đối |
| EA `PATrendRiderXAUv1DemoEA` + `mt5\Include\Exec\*` | Mọi EA khác gọi API lệnh (gate `validate-project.py` kiểm) |
| Bật execution **sau** khi dry-run sạch, có giám sát | Vượt guard, đổi `allow_live_trading`, bỏ `--no-verify` kiểu lách |
| Bot mô phỏng: `PinePlanSimEA`, `WonderwhalesSimEA`, `GridLabEA`, `DCALabEA`, `PATrendRiderXAUv1SimEA` | Grid/DCA trên demo — **chưa** được phép, chờ ADR 0004 |

Trạng thái hiện tại của đường demo: tester đã chạy 31 ENTRY/31 EXIT lệnh demo thật; trên tài khoản demo
thì EA đang `WAITING_FOR_SETUP` và **chưa có ENTRY nào do chiến lược**
([`../v2/EVIDENCE.md`](../v2/EVIDENCE.md) §2.3–§2.4).

---

## 7. Lỗi thường gặp (triệu chứng → nguyên nhân → cách sửa)

| # | Triệu chứng | Nguyên nhân | Sửa |
|---|---|---|---|
| 7.1 | `deploy_pineport.ps1 -Apply` báo lỗi ghi file / compile không chạy | MT5 đang mở, file `.ex5` bị khoá | Tắt MT5 rồi chạy lại §2.4 |
| 7.2 | Compile log có `error` chứ không phải `0 errors, 0 warnings` | Thiếu `Include` (PinePort/Sim) trong Data Folder | Copy lại toàn bộ bằng `-Apply`; kiểm tra `MQL5\Include\PinePort\` |
| 7.3 | Navigator không thấy EA | F5 chưa nhấn; hoặc EA chưa compile | §2.4 → §2.5 |
| 7.4 | Tester/EA không có dòng `ENTRY` nào | Bẫy `InpPaRr1=1.0 < InpPaRrMin=1.5` (mục "Hai cái bẫy", sau bảng bước 3.8) hoặc spread bị `InpMaxSpreadPoints=50` chặn | Load `plan_rr2.set`; kiểm tra log `pa_bridge\|rr1=2.00` |
| 7.5 | Toàn `RISK\|ENTRY_BLOCKED`, không vào lệnh | RiskGuard theo thiết kế (spread vượt ngưỡng, quá 1 vị thế, lỗ trong ngày) | Đọc token trong `reason`; nếu muốn so sánh, nâng `InpMaxSpreadPoints` như preset 600 |
| 7.6 | Chart không có log mới | Nút **Algo Trading** chưa bật; hoặc tick "Allow Algo Trading" bị bỏ | §5.3 + §5.5; chart phải cùng symbol/timeframe bot cần |
| 7.7 | Tab Results equity phẳng, `Deals: 0` | Bot mô phỏng, MT5 không nhận lệnh | Đúng rồi. Đọc CSV (§4) |
| 7.8 | CSV rỗng / không thấy file | `InpEnableLog=false`, hoặc `InpLogFile` khác bạn đang tìm | Bật log; tìm đúng thư mục ở §4.1 |
| 7.9 | `audit_plan_csv.py` in `status=issues` (kèm dòng `issue kind=…`) | File bị ghi dở (bot đang chạy) hoặc trộn 2 lần chạy (cùng `InpLogFile`) | Đợi bot ghi xong `SUMMARY`, hoặc chạy với `InpLogFile` mới |
| 7.10 | `audit_plan_csv.py` báo `not_sorted`/`off_grid` | Sai `--offset-minutes` so với múi giờ máy | Thử `--offset-minutes 0`, rồi 180 |
| 7.11 | Chạy `run_tester.ps1` báo `terminal64 is already running` | Script từ chối vì terminal đang mở | Đóng MT5 (mục đích: chạy headless); hoặc dùng GUI theo Phần 3 |
| 7.12 | `iCustom` / `indicator_init_failed` trong log | Indicator `PinePort\PriceActionMTF` chưa có `.ex5` | §2.4 compile toàn bộ; đừng copy lẻ mỗi EA |

---

## 8. Checklist tự kiểm (tick hết là bạn đã biết chạy bot)

- [ ] Đăng nhập tài khoản **demo**, thấy cân bằng ảo
- [ ] `XAUUSDm` hiện trên chart M15
- [ ] `deploy_pineport.ps1 -Apply` in `0 errors, 0 warnings`
- [ ] Navigator (F5) có `PinePlanSimEA`
- [ ] Chạy Tester single-run, Visual mode, 2026.09, load `plan_rr2.set`
- [ ] Chỉ ra được vì sao Results `Deals: 0` mà CSV vẫn có `ENTRY`
- [ ] Mở được CSV và đọc hiểu 1 dòng `INIT`, 1 dòng `ENTRY`, 1 dòng `EXIT`, 1 dòng `RISK`, dòng `SUMMARY`
- [ ] Chạy `audit_plan_csv.py` → `status=ok issues=0`
- [ ] Gắn EA lên chart, thấy log `initialized|...|tester=0` và CSV `sim_chart.csv` lớn dần
- [ ] Gỡ EA sạch, tắt Algo Trading
- [ ] Nói được: bot mô phỏng ≠ bot demo ≠ tài khoản real (real bị cấm)

---

## 9. Thuật ngữ nhanh

| Thuật ngữ | Nghĩa trong repo này |
|---|---|
| `points` | Đơn vị giá nhỏ nhất của symbol. Trên `XAUUSDm`, journal ghi nhận spread 160–280 points; muốn đổi ra tiền, xem giá trị `Point` của symbol trong cửa sổ Symbols (F3) |
| spread | Chênh giá mua/bán; `spread_points` trong `reason` |
| `SL` / `TP` | Stop-loss (cắt lỗ) / Take-profit (chốt lãi); bot mô phỏng kiểm tra ảo, `TP1/TP2/TP3` là 3 nấc |
| `config_hash` | Vân tay input; hai lần chạy hash khác nhau = hai chiến lược khác nhau, không được so số |
| `equity` | Cân bằng ảo (tiền mô phỏng) |
| `drawdown` / `max_dd` | Mực sụt giảm so với đỉnh cân bằng, tính bằng % |
| `HALTED` | RiskGuard đã ngắt bot vì vượt ngưỡng (vd `InpMaxDrawdownPct=5.0`) |
| dry-run | Bot log ý định nhưng không gửi lệnh |
| quirk `Q2`, `Q11` | Hành vi gốc của Pine được port giữ nguyên; xem [`../indicators/price-action-mtf.md`](../indicators/price-action-mtf.md) §16 |

---

## 10. Đọc tiếp

| Muốn gì | Đọc |
|---|---|
| Hiểu từng khối của con bot, mọi tham số, cách ghép AI | [`ea-anatomy-and-ai.md`](ea-anatomy-and-ai.md) |
| Hiểu preset/input từng bot | [`../v2/CONFIGURATION.md`](../v2/CONFIGURATION.md), [`strategy-tester.md`](strategy-tester.md) §4 |
| Hiểu RiskGuard, sizing, trailing | [`../v2/RISK_MODEL.md`](../v2/RISK_MODEL.md) |
| Chạy hàng loạt bằng lệnh, không bấm chuột | [`strategy-tester.md`](strategy-tester.md) + `reports\build\tester-run\run_tester.ps1` |
| Kiểm môi trường/tổng quan cài đặt | [`install-and-test.md`](install-and-test.md), [`toolchain.md`](toolchain.md) |
| Đường demo execution chi tiết | [`demo-execution.md`](demo-execution.md) |
| Lỗi chuyên sâu hơn | [`../v2/TROUBLESHOOTING.md`](../v2/TROUBLESHOOTING.md) |
| Chiến lược sau lưng bot | [`../v2/STRATEGIES/PA_TRENDRIDER_XAU_V1.md`](../v2/STRATEGIES/PA_TRENDRIDER_XAU_V1.md), [`../indicators/price-action-mtf.md`](../indicators/price-action-mtf.md) |
| Bằng chứng nào đã chạy thật | [`../v2/TEST_REPORT.md`](../v2/TEST_REPORT.md), [`../v2/EVIDENCE.md`](../v2/EVIDENCE.md) |
