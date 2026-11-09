# Infinite Runner XAU V2 — nghiên cứu & nâng cấp (U1 sửa deadlock + đo edge entry)

**Ngày:** 2026-11-09 · **EA:** `mt5/Experts/InfiniteRunnerXAUV2DemoEA.mq5` (magic `25006001`) ·
**Phạm vi:** demo/Strategy Tester. Mọi số dưới đây là **`NOT_STRATEGY_RESULT`** (đo vận hành/kinh tế, không
phải kết quả chiến lược); evidence vẫn `NOT_RUN`, lợi nhuận `UNPROVEN`.

> ## Đọc trước — kết luận
>
> 1. **Có một lỗi vận hành thật đã sửa (U1):** bot tự **deadlock** sau 3 lệnh thua liên tiếp — `streak` chỉ
>    reset khi có lệnh thắng, mà bot bị chặn thì không thắng được. Journal gốc (101 lệnh) cho thấy bot chỉ
>    sống **2 ngày** rồi chặn entry **9 tháng**. Fix: `InpLossStreakCooldownMinutes=240` (hồi phục sau cooldown).
> 2. **Lỗi thứ hai (chưa sửa, cố ý):** khoá drawdown `InpMaxDrawdownPct=8` là **halt vĩnh viễn** (chỉ mở bằng
>    tay) — preset ship tự tắt ngày 2020.06.23 sau 2,5 năm.
> 3. **Entry không có edge.** Đo thô ở tỉ lệ 1:1 (SL 1R, TP 1R, **không** trailing) trên 2018–2026:
>    winrate **48,08%** (< 50% hoà vốn) trên **33.668 lệnh**. Ở 1:1,5 winrate **38,65%** (< 40%).
> 4. **Exit không cứu được.** Ba định nghĩa exit (step trail / trail rộng / không trail) **đều âm** trên
>    cửa sổ dài; kéo rộng trail làm net **tệ hơn** và drawdown **tăng**.
> 5. **Lãi duy nhất từng thấy (cửa sổ 2026 ngắn) là may mắn:** 39 lệnh (0,47%) chạm "TP an toàn" 20R; bỏ
>    chúng thì net âm.
> 6. **Mode `IR_DIR_EMA_MTF` gần như không giao dịch** — 31 lệnh trong 8,75 năm (quá chọn lọc).
>
> **Kết luận:** như WW2, **tín hiệu như đang port không có edge chứng minh được**, và không tham số/exit nào
> tạo ra edge. Giá trị của bot là **hạ tầng demo** (ExecBroker, guard, state), không phải chiến lược.

## 1. Phương pháp

Đọc journal Strategy Tester (18 cột SimLogger) thay vì đoán tham số; mỗi lần đổi **một biến**; so sánh bằng
**expectancy sau chi phí + drawdown**, không bằng winrate. Đo trên cửa sổ dài 2018-01-01 → 2026-10-01,
XAUUSDm M5, Model=1 (1 phút OHLC), deposit 10.000, lot cố định 0.01. Công cụ (đều tracked):
`scripts/tester/gen_ir_sets.py` (sinh scenario), `scripts/tester/analyse_ir.py` (phân tích streaming),
`scripts/tester/build_ir_evidence.py` (dựng evidence pack). Bằng chứng nhỏ gọn đã commit:
[`evidence/infinite-runner/`](evidence/infinite-runner/README.md) (PNG đường vốn + JSON metric từng scenario).

Quy ước đơn vị (Exness `XAUUSDm`, 3 chữ số): **1 point = 0.001**; `InpInitialSlPoints=5000` ⇒ SL cách entry
**5,00 giá** = **1R ≈ $5,00** ở lot 0.01 (contract 100 oz). "TP an toàn" `InpSafetyTpPoints=100000` = 100 giá
= **20R**.

## 2. Journal gốc — 101 lệnh, và lỗi deadlock

Journal `infinite_runner_demo_exec` (2026.01.05→2026.10.01):

| Sự kiện | Số |
|---|---:|
| ENTRY / EXIT | 101 / 101 (chỉ trong 2026.01.05–01.07, chạm trần 50 lệnh/ngày) |
| wins (TB **+$1,26** = 0,25R) | 81 (80,2%) |
| losses (đúng **−$5,00** = 1R) | 20 |
| net / expectancy | +$1,70 / ≈ +0,003R |
| block `loss_streak` | **51.937** (≈ toàn bộ nến M5 của 9 tháng còn lại) |

