# Wonderwhales XAU 2-mode — nghiên cứu cải thiện Scalp (a → h)

> Báo cáo tổng hợp một mạch, tự chứa. Chi tiết theo ngày nằm ở [`../PROGRESS.md`](../PROGRESS.md) §71–§88.
> Nhật ký quyết định nội bộ (git-ignored): `.superpowers/sdd/ww2-scalp-improvement/progress.md`.

**Trạng thái cuối: `NOT_RUN` (bot) · `BLOCKED` (parity) · `UNPROVEN` (lợi nhuận).**
Mọi số liệu trong báo cáo là **`NOT_STRATEGY_RESULT`**: chạy Strategy Tester với parity Pine ↔ MT5 **OFF**, nên
chúng xếp hạng cấu hình chứ **không** phải bằng chứng lợi nhuận.

> ## Kết luận chốt (đọc trước)
>
> **Tín hiệu như đang port KHÔNG có edge chứng minh được.** Bằng chứng mạnh nhất: baseline trên 8,75 năm
> (XAUUSDm M5, 2018-2026) cho **103 lệnh, winrate 39,81%, expectancy −0,02R, PF 0,95** (§11.6) — còn *dưới*
> ngưỡng hoà vốn 40% của TP 1,5R. Kết quả dương ở các cửa sổ ngắn (+0,11R / +0,08R — §11.5) là **nhiễu mẫu nhỏ**.
>
> **Đã loại hết các đòn bẩy tham số:** trailing/break-even không đổi kết cục lệnh nào; nới cửa sổ trigger/setup
> và tổ hợp đều **kém hơn** baseline dưới engine chuẩn; hình học TP không nhất quán; bộ lọc chất lượng SAR vô tác
> dụng; entry bằng mode ATR không kiểm định được (0 lệnh với mặc định, 3 lệnh với ngưỡng M5).
>
> **Ba bài học lớn hơn cả chiến lược:**
> 1. **Chọn engine quan trọng hơn mọi tham số.** `iSAR` của MT5 khác PSAR chuẩn/Pine ~2,3% hướng, và nó *đảo
>    dấu* kết luận của gần như mọi so sánh (§11.4).
> 2. **Cỡ mẫu phải được thiết kế trước.** Với ~19 tín hiệu/năm, cửa sổ 1,5 năm chỉ có ~22 lệnh — mọi so sánh
>    trong §6 và §11.4–11.5 nằm trong vùng nhiễu.
> 3. **Hằng số mặc định của Pine không có nghĩa ở mọi khung** (ngưỡng ATR `0,5` hợp D1/W1 nhưng chặn ~100% nến M5).
>
> **Việc còn lại:** (a) export thật từ TradingView để giải quyết parity (hiện `BLOCKED`, mọi kết luận đứng trên
> tín hiệu chưa xác minh); (b) thiết kế **luật entry mới** để đổi tần suất/loại tín hiệu; (c) chấp nhận kết luận
> âm. Chi tiết ở §13.

---

## 1. Câu hỏi

Chủ sở hữu báo Scalp giao dịch **rất ít** và winrate/PnL kém. Lộ trình đã duyệt: **đo trước, sửa sau**, mỗi
lần đổi đúng **một** biến, đọc kết quả bằng **expectancy sau chi phí + drawdown**, không bằng winrate.

## 2. Phương pháp

1. **Một biến mỗi lần chạy** — mọi đối chứng phải tái lập kết quả trước đó **chính xác**; nếu không, so sánh
   bị coi là không hợp lệ.
2. **In-sample (IS) + out-of-sample (OOS)** — IS `2024.01.01→2025.06.30`, OOS `2025.07.01→2026.10.01`.
   Một biến chỉ được coi là có ích khi **cả hai** cửa sổ cùng chiều.
3. **Tắt cap rủi ro và tắt management khi đo** để một HALT không cắt ngắn mẫu; deposit 100.000, risk 0,15%
   để bộ định cỡ min-lot không âm thầm bỏ tín hiệu.
4. **Nhãn trung thực** — `INSUFFICIENT_SAMPLE` khi < 30 lệnh/nhánh; không bao giờ gọi chẩn đoán là kết quả
   chiến lược.
5. **Chốt luật quyết định trước khi xem kết quả** (ví dụ: chỉ gỡ cổng parity khi `status=match` với ≥ 100
   tín hiệu).

## 3. Công cụ đã dựng

| File | Vai trò |
|---|---|
| `scripts/tester/gen_ww2_sets.py` | Sinh `.set`/`.ini` từ JSON preset; 6 ma trận thí nghiệm |
| `scripts/tester/run_tester.ps1` | Chạy 1 scenario headless; **fail-closed** nếu report 0 bar |
| `scripts/tester/analyse_census.py` | Funnel bias → setup → signal cho census |
| `scripts/tester/analyse_measure.py` | trades/winrate/net/expectancy R+USD/PF/max DD/exit-kind/histogram R/trail mix; `INSUFFICIENT_SAMPLE`; cảnh báo nhánh trùng kết cục |
| `mt5/Include/Wonderwhales/WW2Census.mqh` | CSV census 15 cột (chẩn đoán, không gửi lệnh) |
| `scripts/compare_pine_exports.py` | Comparator parity Pine ↔ MQL5; exit `3` = `BLOCKED` |

**Hai lỗi im lặng của harness đã phát hiện & sửa** (đều có chốt chặn):
`WW2TrailingCoordinator` chỉ xét candidate trail khi `r ≥ InpTrailTriggerR` (đặt `1e9` làm nhánh trail
**không bao giờ chạy**), và `OnInit` từ chối `InpTrailTriggerR < InpBreakEvenTriggerR` (run abort với
**exit 0 / 0 bar** nhưng runner vẫn archive CSV cũ).

## 4. Nguyên nhân gốc (bước a — census)

Scenario `ww2_scalp_census`: **194.869 nến M5**, 2024-01-01 → 2026-09-30, parity ON nên **0 lệnh**.

