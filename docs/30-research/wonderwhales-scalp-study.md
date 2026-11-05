# Wonderwhales XAU 2-mode — nghiên cứu cải thiện Scalp (a → h)

> Báo cáo tổng hợp một mạch, tự chứa. Chi tiết theo ngày nằm ở [`../PROGRESS.md`](../PROGRESS.md) §71–§79.
> Nhật ký quyết định nội bộ (git-ignored): `.superpowers/sdd/ww2-scalp-improvement/progress.md`.

**Trạng thái cuối: `NOT_RUN` (bot) · `BLOCKED` (parity) · `UNPROVEN` (lợi nhuận).**
Mọi số liệu trong báo cáo là **`NOT_STRATEGY_RESULT`**: chạy Strategy Tester với parity Pine ↔ MT5 **OFF**, nên
chúng xếp hạng cấu hình chứ **không** phải bằng chứng lợi nhuận.

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

## 11. Artefact

Gitignored (chỉ có trên máy chạy): `reports/build/tester-reports/` —
`ww2_scalp_census/` (journal 45 MB + census 14,5 MB), và mỗi scenario `ww2_meas_scalp_*/` (journal, telemetry,
`.htm`, `.png`). Bảng tổng hợp: `reports/build/measure_summary.txt` (do `analyse_measure.py` sinh).

Cổng tĩnh tại commit cuối: `validate-project checks=15 fail=0`, `validate_demo_execution checks=14 fail=0`,
`check_docs_links broken=0`, `pytest 459 passed`, compile `0 errors / 0 warnings`.