**Cơ chế lỗi:** từ 2026.01.07 lệnh thua thứ 3 liên tiếp đặt `g_streak_losses=3`; `EntryThrottlesOk` chặn mọi
entry khi `streak >= InpMaxConsecutiveLosses`; `g_streak_losses` **chỉ reset khi có lệnh thắng** (EA ~dòng
1049) và `InpCooldownMinutes=0` ⇒ không có lệnh ⇒ không có thắng ⇒ **deadlock vĩnh viễn**. Nhánh `Halt()`
dành cho streak không bao giờ chạy (throttle chặn trước), nên panel ghi `halted=ACTIVE` trong khi bot đã chết.

Đây cũng là lý do kinh tế 101 lệnh vô nghĩa: **toàn bộ mẫu chỉ là 2 ngày**, không phải 9 tháng.

## 3. U1 — sửa deadlock (đã ship)

Input mới `InpLossStreakCooldownMinutes` (mặc định **240**): chạm chuỗi thua → chặn `cooldown` phút → hết hạn
**xoá streak và vào lại**; `0` = khoá vĩnh viễn (escape hatch có chủ ý). Logic thuần:
`mt5/Include/InfiniteRunner/IRRisk.mqh` (`IRLossStreakDecide`); test `mt5/Scripts/IRCoreTests.mq5`; guardrail ở
`sim_configs.py` + `validate_demo_execution.py` + pytest; ADR 0005 ghi sửa đổi.

**Kiểm chứng** (đúng cửa sổ gốc 2026.01.05→10.01): bot giao dịch **đủ 9 tháng**, `streak=0`, không halt:

| Cấu hình | Lệnh | Winrate | Net | Exp R | Ghi chú |
|---|---:|---:|---:|---:|---|
| bản cũ | 101 | 80,2% | +1,70 | +0,003 | chết sau 2 ngày |
| sau fix U1 | 8.364 | 72,2% | +763,55 | +0,018 | đủ 9 tháng |

⚠️ **Cảnh báo:** bỏ **39 lệnh (0,47%) chạm TP 20R** thì net ≈ **−$3.136** ⇒ "lãi" là may mắn, không phải edge.

## 4. Lỗi thứ hai — khoá drawdown là halt vĩnh viễn

Chạy preset **y như ship** (khoá daily/DD bật) trên 2018→2026: bot halt ngày **2020.06.23** với
`max_drawdown_reached|dd=8.00%` (`InpManualResetDrawdown=false`), chỉ 2.406 lệnh:

| Lệnh | Winrate | Net | Exp R | PF | MaxDD |
|---:|---:|---:|---:|---:|---:|
| 2.406 | 71,07% | **−793,01** | −0,066 | 0,77 | 8% → halt |

Khoá DD 8% là **hàng rào an toàn có chủ ý** (ADR), **không** phải lỗi — nhưng nó kết thúc bot sau ~2,5 năm.
Vì vậy các đo lường dưới đây tắt khoá daily/DD để xem trọn cửa sổ.

## 5. Đo trên cửa sổ đầy đủ 2018–2026 (khoá daily/DD tắt)

| # | Cấu hình | Lệnh | Winrate | Net | Exp R | PF | MaxDD | ghi chú |
|---|---|---:|---:|---:|---:|---:|---:|---|
| A | baseline (step trailing ship) | 26.130 | 73,0% | −685,40 | −0,005 | 0,98 | 22,5% | 75 TP-hit = +$7.472; bỏ ra ⇒ −$8.157 |
| B | U2 để winner chạy (fixed trail, step off) | 34.238 | 59,8% | −2.077,69 | −0,012 | 0,97 | 32,2% | rộng hơn ⇒ tệ hơn |
| C | U3 1:1 (SL 5000, TP 5000, không trail) | 26.143 | **48,07%** | −5.796,01 | −0,044 | 0,92 | 58,3% | đo edge thô |
| D | U3 1:1,5 (TP 7500) | 18.407 | **38,65%** | −3.839,00 | −0,042 | 0,93 | 38,8% | hoà vốn cần 40% |
| E | `IR_DIR_EMA_MTF` | 31 | 74,2% | −21,18 | −0,137 | 0,49 | 0,2% | quá chọn lọc, vô dụng |
| F | U3 1:1 **sạch** (mọi guard off) | 33.668 | **48,08%** | −7.158,96 | −0,043 | 0,92 | 71,9% | khử mọi confound |

### 5.1 Entry không có edge

Ở **1:1**, hoà vốn cần winrate **50%** trước chi phí. Đo được **48,07%** (C, có guard streak) và **48,08%**
(F, mọi guard off) — nhất quán on **33.668 lệnh**. Ở **1:1,5**, hoà vốn cần **40%**; đo được **38,65%**.
Nghĩa là tín hiệu (EMA 21/50 chiều "legacy", mode 0) **không tốt hơn tung đồng xu** — thua **một chút** (đúng
bằng spread + trượt). avg_win $4,98 vs avg_loss −$5,02 là chênh lệch spread.