| Cổng | Số nến | % tổng | % của cổng trước |
|---|---:|---:|---:|
| bias M15 (EMA20/50 + EMA200) | 160.310 | 82,27% | — |
| setup M5 (PSAR flip cùng phía bias) | 4.657 | 2,39% | 2,90% của bias |
| signal M1 xác nhận | **52** | 0,03% | 1,12% của setup |

`reason`: `no_m5_flip` 155.653 (79,88%), `no_m15_bias` 34.559 (17,73%), `no_m1_confirm` 4.605 (2,36%),
`signal` 52 ⇒ **~19 tín hiệu/năm**.

**Nguyên nhân:** cả ba cổng chỉ đọc `shift=1`, nên cổng M1 đòi **đúng cây M1 cuối cùng** của nến M5 vừa đóng
phải là cây flip — 4 trong 5 cây M1 bị bỏ qua. Cổng M1 giết **98,88%** số setup đã qua M5. Bộ lọc bias **không**
phải nút thắt (82% nến có bias).

## 5. Kết quả theo bước

| Bước | Thay đổi (một biến) | Kết luận |
|---|---|---|
| b | Harness đo + ghi `r=` vào journal EXIT | Công cụ; 8 run `NOT_STRATEGY_RESULT` |
| c | Runbook parity + exit code `3` = `BLOCKED` | Comparator đã sẵn sàng; parity **`BLOCKED`** |
| d | `InpTriggerWindowBars=5` (quét cả nến M5) | **Cải thiện rõ** |
| e | `InpSetupWindowBars=5` (flip trong 5 nến M5) | Cải thiện IS, không qua OOS |
| f | Tổ hợp `(5,5)` | **Cả hai cửa sổ dương lần đầu**, edge mỏng |
| g | Hình học TP (1,0/1,25/1,5/2,0 R) | **IS/OOS mâu thuẫn** ⇒ không chọn được |
| h | Bộ lọc chất lượng SAR | **Không tác dụng** |

## 6. Bốn đòn bẩy — kết quả đầy đủ

### 6.1 Management (bước b) — **LOẠI**

IS: A/B/C/D **giống hệt** 21 lệnh, 28,57%, −988,62 USD, −0,32R, PF 0,56, DD 1,34%.
OOS: A = 25 lệnh, 40,00%, −85,45, −0,01R, PF 0,96; B/C/D = 25 lệnh, 44,00%, −376,68, −0,09R, PF 0,81.

Mọi exit đều là **−1R hoặc +1,5R**. Break-even và structure/PSAR **có bắn** (5–10 sự kiện) nhưng **không đổi
kết cục lệnh nào**: giá chạm TP hoặc SL trước khi stop trail kịp bị chạm. BE trung tính ở IS, **hơi có hại** ở
OOS (−291,23 USD) vì kéo 3 lệnh thắng về scratch.

### 6.2 Cửa sổ sự kiện (bước d–f)

| Cấu hình (setup, trigger) | Lệnh IS | Exp R IS | PF IS | Lệnh OOS | Exp R OOS | PF OOS |
|---|---:|---:|---:|---:|---:|---:|
| (1, 1) đối chứng | 21 | −0,32 | 0,56 | 25 | −0,01 | 0,96 |
| (5, 1) | 235 | −0,08 | 0,87 | 238 | −0,01 | 0,97 |
| (1, 5) | 282 | −0,10 | 0,83 | 298 | **+0,06** | **1,10** |
| (5, 5) | **854** | **+0,03** | 1,06 | **841** | **+0,02** | 1,03 |

- **Cả hai cửa sổ là nút thắt thật**: mỗi cái một mình tăng ~11–13× số lệnh và cắt gần nửa expectancy âm ở IS.
- **Chỉ cửa sổ trigger vượt 0 ở OOS** khi đứng một mình; nhưng tổ hợp `(5,5)` là cấu hình **duy nhất dương ở
  cả hai** cửa sổ.
- Đối chứng `(1,1)`, `w1`, `s1`, `q0` **tái lập chính xác** kết quả trước ⇒ các mặc định đúng là không đổi
  hành vi (harness tự chứng minh, không phải lời).

### 6.3 Hình học TP (bước g) — **KHÔNG NHẤT QUÁN**

Base `(1,5)`, chỉ đổi `InpTakeProfitR` (SL giữ 1R):

| TP | Exp R IS | PF IS | Exp R OOS | PF OOS |
|---|---:|---:|---:|---:|
| 1,0R | −0,10 | 0,82 | −0,03 | 0,93 |
| 1,25R | −0,11 | 0,82 | −0,01 | 0,98 |
| 1,5R | −0,10 | 0,83 | +0,06 | 1,10 |
| 2,0R | −0,11 | 0,84 | +0,09 | 1,14 |

Winrate giảm đúng theo `1/(1+TP)` và luôn trên ngưỡng hoà vốn, **nhưng IS âm phẳng ở mọi mức TP** trong khi
OOS thích TP lớn đơn điệu ⇒ **không** chọn được TP; TP 2,0R tốt ở OOS có thể là đặc điểm chế độ 2025-07→2026-10.

### 6.4 Bộ lọc chất lượng SAR (bước h) — **KHÔNG TÁC DỤNG**

Base `(5,5)`, `InpScalpRequireSarAgree` (đòi hướng PSAR khung setup **còn** đồng ý lúc trigger):
`q0` (tắt) IS 854 lệnh / +0,03R / PF 1,06; OOS 841 / +0,02 / 1,03.
`q1` (bật) IS **848** lệnh / +0,03R / PF 1,05; OOS **828** / +0,03 / 1,04.

Lọc chỉ bỏ **0,7–1,5%** số lệnh và **đổi dấu** giữa hai cửa sổ: cửa sổ trigger rộng **một** nến M5 nên gần như
không có thời gian để SAR M5 đảo ngược sau flip. Giả thuyết "xu hướng đảo sau flip" **không đúng**.

## 7. Cấu hình tốt nhất hiện có

`(setup 5, trigger 5)` — dương ở cả hai cửa sổ nhưng **edge mỏng**:

| Cửa sổ | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---:|---:|---:|---:|---:|---:|
| IS | 854 | 41,92% | +4.207,65 | +0,03 | 1,06 | 5,46% |
| OOS | 841 | 41,26% | +2.517,92 | +0,02 | 1,03 | 3,51% |

Winrate hoà vốn của TP 1,5R là **40%**; winrate quan sát 41–42% chỉ **hơn ~2 điểm** ⇒ PF 1,03–1,06 nằm trong
vùng nhiễu/chi phí. `(1,5)` vẫn là cấu hình có **edge/lệnh tốt nhất** (`+0,06R` OOS) dù IS âm.

## 8. Điều biết chắc / điều chưa biết

**Biết chắc:**
- Cổng M1 một-nến là nút thắt thật; nới cửa sổ trigger cải thiện rõ ở cả hai cửa sổ.
- Trailing/break-even không đóng góp gì ở cấu hình này.
- Bộ lọc SAR-agree vô tác dụng; hình học TP không được hai cửa sổ xác nhận.

**Chưa biết (không được suy diễn):**
- **Parity Pine ↔ MT5 chưa được chứng minh** (`BLOCKED`): chưa có CSV reference do TradingView xuất. Mọi tín
  hiệu đo được có thể vẫn lệch bản gốc Pine ⇒ mọi kết luận về lợi nhuận đều đứng trên nền chưa kiểm chứng.
- **Chưa có bằng chứng lợi nhuận** nào: tất cả đều parity OFF (`NOT_STRATEGY_RESULT`).
- Chưa rõ edge mỏng ở `(5,5)` là edge thật hay đặc điểm chế độ của dữ liệu.
- Bộ dữ liệu chỉ 2,75 năm, một symbol (`XAUUSDm`), một broker (Exness).

## 9. Tái lập

```powershell
# 0) Compile EA vào terminal (đóng MT5 trước)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1 -Apply -Force

# 1) Sinh .set/.ini (từ JSON preset — nguồn sự thật duy nhất)
.venv\Scripts\python.exe scripts\tester\gen_ww2_sets.py

# 2) Census (chẩn đoán, 0 lệnh)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tester\run_tester.ps1 -Scenario ww2_scalp_census
.venv\Scripts\python.exe scripts\tester\analyse_census.py `
    reports\build\tester-reports\ww2_scalp_census\sim_ww2_scalp_census_census.csv