### 5.2 Exit không cứu được

- Step trailing (baseline) **giữ winrate cao 73%** nhưng **cắt thắng ở ~0,36R** (p50=0,04R, p90=0,70R), net ≈ hoà
  (−$685), âm khi bỏ 75 TP-hit hiếm.
- Cho winner chạy (B, fixed trail) **tăng avg_win** (0,36R → 0,65R) nhưng **hạ winrate** (73% → 60%) và **net
  tệ hơn** (−$2.078) cùng DD **lớn hơn** (32%).
- Bỏ hẳn trailing (C/F) ⇒ winrate về **48%**, net âm sâu (−$5.800…−$7.160), DD 58–72%.

Kéo rộng exit **không tạo edge**, chỉ đổi hình dạng winrate. Giống WW2: tần suất/exit không tạo lợi thế.

## 6. Vì sao "lãi" ở 2026? — may mắn đuôi

Cửa sổ 2026 (9 tháng) cho +$763 vì **39 lệnh chạm TP 20R** (+$3.892). Cửa sổ 2018–2026 (A) cũng chỉ dương
nhờ **75 TP-hit** (+$7.472); bỏ ra thì −$8.157. Chiến lược sống nhờ **các sự kiện đuôi hiếm (≈0,3%)**, không
nhờ kỳ vọng dương.

## 7. Điều đã ship trong phiên này

- **U1** (sửa deadlock) + test + guardrail + ADR 0005 (commit `adf66d9`).
- **Không** đổi chiến lược/entry/exit/preset ship. **Không** sửa khoá DD (hàng rào an toàn — quyết định của
  chủ dự án nếu muốn cho hồi phục).

## 8. Khuyến nghị (cần chủ dự án quyết)

1. **Chấp nhận kết luận âm và dừng tinh chỉnh** trên tín hiệu hiện tại (giống WW2). — *khuyến nghị*
2. Nếu muốn tiếp: **thiết kế lại entry** (giả thuyết mới, spec trước, mẫu lớn) — vì mọi biến thể EMA/exit đều
   không có edge.
3. **Khoá drawdown**: nếu muốn bot chạy liên tục, cần cho nó hồi phục được (như U1) — nhưng đó là nới hàng
   rào an toàn, phải là quyết định riêng.
4. Mode `IR_DIR_EMA_MTF`: hoặc **bỏ** khỏi preset (quá chọn lọc, 31 lệnh/8,75 năm), hoặc nới điều kiện — cần
   spec mới.

## 9. Tái lập

Scenario được **sinh từ `configs/demo/infinite_runner_demo.json`** (nguồn sự thật) — không sửa tay `.set`:

```powershell
# 1. Sinh .set/.ini cho mọi scenario (ghi vào reports/build, gitignored)
.venv\Scripts\python.exe scripts\tester\gen_ir_sets.py

# 2. Chạy Strategy Tester (mỗi scenario ~15-30 phút)
scripts\tester\run_tester.ps1 -Scenario infinite_runner_fixcheck          -TimeoutSec 10800
scripts\tester\run_tester.ps1 -Scenario infinite_runner_long_base_nolock  -TimeoutSec 10800
scripts\tester\run_tester.ps1 -Scenario infinite_runner_long_exit_run     -TimeoutSec 10800
scripts\tester\run_tester.ps1 -Scenario infinite_runner_long_fixedrr      -TimeoutSec 10800
scripts\tester\run_tester.ps1 -Scenario infinite_runner_long_fixedrr15    -TimeoutSec 10800
scripts\tester\run_tester.ps1 -Scenario infinite_runner_long_fixedrr_clean -TimeoutSec 10800
scripts\tester\run_tester.ps1 -Scenario infinite_runner_long_mtf          -TimeoutSec 10800

# 3. Phân tích (in nền kinh tế) + dựng lại evidence pack đã commit
.venv\Scripts\python.exe scripts\tester\analyse_ir.py reports\build\tester-reports\<scenario>\sim_*.csv
.venv\Scripts\python.exe scripts\tester\build_ir_evidence.py
```

Dữ liệu thô (journal CSV tới ~190 MB, báo cáo HTM) ở `reports/build/tester-reports/<scenario>/` và **bị
gitignore** theo `reports/README.md`; chỉ PNG đường vốn + JSON metric (0,09 MB) được commit vào
[`evidence/infinite-runner/`](evidence/infinite-runner/README.md).