# 3) Ma trận đo (management / cửa sổ / hình học / chất lượng)
foreach ($w in 'is','oos') { foreach ($a in 'a','b','c','d') {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tester\run_tester.ps1 -Scenario "ww2_meas_scalp_${w}_${a}" } }
.venv\Scripts\python.exe scripts\tester\analyse_measure.py reports\build\tester-reports
```

Chạy hết ma trận hiện có (40 scenario) mất khoảng **1 giờ**; mỗi run ~90–115 s.

Port check (§11) có lệnh riêng, đầy đủ ở
[`../../scripts/tester/README.md`](../../scripts/tester/README.md) mục "Port check Pine ↔ MQL5".

## 10. Việc còn mở và khuyến nghị

1. **Parity (chặn mọi kết luận lợi nhuận)** — cần CSV reference thật do Pine xuất (runbook:
   [`../10-bots/wonderwhales-2mode.md`](../10-bots/wonderwhales-2mode.md) §5.3). Không có TradingView Pro thì
   phương án thay thế là **cross-implementation** (dump bar MT5 + port spec Pine sang Python, so với log MQL5),
   **phải ghi nhãn `CROSS_IMPLEMENTATION`**, không dùng để gỡ cổng parity.
2. **Nếu muốn tiếp tục tìm edge** — hướng đúng không còn là tinh chỉnh tham số mà là **đổi định nghĩa entry**
   (ví dụ đòi M15 bias *mới* cắt, hoặc đòi cấu trúc BOS), coi như nghiên cứu mới chứ không phải tuning.
3. **Đừng đổi preset mặc định** dựa trên các số parity-OFF này: preset giữ `InpTriggerWindowBars=1`,
   `InpSetupWindowBars=1`, `InpScalpRequireSarAgree=false` cho tới khi parity xong (quyết định của chủ sở hữu).
4. Việc mở cũ vẫn treo: magic `25006001` trên demo chưa xác nhận đã đóng; file state của InfiniteRunner chưa
   xoá; 5 bot demo cũ vẫn `UNPROVEN` lợi nhuận (`../PROGRESS.md` §70.4).

## 11. Kiểm chứng port — cross-implementation (task J)

Không có TradingView Pro nên **không** tạo được CSV reference của Pine. Thay vào đó: viết một bản cài đặt
**độc lập** của spec Pine bằng Python (`python/src/mt5_ea_ai_lab/signals/wonderwhales.py`), chạy trên **đúng
cùng cây nến** với indicator MQL5, rồi so **từng nến**.

**Nhãn: `CROSS_IMPLEMENTATION` — KHÔNG phải `PARITY`.** Nó chứng minh hai bản cài đặt độc lập của cùng một
spec khớp nhau (hoặc không), **không** chứng minh bản nào khớp TradingView. Vì vậy nó **không** được dùng để
gỡ `InpRequireParity`.

Cách làm:

1. `WonderwhalesDumpTesterEA` (read-only, chỉ chạy trong tester) ghi mỗi nến đã đóng **cùng giá trị buffer**
   của `PinePort\Wonderwhales`: `psar,sar_dir,buy_signal,sell_signal,fast,slow,atr_pct,blocked_*`.
2. Bản Python chạy spec trên đúng OHLCV đó.
3. `scripts/compare_wonderwhales_bars.py` so từng trường sau khi bỏ 300 nến warm-up.

**Phát hiện kèm theo (quan trọng):** `PineSignalLabEA` **không thể ghi tín hiệu trong Strategy Tester** — nó
đòi `BarsCalculated(handle) >= Bars()`, nhưng trong tester `Bars()` tính cả ~1 năm lịch sử nạp trước
`FromDate` còn indicator chỉ tính vùng test (`calculated=71009` vs `rates_total=141805`), nên nó kẹt
`indicator_not_ready` suốt run và ghi **0 tín hiệu** (bằng chứng: `reports/.../portref_sig_m5`). Đây là lý do
chưa từng có kết quả parity nào chạy được.

### 11.1 Kết quả (XAUUSDm, 2025.01.01→2026.01.01, mode SAR_EMA, sau 300 nến warm-up)

| Khung | Nến so | `sar_dir` | `buy_signal` | `sell_signal` | `psar` (≤1e-4) | `fast`/`slow` (≤1e-4) |
|---|---:|---:|---:|---:|---:|---:|
| M15 | 23.320 | 97,39% | 99,40% | 99,70% | 87,82% | 100% |
| M5 | 70.496 | 97,69% | 99,50% | 99,71% | 88,70% | 100% |
| M1 | 352.837 | 97,89% | 99,62% | 99,65% | 90,14% | 100% |

Đọc:

1. **EMA khớp hoàn toàn:** `fast` lệch ≤ 5e-9, `slow` ≤ 1,3e-5, 100% nến nằm trong 1e-4 trên cả ba khung ⇒
   phần EMA của indicator đã được kiểm chứng chéo.
2. **Tín hiệu khớp 99,4–99,7%** ⇒ ~0,3–0,6% nến cho tín hiệu khác.
3. **PSAR mới là chỗ lệch:** hướng lệch **~2,1–2,6%** nến; mức PSAR chỉ khớp 88–90% trong 1e-4, lệch tối đa
   tới **120** (M15). Bản port đã được tinh chỉnh sang biến thể clamp hai nến trước (97,69% hướng ở M5, so
   với 96,44% của biến thể clamp một nến), nhưng phần lệch còn lại **không giải thích được**.
4. Vì toàn bộ chuỗi entry dựa trên **PSAR flip**, mức độ lệch này là rủi ro thật cho parity.

### 11.2 Kết luận (trung thực)

- **Không kết luận được bên nào đúng.** Bản port theo PSAR Wilder/Pine cổ điển; indicator MQL5 gọi `iSAR`
  của MT5 — vốn nổi tiếng khác `ta.sar` của TradingView (đúng như rủi ro D1 trong
  [`indicators/wonderwhales.md`](indicators/wonderwhales.md) §10, giờ đã **đo được bằng số**).
- Vì vậy: **port chưa được kiểm chứng** ⇒ mọi kết luận về chiến lược ở §6–§7 vẫn đứng trên một tín hiệu
  chưa xác minh. Chỉ export thật từ TradingView mới giải quyết được.
- Việc nên làm tiếp: **thay `iSAR` bằng một PSAR tự cài trong indicator** (bắt đầu bằng biến thể đã đo là sát
  nhất), rồi đo lại cross-implementation; nếu khớp ~100% thì rủi ro chuyển từ "indicator" sang "chưa có
  reference Pine".

### 11.3 PSAR tự cài — đã thêm, **chưa** kiểm chứng (đang chờ xử lý)

Đã thêm vào indicator một input mới `InpPsarEngine` (`ENUM_WW_PSAR`: `WW_PSAR_ISAR` mặc định = hành vi ship
**không đổi**, `WW_PSAR_BUILTIN` = PSAR Wilder tự cài với clamp hai nến trước) và hàm thuần
`WwPsarReset/WwPsarStep` trong `WonderwhalesContract.mqh`.

Lượt đo lại (`portref_dump_m5_builtin`): **nhánh tự cài KHÔNG khớp bản Python** — `sar_dir` 81,26%,
`psar` chỉ 1,60% nến trong 1e-4 (so với 97,69% / 88,70% của `iSAR`). Hai chuỗi lệch **từ nến thứ hai** và ở
trạng thái up/down khác nhau, tức là **lỗi thật** trong nhánh tự cài (không phải lệch pha: quét độ trễ
−3..+3 đều ≤1,6%).

#### 11.3.1 Đã tìm ra và sửa (2026-11-06)

Hai lỗi, cả hai đều thật:

1. **Điểm bắt đầu khác nhau.** PSAR là công thức truy hồi: hai chuỗi chỉ khớp khi bắt đầu ở **cùng một nến**.
   Trong tester, `iSAR` (sub-indicator) được tính trên **toàn bộ lịch sử terminal**, còn `rates_total` mà
   indicator tự cài nhận được nhỏ hơn `Bars()` của EA ⇒ chuỗi tự cài bắt đầu ở vùng test, lệch pha.
   *Sửa:* EA dump thêm vùng lịch sử nạp trước; comparator chạy port **từ nến đầu tiên indicator có giá trị**
   (`aligned_from_row`); và trong indicator, chuỗi tự cài được dựng bằng `CopyRates` trên **đúng** `Bars()`
   rồi đọc qua `offset = Bars() - rates_total`.
2. **Cache gồm cả nến đang chạy.** Nến đang chạy đổi OHLC liên tục; vì trạng thái PSAR là **bền** (persistent),
   đưa nó vào cache sẽ làm hỏng mọi giá trị sau đó.
   *Sửa:* lưu trạng thái (up/ep/af) **từng nến**, chỉ tính tới nến **đã đóng**, và **tính lại nến vừa đóng**
   mỗi lần (rewind + chạy tiếp) thay vì cộng dồn mù.

Kết quả sau khi sửa (`portref_dump_m5_builtin`, XAUUSDm M5 2024-01→2025-12, 141.503 nến so sau warm-up):

| Trường | Khớp |
|---|---|
| `sar_dir`, `buy_signal`, `sell_signal`, `blocked_buy`, `blocked_sell` | **100%** |
| `psar` | **100%** trong 1e-4, lệch tuyệt đối tối đa **5e-9** |
| `fast` / `slow` | 100% trong 1e-4 |

⇒ **Bản cài MQL5 của PSAR tự cài khớp chính xác bản Python độc lập.** Vì vậy chênh lệch 2,3% hướng so với
`iSAR` (mục 11.1) là **khác biệt thuật toán thật giữa `iSAR` của MT5 và PSAR chuẩn/Pine**, đã được chứng minh
từ **cả hai phía** — đúng rủi ro D1. Vẫn **không** biết bên nào khớp `ta.sar` của TradingView (cần export thật).

Kiểm chứng trên **cả ba khung** mà EA dùng (engine tự cài):

| Khung | Nến so | `sar_dir` / tín hiệu / blocked | `psar` (≤1e-4) | `fast`/`slow` |
|---|---:|---:|---:|---:|
| M15 | 43.865 | 100% | 100% (max 5e-9) | 100% |
| M5 | 141.503 | 100% | 100% (max 5e-9) | 100% |
| M1 | 703.411 | 100% | 100% (max 5e-9) | 100% |

Phát hiện phụ khi mở rộng sang M1/M15: những nến **cũ hơn vùng cache** (cache neo đuôi, còn cửa sổ M1/M15 rất
lớn) bị indicator ghi `EMPTY_VALUE` (DBL_MAX). Đã sửa **cả hai phía**: EA dump không ghi sentinel
(`|price|>1e12` → bỏ trống) và comparator coi mọi giá trị `|v|>1e12` là **thiếu** thay vì so sánh. Trước khi
sửa, sentinel đó bị đọc thành số và tạo ra "chênh lệch" giả (max ~1e287).

Trạng thái: `WW_PSAR_BUILTIN` **vẫn không phải mặc định** (mặc định `iSAR`, hành vi ship không đổi). Khi bật,
indicator in `WONDERWHALES|INFO|psar_engine_builtin|port_check=100pct...`. Đổi engine mặc định là **quyết định
riêng** vì nó đổi **mọi** tín hiệu ⇒ phải chạy lại toàn bộ ma trận đo.

**Đã tối ưu hiệu năng (2026-11-06).** Ba lỗi/chi phí, theo thứ tự phát hiện:

1. Bản đầu gọi `CopyRates(Bars())` và dựng lại toàn bộ chuỗi **mỗi lần OnCalculate** (theo từng tick): dump M5
   một-handle ~249 s.
2. Bản "chỉ thêm đuôi" vẫn **đánh địa chỉ theo vị trí cửa sổ**, mà tester lại **chèn nến cũ vào đầu** khi nạp
   lịch sử ⇒ vị trí không ổn định ⇒ phải kiểm tra **theo thời gian** của nến vừa đóng.
3. Một lỗi off-by-one coi nến `rates_total-1` (nến **đang chạy**) là nến đã đóng ⇒ lệch cả chuỗi một nến.

Bản cuối là **cache vòng neo theo đuôi chuỗi** (slot mới nhất = nến đã đóng gần nhất): thêm nến là O(1), cửa sổ
bị tái lập không cần dựng lại, chỉ dựng lại khi chuỗi ngắn đi hoặc có khoảng trống. Kiểm chứng lại: **100%**
(141.503 nến, max lệch 5e-9) và dump M5 một-handle **249 s → ~18–20 s** (baseline `iSAR` cùng dump ~12 s).
Đồng thời sửa `run_tester.ps1`: tester chọn agent 3000/3001 tuỳ run ⇒ phải quét **mọi** agent Files dir thay vì
chỉ cái đầu (trước đó archive rỗng dù CSV đã ghi).

**Chưa đổi được mặc định sang `WW_PSAR_BUILTIN`.** Đã thử (2026-11-06): EA 2-mode tạo **6 handle** (M1…W1) và
một run với engine tự cài vẫn mất **hàng chục phút** (đo được 18,4 phút/lần ở bản trước; >12 phút ở bản tối ưu),
so với **~110 s** của `iSAR` — nên ma trận 32 run là bất khả thi. **Mặc định giữ `iSAR`**, giữ input
`InpPsarEngine` để chọn theo run.

Kết quả đã đạt được cho engine tự cài: **khớp 100% bản Python độc lập** (141.503 nến, max lệch 5e-9); dump M5
một handle **~18–20 s**; sau khi truy tìm đuôi cache **theo thời gian** (bù việc tester chèn nến cũ vào đầu),
một run EA 2-mode còn **348 s (~5,8 phút)** so với **~110 s** của `iSAR` — vẫn ~3×, nên ma trận 32 run (~3 giờ)
mới chỉ chạy **6 cấu hình chính**.

### 11.4 Đổi engine ĐỔI HẲN kết luận (6 cấu hình chính, `NOT_STRATEGY_RESULT`)

| Cấu hình | `iSAR`: lệnh / net / exp R / PF | `BUILTIN`: lệnh / net / exp R / PF |
|---|---|---|
| `is_a` baseline | 21 / −988,62 / −0,32 / 0,56 | **22 / +339,41 / +0,11 / 1,19** |
| `oos_a` baseline | 25 / −85,45 / −0,01 / 0,96 | **30 / +259,41 / +0,08 / 1,11** |
| `is_gate_w5` | 282 / −4.287,54 / −0,10 / 0,83 | 297 / −2.244,07 / −0,05 / 0,92 |
| `oos_gate_w5` | 298 / +2.601,60 / +0,06 / 1,10 | 309 / +2.790,50 / +0,07 / 1,10 |
| `is_combo_c5` | 854 / +4.207,65 / +0,03 / 1,06 | 894 / +2.068,59 / +0,02 / 1,03 |
| `oos_combo_c5` | 841 / +2.517,92 / +0,02 / 1,03 | 885 / +1.034,02 / +0,01 / 1,01 |

**Đọc:** với PSAR chuẩn/Pine, **baseline (không nới cửa sổ) dương ở CẢ HAI cửa sổ** (+0,11R / +0,08R), trong
khi với `iSAR` nó âm ở cả hai; và việc **nới cửa sổ trở nên kém hơn baseline**. Nghĩa là phần lớn "cải thiện"
ở mục 6.2 trước đây là **bù đắp cho PSAR của iSAR**, không phải edge của tín hiệu.

**Cảnh báo:** arm A chỉ có **22–30 lệnh** (IS vẫn `INSUFFICIENT_SAMPLE`), PF 1,11–1,19 là vừa phải, mọi thứ vẫn
parity OFF (`NOT_STRATEGY_RESULT`), và chỉ 6/32 cấu hình được chạy lại. **Không** được coi đây là bằng chứng lợi
nhuận, và **không** đủ để đổi mặc định engine.

Lưu ý vận hành: các archive trong `reports/` (gitignored) hiện **trộn hai engine** — 6 scenario chính là
`BUILTIN`, phần còn lại là `iSAR`; bảng iSAR gốc được giữ ở `reports/build/measure_summary_isar_engine.txt`.

### 11.5 Ma trận đầy đủ (32 run) với engine `BUILTIN`

Đã chạy lại **cả 32** scenario với `InpPsarEngine=1` (~5,8 phút/run). Bảng đầy đủ ở
`reports/build/measure_summary_builtin_engine.txt`; các mốc chính (exp R — số dương in đậm):

| Nhóm | IS (exp R) | OOS (exp R) |
|---|---|---|
| **baseline `(1,1)`** = `a` = `w1` = `s1` | **+0,11** (22 lệnh, `INSUFFICIENT_SAMPLE`) | **+0,08** (30 lệnh) |
| trailing `b`/`c`/`d` | +0,11 / +0,07 / +0,07 | +0,01 / +0,01 / +0,01 |
| trigger `w5` | −0,05 | +0,07 |
| setup `s5` | −0,11 | −0,02 |
| combo `(5,5)` | +0,02 | +0,01 |
| geom `tp10/125/15/20` trên `(1,5)` | −0,04 / −0,05 / −0,05 / −0,04 | −0,02 / +0,01 / +0,07 / **+0,12** |
| qual `q1` vs `q0` | +0,02 vs +0,02 | +0,01 vs +0,01 |

**Kết luận (trung thực):**

1. **Không đòn bẩy nào thắng baseline** dưới engine chuẩn. Nới cửa sổ trigger/setup, tổ hợp `(5,5)` — tất cả
   đều **kém hơn** `(1,1)`; trailing/break-even vẫn không đổi kết cục lệnh; bộ lọc chất lượng vẫn vô tác dụng.
2. **Baseline `(1,1)` là cấu hình duy nhất dương ở cả hai cửa sổ** (+0,11R / +0,08R) — đúng như bảng 11.4.
3. Nhưng **mẫu quá nhỏ để kết luận edge**: 22 lệnh ở IS (`INSUFFICIENT_SAMPLE`) và 30 ở OOS, PF 1,11–1,19.
   Với `InpScalpTriggerWindowBars=1` (mặc định), ~19 tín hiệu/năm là **thiết kế**, nên 1,5 năm in-sample chỉ có
   ~22 lệnh. Muốn tăng mẫu phải **kéo dài cửa sổ đo**, không phải nới cổng tín hiệu (chính việc nới cổng làm
   edge biến mất).
4. `oos_geom_tp20` (+0,12R, PF 1,18) là điểm sáng duy nhất về OOS, nhưng IS của nó là −0,04 ⇒ **không nhất
   quán**, đúng như kết luận hình học TP ở mục 6.3.

Nghĩa là: dưới engine chuẩn, **đòn bẩy đúng không phải tham số** — hoặc tín hiệu này không có edge đủ lớn, hoặc
mẫu hiện tại chưa đủ để nhìn thấy nó. Bước hợp lý tiếp theo là **mở rộng mẫu** (lịch sử dài hơn) chứ không phải
tinh chỉnh tiếp.

### 11.6 Mở rộng mẫu (2018-2026) — và câu trả lời là ÂM

Chạy baseline `(1,1)` với engine tự cài trên **toàn bộ lịch sử có được** (XAUUSDm M5, 2018-01-01 → 2026-10-01;
run 78,6 phút):

| Cửa sổ | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---:|---:|---:|---:|---:|---:|
| IS 1,5 năm (§11.5) | 22 | 45,45% | +339,41 | **+0,11** | 1,19 | 0,52% |
| OOS 1,25 năm (§11.5) | 30 | 43,33% | +259,41 | **+0,08** | 1,11 | 1,14% |
| **2018-2026 (8,75 năm)** | **103** | **39,81%** | **−420,77** | **−0,02** | **0,95** | 1,60% |

**Kết luận: kết quả dương ở §11.5 là nhiễu mẫu nhỏ.** Với 103 lệnh, expectancy ≈ **0 và hơi âm**
(−0,02R), PF 0,95, winrate 39,81% — **dưới** ngưỡng hoà vốn 40% của TP 1,5R (nhất quán với expectancy âm).

Đây là bằng chứng mạnh nhất trong cả báo cáo: **tín hiệu như đang port không có edge chứng minh được**. Và nó
cho thấy vấn đề phương pháp: với `InpScalpTriggerWindowBars=1` (mặc định), ~19 tín hiệu/năm là **thiết kế**, nên
cửa sổ 1,5 năm chỉ có ~22 lệnh — **quá nhỏ để kết luận bất cứ điều gì**; mọi so sánh trong §6.2–§6.4, §11.4–§11.5
đều nằm trong vùng nhiễu đó.

Hệ quả cho bước tiếp theo: **không tinh chỉnh tham số nữa**. Hoặc (a) thay đổi **định nghĩa entry** để tạo ra
nhiều tín hiệu/loại tín hiệu khác, hoặc (b) chấp nhận kết luận "không có edge" và dừng.

### 11.7 Thử đổi định nghĩa entry bằng mode ATR — và phát hiện cổng ATR vô hiệu trên M5

Thử rẻ nhất: đổi `InpSignalMode` sang `WW_MODE_SAR_EMA_ATR` (3) — thêm cổng biến động ATR, đã có sẵn trong
contract đã kiểm chứng. Chạy trên **cùng cửa sổ dài** để so với baseline 103 lệnh (run 79 phút):

| Cấu hình (cửa sổ 2018-2026) | Lệnh | Net (USD) | Exp (R) | PF |
|---|---:|---:|---:|---:|
| mode 2 SAR+EMA (baseline) | 103 | −420,77 | −0,02 | 0,95 |
| **mode 3 SAR+EMA+ATR** (`InpMinAtrPct=0,5`) | **0** | 0,00 | — | — |

**0 lệnh trong 8,75 năm.** Nguyên nhân đo được: cổng là `ATR% ≥ InpMinAtrPct = 0,5`, nhưng phân bố ATR% trên
XAUUSDm **M5** (141.804 nến) là:

| percentile | 5% | 25% | 50% | 75% | 95% | max |
|---|---:|---:|---:|---:|---:|---:|
| ATR% | 0,032 | 0,051 | **0,069** | 0,098 | 0,169 | 0,550 |

⇒ `0,5` là mặc định **cấp D1/W1** (giá trị gốc của Pine cho use-case khung cao); trên M5 nó chặn **~100%** nến.
Muốn kiểm định giả thuyết "chỉ vào lệnh khi biến động đủ lớn" trên M5 phải đặt ngưỡng theo thang M5 — ví dụ
`0,12` (khoảng tứ phân vị trên) để giữ ~25% nến mạnh nhất.

Đây cũng là một bài học parity: hằng số mặc định của Pine **không** tự động có nghĩa ở mọi khung; EA 2-mode
Scalp dùng mode 2 nên không bị ảnh hưởng, nhưng nếu ai bật mode 3 với mặc định thì bot sẽ im lặng mãi mãi.

### 11.8 Thử lại với ngưỡng ATR theo thang M5 — vẫn bế tắc vì mẫu

Đặt `InpMinAtrPct = 0,12` (tứ phân vị trên của M5) với `InpSignalMode=3`, cùng cửa sổ dài (run 81 phút):

| Cấu hình (2018-2026) | Lệnh | Net (USD) | Winrate | Exp (R) |
|---|---:|---:|---:|---:|
| mode 2 SAR+EMA (baseline) | 103 | −420,77 | 39,81% | −0,02 |
| mode 3, `MinAtrPct=0,5` (mặc định) | 0 | 0,00 | — | — |
| **mode 3, `MinAtrPct=0,12`** | **3** | +543,80 | 100% | +1,50 |

**3 lệnh trong 8,75 năm ⇒ không kết luận được gì.** Lý do: chuỗi entry (bias M15 + flip M5 + xác nhận M1) vốn đã
chỉ cho ~19 tín hiệu/năm; nhân thêm điều kiện ATR ~15% số nến ⇒ vài lệnh mỗi thập kỷ. Cả 3 lệnh đều thắng, nhưng
với n=3 điều đó vô nghĩa.

⇒ **Các thí nghiệm entry "rẻ" (dùng mode có sẵn) đã hết.** Giả thuyết ATR-regime không thể kiểm định được bằng
chuỗi entry hiện tại ở cỡ mẫu có ý nghĩa. Chỉ còn: thiết kế **luật entry mới** (tạo tần suất tín hiệu khác) hoặc
**chấp nhận kết luận âm** và dừng.

### 11.9 Định nghĩa entry mới (E-A: bỏ cổng M1) — mẫu LỚN, kết quả vẫn ÂM

Luật mới đúng vào nút thắt mà census chỉ ra: `InpScalpRequireTrigger=false` **bỏ xác nhận M1**, chỉ cần bias M15
+ flip M5 cùng phía. Đây là thí nghiệm được thiết kế để có **mẫu lớn ngay từ đầu** (dự kiến ~1.000–1.700
lệnh/năm). Chạy cùng cửa sổ dài 2018-2026, engine PSAR tự cài (55 phút):

| Cấu hình (2018-2026) | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---:|---:|---:|---:|---:|---:|
| baseline `(1,1)` | 103 | 39,81% | −420,77 | −0,02 | 0,95 | 1,60% |
| **E-A: bỏ cổng M1** | **5.378** | **39,05%** | **−26.872,11** | **−0,04** | **0,93** | **31,67%** |

**Mẫu 5.378 lệnh ⇒ kết luận chắc chắn: E-A làm mọi chỉ số xấu đi.** Expectancy −0,04R (so với −0,02R), PF 0,93
(so với 0,95), winrate 39,05% (dưới ngưỡng hoà vốn 40%), và drawdown 31,67% vì số lệnh khổng lồ.

**Đọc:** cổng M1 **không** che mất edge — nó đang **lọc nhiễu**. Bỏ nó tăng tần suất nhưng hạ chất lượng/đơn vị
rủi ro. Điều này khép lại hướng "đổi định nghĩa entry để tăng tần suất": **không tạo ra edge**, chỉ khuếch đại
kết quả âm.

Ba lần thử theo hướng entry (mode ATR, ngưỡng ATR theo M5, bỏ cổng M1) **đều âm hoặc không kiểm định được**.
Với dữ liệu hiện có, kết luận **không có edge** là kết luận duy nhất được dữ liệu ủng hộ.

## 12. Artefact

Gitignored (chỉ có trên máy chạy): `reports/build/tester-reports/` —
`ww2_scalp_census/` (journal 45 MB + census 14,5 MB), và mỗi scenario `ww2_meas_scalp_*/` (journal, telemetry,
`.htm`, `.png`). Bảng tổng hợp: `reports/build/measure_summary.txt` (do `analyse_measure.py` sinh).

Cổng tĩnh tại commit cuối: `validate-project checks=15 fail=0`, `validate_demo_execution checks=14 fail=0`,
`check_docs_links broken=0`, `pytest 480 passed`, compile `0 errors / 0 warnings`.

## 13. Kết luận chốt và việc còn lại

### 13.1 Điều đã chứng minh được

- **Cơ chế gây "rất ít lệnh" (có số liệu):** hai cổng sự kiện một-nến chồng nhau (flip M5 và flip M1). Cổng M1
  chỉ nhìn **1 trong 5** nến M1 của nến M5; census cho thấy nó giết **98,88%** số setup (§4).
- **EMA của port khớp hoàn toàn** với bản Python độc lập trên M1/M5/M15 (max lệch ~5e-9, 100% nến trong 1e-4).
- **PSAR tự cài khớp 100%** bản Python độc lập trên cả ba khung (M1 703.411 · M5 141.503 · M15 43.865 nến, §11.3.1).
- **`iSAR` của MT5 KHÁC PSAR chuẩn/Pine ~2,3% hướng** — đo từ cả hai phía; đây là rủi ro D1 đã được định lượng.
- **Trailing/break-even không đóng góp gì** ở cấu hình này (dưới cả hai engine).
- **Không đòn bẩy tham số nào thắng baseline** dưới engine chuẩn (§11.5).
- **Không có edge chứng minh được** trên 8,75 năm: 103 lệnh, −0,02R, PF 0,95 (§11.6).

### 13.2 Điều CHƯA chứng minh được (không được suy diễn)

- **Parity Pine ↔ MT5 vẫn `BLOCKED`**: chưa có CSV reference do TradingView xuất. Mọi kết luận về chiến lược
  đứng trên một tín hiệu **chưa xác minh với bản gốc**. Đây là điều kiện tiên quyết số một.
- Bên nào đúng (`iSAR` hay PSAR chuẩn) — **không biết**; chỉ export thật mới trả lời được.
- Không có bằng chứng lợi nhuận nào; bot `NOT_RUN`, profit `UNPROVEN`.
- Bộ dữ liệu: một symbol (`XAUUSDm`), một broker (Exness), một khung (M5 setup).

### 13.3 Bài học phương pháp (giữ lại cho các nghiên cứu sau)

1. **Cỡ mẫu thiết kế trước.** Với ~19 tín hiệu/năm, 1,5 năm = ~22 lệnh: không đủ. Phải dài ≥ 8 năm, hoặc thiết
   kế luật có tần suất cao hơn ngay từ đầu.
2. **Kiểm chứng port trước khi tinh chỉnh.** Chọn PSAR đảo dấu kết luận; tinh chỉnh tham số trên một tín hiệu
   chưa xác minh là vô nghĩa.
3. **Đo độ nhạy theo engine.** Mọi so sánh nên chạy trên ≥ 2 engine/hai bản cài đặt để biết kết luận có phụ
   thuộc implementation không.
4. **Trong tester, mọi thứ phải neo theo THỜI GIAN, không theo chỉ số**: tester **chèn nến cũ vào đầu** cửa sổ
   khi nạp lịch sử, làm chỉ số trôi; `Bars()` cũng lớn hơn `rates_total` mà indicator nhận.
5. **Sentinel không được vào CSV**: `EMPTY_VALUE` (DBL_MAX) bị đọc thành số ⇒ tạo chênh lệch giả (§85).
6. **Hằng số Pine mặc định không có nghĩa ở mọi khung** (ATR 0,5 hợp D1/W1, chặn ~100% nến M5 — §11.7).

### 13.4 Việc còn lại (theo thứ tự khuyến nghị)

1. **Parity** — export CSV reference thật từ TradingView (runbook: [`../10-bots/wonderwhales-2mode.md`](../10-bots/wonderwhales-2mode.md)
   §5.3). Phần chuẩn bị đã xong để việc này thành **drop-in một lệnh**:
   `scripts/ww2_parity_check.py` kiểm tra trước (schema/`symbol`/`timeframe`/số tín hiệu), gọi comparator, và in
   `ALLOW_FLIP`/`KEEP_BLOCKED` theo đúng luật quyết định đã chốt (kèm `ww2_parity_decision.txt`). Việc còn lại chỉ
   là **file export của bạn** (agent không mở TradingView, repo không có TradingView Pro). Không có export thật thì
   **`CROSS_IMPLEMENTATION`** (§11) là mức kiểm chứng cao nhất hiện có, và nó **không** được dùng để gỡ
   `InpRequireParity`.
2. **Luật entry mới** — nếu tiếp tục tìm edge: đổi tần suất/loại tín hiệu (M15 crossover event, break-of-structure
   trên M5), thiết kế mẫu đủ lớn ngay từ đầu, đo bằng harness sẵn có.
3. **Chấp nhận kết luận âm** — với dữ liệu hiện có, **không tinh chỉnh thêm**.
4. **Việc mở cũ (§70.4, cập nhật 2026-11-08 — xem `../PROGRESS.md` §90):**
   - Tester IR **đã chạy có bằng chứng** (101 entry/101 exit, net +1,70; §90.2) và ba lỗi của `run_tester.ps1`
     đã được sửa (§90.3).
   - Vị thế lạc magic `25006001` trên demo **vẫn đang mở** theo journal (`entries=1|exits=0`, ticket
     `-1507758291`) ⇒ state file **không được xoá**; chỉ terminal/demo mới xác nhận được đã đóng.
   - Lợi nhuận 5 bot demo cũ vẫn `UNPROVEN` (chỉ phiên demo thật mới nâng được).
5. **Việc treo duy nhất còn lại trong cây làm việc:** `docs/superpowers/specs/2026-11-04-data-reset-and-regeneration-design.md`
   vẫn **untracked** (spec chưa từng được duyệt). Chủ sở hữu chọn **giữ nguyên, không commit** (2026-11-08).

### 13.5 Nhãn trung thực (không nâng)

- Bot `NOT_RUN` · parity `BLOCKED` · profit `UNPROVEN`.
- Mọi số trong báo cáo là `NOT_STRATEGY_RESULT` (parity OFF), trừ khi ghi rõ khác.
- Preset ship giữ mặc định: `InpTriggerWindowBars=1`, `InpSetupWindowBars=1`, `InpScalpRequireSarAgree=false`,
  `InpPsarEngine=WW_PSAR_ISAR` (engine tự cài đã kiểm chứng nhưng **chậm hơn** với EA 6 handle).
