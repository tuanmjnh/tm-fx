# Infinite Runner V2/V3 — nghiên cứu hướng "chạy dài hạn, lãi nhỏ đều"

**Ngày:** 2026-11-09 · **EA:** `mt5/Experts/InfiniteRunnerXAUV2DemoEA.mq5` (magic `25006001`) và bản thử
`archive/wip/2026-11-03_InfiniteRunnerXAUV3/` · **Phạm vi:** demo / Strategy Tester.
**Nhãn:** mọi số dưới đây là **`NOT_STRATEGY_RESULT`**; lợi nhuận vẫn **`UNPROVEN`**.

**Nguồn dữ liệu:** chỉ dùng bằng chứng đã commit trong [`evidence/infinite-runner/`](evidence/infinite-runner/README.md)
và code trong repo. Bản nghiên cứu này **không chạy thêm Strategy Tester nào** (không có MT5 trong môi trường
viết tài liệu) — các thí nghiệm mới nằm ở §8 và phải do chủ dự án (hoặc agent có MT5) chạy.
Nối tiếp [`infinite-runner-study.md`](infinite-runner-study.md) (U1 sửa deadlock + đo edge entry).

> ## Đọc trước — kết luận
>
> 1. **Mục tiêu "lãi nhỏ đều, chạy lâu" cần một thứ chưa có: expectancy dương sau chi phí.** Mọi cấu hình V2
>    đã đo (9 lần chạy) đều có net âm hoặc dương nhờ đuôi hiếm. Không có tham số hay quy tắc thoát nào *tạo ra*
>    edge — chỉ có entry/thời gian giữ lệnh mới tạo ra nó.
> 2. **Winrate 73% của V2 là sản phẩm của exit, không phải tín hiệu tốt.** Step trailing cắt thắng ở ~0,36R và
>    giữ thua ở 1R ⇒ cần winrate hoà vốn 73,4%; đo được 72,97%. Đây đúng là phân phối lệch âm: "lãi nhỏ đều,
>    thua lớn hiếm" — đẹp trên đồ thị ngắn, nguy hiểm khi chạy dài (§4).
> 3. **Chi phí giải thích gần như toàn bộ kết quả của các lần chạy SL/TP cố định.** Mô hình "giá ngẫu nhiên trừ
>    spread ≈ 0,19 giá" dự đoán winrate 48,10% (1:1) và 38,48% (1:1,5); đo được 48,08% và 38,65% (§3).
>    Entry EMA21/50 không tốt hơn tung đồng xu — nó chỉ trả spread ~3.000–3.900 lần/năm (≈ 5,7–7,4%/năm trên $10.000).
> 4. **Có một tín hiệu nhỏ đáng điều tra:** hai lần chạy cho winner chạy (`long_exit_run`, `long_base_nolock`) có
>    lợi nhuận *gộp trước spread* dương ≈ +0,03R/lệnh, trong khi các lần chạy SL/TP cố định ≈ 0. Nó vẫn nhỏ hơn
>    spread (≈ 0,038R) nên net âm, và **chưa biết** nó là trend-persistence thật hay chỉ là đà tăng dài hạn của
>    vàng 2018–2026 (§5). Thí nghiệm E1 (phân rã theo hướng × năm) quyết định việc này.
> 5. **V3 không phải "nâng cấp lợi nhuận".** V3 giữ nguyên entry V2, chỉ đổi cách thoát (structure trailing M15)
>    và lot theo rủi ro; nó còn **thiếu bản sửa deadlock U1** (§2). Dự đoán có thể bác bỏ: V3 sẽ nằm gần
>    `long_exit_run` (net −2.100…0 trên cùng cửa sổ) chứ không lật được dấu.
> 6. **Hướng khả thi cho mục tiêu của bạn:** ít lệnh hơn, giữ lâu hơn, entry theo regime khung lớn — vì chi phí
>    cố định theo lệnh còn edge (nếu có) tích luỹ theo thời gian giữ. Phải qua cổng G1–G4 (§9) trước khi gọi là có
>    edge. Quy mô kỳ vọng thực tế ở rủi ro 0,25%/lệnh được tính ở §7 — nhỏ hơn nhiều so với cảm giác từ winrate.

## 1. Dịch mục tiêu thành tiêu chí đo được

"Lợi nhuận nhỏ liên tục, chạy lâu dài" không đo được nếu không đổi thành số. Đề xuất bộ tiêu chí cho mọi thí nghiệm
về sau (ghi cùng nhãn `NOT_STRATEGY_RESULT` cho tới khi qua G4):

| Tiêu chí | Ngưỡng đề xuất | Vì sao |
|---|---|---|
| Expectancy sau chi phí (R/lệnh) | cận dưới CI 95% > 0, **cả khi nhân đôi spread** | edge phải sống sót khi chi phí thật tệ hơn tester |
| Số lệnh độc lập | ≥ số lệnh ở bảng §7 cho edge cần phát hiện | tránh kết luận từ mẫu nhỏ |
| Max drawdown (equity) | ≤ 15% trên cửa sổ đầy đủ, không halt vĩnh viễn | "chạy lâu" nghĩa là không tự chết |
| Tỉ lệ tháng dương / thời gian dưới đỉnh | báo cáo cả hai | đo cảm giác "đều" thay vì winrate |
| Skew & avg win / avg loss | báo cáo, không tối ưu winrate | phát hiện bẫy lệch âm (§4) |
| Doanh thu đuôi | net **không** có 0,5% lệnh tốt nhất | `net_without_tp` đã chứng tỏ đuôi gây hiểu lầm |
| Tần suất lệnh | ≤ ~1–3 lệnh/ngày giao dịch (đề xuất ban đầu) | V2 hiện ~12–16 lệnh/ngày |

## 2. V2 và V3: khác nhau đúng ở đâu

So sánh `input` của hai file (V3 nằm ở `archive/wip/2026-11-03_InfiniteRunnerXAUV3/`, 2.069 dòng; V2 1.934 dòng):

| Hạng mục | V2 (canonical) | V3 (WIP) | Ghi chú |
|---|---|---|---|
| Entry | `IR_DIR_LEGACY_EMA` (EMA21 ≥ EMA50 ⇒ BUY, ngược lại SELL, mỗi nến M5 đóng) | **giống hệt** | cố ý, để so sánh riêng exit |
| Thoát | Step trailing 3 nấc (bật) | Structure trailing M15 (swing xác nhận + đệm ATR); step & classic **tắt** | thay đổi lõi của V3 |
| Break-even | tắt (`0`) | `1.5R` | trễ hơn |
| Lot | `IR_LOT_FIXED` 0,01 | `IR_LOT_RISK` 0,25% | xem lưu ý dưới |
| `InpEnableExecution` | `true` (ADR 0006) | `false` | V3 an toàn hơn khi gắn nhầm |
| Chống deadlock U1 | **có** (`InpLossStreakCooldownMinutes=240`, `IRRisk.mqh`) | **không có** | V3 tách ra trước khi sửa |
| File log/state | `infinite_runner_demo*.csv` | `..._v3.csv` | tránh trộn state |
| Đăng ký validator | trong `EXEC_SOURCES` của `scripts/validate-project.py` | không | lý do thật sự V3 bị cô lập |

Ba hệ quả thực tế:

1. **V3 vẫn mang lỗi deadlock đã sửa ở V2.** Chuỗi 3 lệnh thua liên tiếp sẽ khoá vào lệnh vĩnh viễn (streak chỉ xoá
   khi thắng). Phải port U1 trước khi chạy V3 dài hạn — nếu không, mọi kết quả V3 dài sẽ lặp lại lỗi "chết sau 2 ngày".
2. **Lý do cô lập ghi trong README của V3 chưa chính xác.** README nói 6 lời gọi `AccountInfo*` ngoài `Exec/*` vi phạm
   ranh giới; nhưng V2 cũng gọi `AccountInfo*` ở cùng các vị trí tương ứng và vẫn qua validator vì **được liệt kê trong
   `EXEC_SOURCES`**. Cái thiếu của V3 là *đăng ký* (allowlist + ADR + preset + test), không phải một lỗi kiến trúc mới.
3. **Lot theo rủi ro có thể bỏ qua mọi lệnh ở tài khoản nhỏ.** 0,01 lot XAU ≈ 1 oz ⇒ SL 5,00 giá thua $5,00. Với risk
   0,25%, cần equity ≥ **$2.000** (SL 5 giá), ≥ **$4.000** (SL 10), ≥ **$6.000** (SL 15). Dưới ngưỡng, V3 bỏ qua lệnh (đúng
   thiết kế) — bot sẽ "không giao dịch" mà không có lỗi. Hãy kiểm tra equity demo trước khi kết luận "bot chết".

## 3. Mô hình kinh tế: giá ngẫu nhiên trừ spread

**Định lý dùng ở đây (optional stopping):** nếu giá (bid) không có drift hay tính dự đoán, thì với *mọi* quy tắc thoát
(SL/TP cố định, trailing, step, structure), kỳ vọng lãi/lỗ mỗi lệnh = **−spread** (trước slippage/swap). Quy tắc thoát chỉ
đổi *hình dạng* phân phối kết quả, không đổi kỳ vọng.

Với SL cách entry `A` và TP cách `B` (giá), BUY mở ở ask = bid + `s`: TP cần bid đi lên `B + s`, SL chỉ cần đi xuống
`A − s`. Xác suất chạm TP trước (bước ngẫu nhiên đối xứng):

```text
p_TP = (A − s) / (A + B)          kỳ vọng mỗi lệnh = −s
```

Kiểm tra với bằng chứng đã commit (XAUUSDm, 1 point = 0,001, A = 5,00):

| Lần chạy | A:B | n | winrate đo được | spread suy ra | winrate dự đoán ở s = 0,19 |
|---|---|---:|---:|---:|---:|
| `long_fixedrr` | 1 : 1 | 26.143 | 48,07% | 0,193 ± 0,061 | 48,10% |
| `long_fixedrr_clean` | 1 : 1 | 33.668 | 48,08% | 0,192 ± 0,053 | 48,10% |
| `long_fixedrr15` | 1 : 1,5 | 18.407 | 38,65% | 0,168 ± 0,088 | 38,48% |

Spread suy ra ≈ **190 điểm**, đúng khoảng 150–300 điểm Exness mà [`10-bots/infinite-runner.md`](../10-bots/infinite-runner.md)
§6 đã ghi — một phép kiểm độc lập. Tổng net dự đoán `N × s` so với đo được:

| Lần chạy | N | `−N × 0,19` | net đo được | chênh (≈ lãi gộp trước spread) | gộp / lệnh |
|---|---:|---:|---:|---:|---:|
| `fixedrr` (1:1) | 26.143 | −4.967 | −5.796 | −829 | −0,006R |
| `fixedrr_clean` (1:1) | 33.668 | −6.397 | −7.159 | −762 | −0,005R |
| `fixedrr15` (1:1,5) | 18.407 | −3.497 | −3.839 | −342 | −0,004R |
| **`long_base_nolock`** (step trail) | 26.130 | −4.965 | −685 | **+4.279** | **+0,033R** |
| **`long_exit_run`** (fixed trail, step off) | 34.238 | −6.505 | −2.078 | **+4.427** | **+0,026R** |

**Đọc bảng:** ba dòng đầu khớp mô hình (chênh nhỏ âm ≈ slippage/phí thêm ~$0,03/lệnh). Hai dòng sau **lệch dương
~$4.300** — lớn hơn sai số (SE trung bình ≈ $0,022/lệnh cho 34k lệnh; sai số của `s` ≈ ±0,027 chi phối). Đó là lãi gộp
≈ $0,13–0,16 mỗi lệnh khi cho winner chạy, so với spread $0,19: **thiếu khoảng $0,03–0,06/lệnh để hoà vốn**.

## 4. Bẫy "lãi nhỏ đều" = phân phối lệch âm

Winrate hoà vốn khi trung bình thắng `W` và thua `L`: `p* = L / (W + L)`.

| Lần chạy | winrate đo | `p*` | khe hở | ghi chú |
|---|---:|---:|---:|---|
| `long_base_nolock` (step trail) | 72,97% | 73,36% | −0,39 pp | thắng 0,36R, thua 1R |
| `long_exit_run` (fixed trail) | 59,76% | 60,49% | −0,73 pp | thắng 0,65R |
| `long_fixedrr` (1:1) | 48,07% | 50,28% | −2,22 pp | không trail |
| `fixedrr15` (1:1,5) | 38,65% | 40,32% | −1,67 pp | |

Winrate dịch chuyển gần như đúng bằng `p*` ở mọi cấu hình: exit chỉ **đánh đổi** winrate lấy kích cỡ thắng, khe hở còn
lại ≈ chi phí. Hệ quả:

- Đường vốn có dạng thang đều rồi một cú sụt sâu (tail risk phía thua). `long_base_nolock` chạm DD 22,5% và
  `fixedrr_clean` 71,9%.
- Trailing chặt làm đồ thị 2–3 tháng trông "lãi nhỏ đều" (như cửa sổ 2026: +$763, winrate 72%) nhưng **lãi đó nằm trong
  39 lệnh 20R (0,47%)**; bỏ chúng thì −$3.128 ([`infinite-runner-study.md`](infinite-runner-study.md) §3, §6).
- Khoá `InpMaxDrawdownPct=8` biến cú sụt thành halt vĩnh viễn ngày 2020.06.23 — bot không "chạy lâu" được theo đúng nghĩa.

## 5. Phần chưa giải thích: +0,03R/lệnh gộp khi cho winner chạy

Hai khả năng:

- **(a) Trend-persistence thật của vàng ở khung giờ–ngày**, thứ mà trailing rộng khai thác. Văn liệu ủng hộ
  time-series momentum ở chân trời dài (Moskowitz, Ooi & Pedersen 2012) nhưng với giao dịch trong ngày thì thường *không*
  đủ bù chi phí (xem §10).
- **(b) Beta của thị trường tăng**: vàng tăng mạnh 2018–2026, rule "fast ≥ slow ⇒ BUY" thiên về mua; lệnh giữ lâu hưởng
  drift. Đây không phải edge — là cược vào xu hướng tăng dài hạn, và sẽ biến mất/đảo chiều theo regime.

### 5.1 E1 đã chạy (2026-11-10) — và nó **bác bỏ** giả thuyết có edge

Công cụ: [`scripts/tester/ir_breakdown.py`](../../scripts/tester/ir_breakdown.py) (streaming, tách theo **hướng ×
năm × đuôi**, một lần đọc journal; nhãn `NOT_STRATEGY_RESULT`). Bằng chứng:
[`evidence/infinite-runner/`](evidence/infinite-runner/README.md) (`e1_*.json`). Gross/lệnh = net + chi phí spread
(`--spread-price 0.19`, tức ~0,038R ở SL 1R = 5,00 giá).

| Journal | n | gross (R/lệnh) | BUY | SELL | gross **bỏ 0,5% lệnh tốt nhất** |
|---|---:|---:|---:|---:|---:|
| `long_base_nolock` | 26.130 | +0,0328 | +0,0399 | +0,0258 | **−0,0411** (đảo dấu) |
| `long_exit_run` | 34.238 | +0,0259 | +0,0269 | +0,0249 | **+0,0048** (gần 0) |

**Đọc:** gross dương **ở cả hai hướng** ⇒ *không* phải beta chỉ-mua; **nhưng biến mất khi bỏ 0,5% lệnh tốt nhất**
⇒ theo tiêu chí bác bỏ ghi trước ở §8, đây là **may mắn/đuôi chứ không phải trend-persistence đáng tin**. Và ngay
cả khi giữ nguyên, +0,026–0,033R **nhỏ hơn spread (~0,038R)** nên net vẫn âm. Kết luận: **giả thuyết (a) không
được dữ liệu ủng hộ** ⇒ không đầu tư tiếp vào biến thể trend (H-B/H-D) trên tín hiệu entry hiện tại; (b) cũng
không đứng vững vì edge không nằm riêng ở phía BUY.

**Điều quan trọng cho mục tiêu của bạn:** chi phí là *cố định theo lệnh* (~$0,19 / 0,01 lot), còn lãi gộp (nếu thật) *tích
luỹ theo thời gian giữ lệnh*. Vì vậy cấu trúc "ít lệnh, giữ lâu, SL/trail theo khung lớn" có logic nội tại; cấu trúc hiện tại
(SL 5 giá, step trail cắt ở 0,36R, vào lại ngay mỗi nến) làm ngược lại. Lưu ý: **mở rộng SL một mình không giúp** — nó giảm
chi phí tính theo R (`s/SL`: 0,038R ở SL 5 → 0,013R ở SL 15) nhưng giảm cả lãi gộp tính theo R; chỉ phần *thời gian giữ lâu
hơn* mới đổi tỉ số lãi-gộp/chi-phí.

### 5.2 Lọc chi phí (H-C) và biến thể bỏ giới hạn tần suất — đã đo (2026-11-10)

H-C và một biến thể **ngược H-A** (bỏ giới hạn tần suất, theo yêu cầu chủ dự án), chạy trên cửa sổ đầy đủ
2018-2026 (khoá daily/DD tắt như §3; engine = step trailing shipped). Bằng chứng:
`evidence/infinite-runner/infinite_runner_long_{nolimit,spread200}.json`.

| Cấu hình | Lệnh | Winrate | Net | Exp R (CI95) | gross | net spread×2 | net_without_tp | MaxDD |
|---|---:|---:|---:|---|---:|---:|---:|---:|
| `long_base_nolock` (giới hạn cũ, tham chiếu) | 26.130 | 72,97% | −685 | −0,005 [−0,020..+0,011] | +4.279 | −5.650 | −8.157 | 22,48% |
| `long_nolimit` (bỏ trần lệnh/ngày + khoảng cách nến) | 30.551 | 72,83% | **+2.192** | +0,014 [−0,002..+0,031] | +7.997 | −3.613 | **−9.370** | 22,41% |
| `long_spread200` (không vào khi spread > 200) | 14.387 | 73,11% | +219 | +0,003 [−0,018..+0,027] | +2.953 | −2.514 | −4.164 | **17,16%** |

**Đọc (đúng tiêu chí bác bỏ của H-A/H-C):**

- **Bỏ giới hạn tần suất** chỉ tăng ~17% số lệnh (một vị thế + cấm vào lại trong cùng nến M5 vẫn giới hạn),
  net chuyển dương nhẹ nhưng **vẫn nhờ 116 lệnh chạm TP 20R** (`net_without_tp` = −9.370) và **âm ở spread×2**;
  CI của R bao 0 ⇒ không phải edge bền ⇒ *giảm giới hạn ≠ tạo lãi*.
- **Lọc chi phí (spread ≤ 200)** halved số lệnh và **giảm DD mạnh (22,5%→17,2%)** nhưng net ≈ 0 (CI bao 0) ⇒
  *lọc chi phí chỉ giảm lỗ/biến động, không tạo lãi* — kết quả vẫn hữu ích: một cấu hình ít lệnh, ít đau hơn.

Cả hai xác nhận lại kết luận §5.1: phần dương luôn nằm ở đuôi và nhỏ hơn chi phí; **không cấu hình nào tạo ra
expectancy dương bền**.

### 5.3 H-D (entry theo regime) đã đo (2026-11-10) — bác bỏ

`IR_DIR_REGIME` = H1 context + M5 breakout K=12 (spec:
[infinite-runner-regime-entry-spec.md](infinite-runner-regime-entry-spec.md)), engine exit shipped, cửa sổ đầy đủ
2018-2026 (khoá daily/DD tắt). Bằng chứng: `evidence/infinite-runner/infinite_runner_long_regime.json`.

| Cấu hình | Lệnh | Winrate | Net | Exp R (CI95) | gross | net spread×2 | net_without_tp | MaxDD |
|---|---:|---:|---:|---|---:|---:|---:|---:|
| `long_regime` (H-D) | 3.260 | 71,60% | **−434** | −0,027 [−0,067..+0,020] | +185 | −1.054 | −1.232 | 5,09% |

**Đọc:** ít lệnh hơn nhiều (3.260 vs 26.130) và **DD rất nhỏ (5,1%)** — đúng tinh thần "ít lệnh, bớt đau" — nhưng
**expectancy vẫn âm** (−0,027R), gross gần 0 (+185 ≈ +0,011R/lệnh) và **âm ở spread×2**. Theo tiêu chí bác bỏ
trong spec ("trong mẫu < 0 sau chi phí") ⇒ **H-D bị bác bỏ**: entry theo regime **không tạo edge** trên dữ liệu này.

### 5.4 H-B (trend khung lớn + ATR) đã đo (2026-11-10) — dương nhưng là **BETA**

Config-only trên EA hiện có: entry H1/H4 (legacy), SL `ATR×3`, trail `ATR×2`, step off, khoá daily/DD tắt. Bằng
chứng: `evidence/infinite-runner/infinite_runner_long_htf_{h1,h4}.json`.

| Cấu hình | Lệnh | Winrate | Net | Exp R (CI95) | net spread×2 | tp_hits | MaxDD |
|---|---:|---:|---:|---|---:|---:|---:|
| `long_htf_h1` | 1.828 | 49,56% | +1.381 | +0,018 [−0,054..+0,050] | **+1.034** | 0 | 11,8% |
| `long_htf_h4` | 538 | 53,53% | +1.351 | +0,024 [−0,059..+0,123] | **+1.249** | 0 | 12,8% |

**Đây là ứng viên DUY NHẤT tới nay dương, KHÔNG phụ thuộc đuôi** (`net_without_tp` = net, `tp_hits` = 0) **và vẫn
dương ở spread×2**. Nhưng **E1 phá vỡ nó**:

- **Chỉ dương ở BUY**: `htf_h1` BUY +0,071R vs SELL −0,011R; `htf_h4` BUY +0,113R vs SELL −0,029R.
- **Tập trung theo năm**: `htf_h1` **âm cả 2018–2022**, chỉ dương 2023–2026; `htf_h4` dồn vào **2026** (+0,236R,
  60 lệnh) và 2025 âm.

Theo tiêu chí bác bỏ đã ghi trước của E1 ("gộp > 0 chỉ ở BUY, hoặc chỉ 1–2 năm ⇒ beta/may mắn"), H-B là **beta
của uptrend vàng 2018–2026**, không phải edge — OOS 2018–2022 đã âm ngay trong bảng theo năm. CI của R vẫn bao 0.

## 6. Khoảng cách backtest ↔ chạy thật

| Rủi ro | Hiện trạng trong repo | Việc cần |
|---|---|---|
| Mô hình tick | `Model=1` (1-phút OHLC) trong `gen_ir_sets.py`; không có `Spread=` trong `.ini` | chạy lại các ứng viên cuối bằng real ticks; ghi spread dùng |
| Spread theo giờ | spread vàng khác nhau vài lần theo giờ/nhà môi giới; roll-over thường rất rộng | log spread vào journal; lọc giờ chi phí cao (H-C) |
| Swap/financing | runner giữ lệnh qua đêm; chưa thấy swap trong metric | thêm swap vào journal/metric |
| Trượt giá & phí | suy ra ≈ $0,03/lệnh từ §3 | đo trên demo thật (cần ≥ vài trăm lệnh) |
| Dữ liệu 8,75 năm là *một* đường giá | một regime tăng dài | walk-forward + kiểm theo năm |

## 7. Quy mô kỳ vọng và lượng mẫu cần để tin

Lãi xấp xỉ theo năm (không lãi kép, rủi ro cố định `r` mỗi lệnh): `năm% ≈ N × e × r`, với `N` lệnh/năm, `e` expectancy
**ròng** (R/lệnh). Ở `r = 0,25%`:

| N lệnh/năm | e = 0,02R | e = 0,05R | e = 0,10R | e = 0,20R |
|---:|---:|---:|---:|---:|
| 250 (~1/ngày) | 1,2% | 3,1% | 6,2% | 12,5% |
| 1.000 | 5,0% | 12,5% | 25% | 50% |
| 3.000 (≈ V2 hiện nay) | 15% | 37% | 75% | 150% |

Số lệnh cần để phát hiện `e` (độ lệch chuẩn ≈ 1R, kiểm định một phía 95%, power 80%): `n ≈ ((1,645+0,84)/e)²`:

| e (R/lệnh) | 0,01 | 0,02 | 0,03 | 0,05 | 0,10 |
|---|---:|---:|---:|---:|---:|
| n cần | ~61.800 | ~15.400 | ~6.900 | ~2.500 | ~620 |

**Mâu thuẫn cốt lõi:** edge nhỏ cần mẫu lớn để *chứng minh*, mẫu lớn đòi tần suất cao, tần suất cao nhạy với chi phí. Ở
1 lệnh/ngày (250/năm) cần ~10 năm để thấy `e = 0,05R`. Vì vậy: (1) ưu tiên giả thuyết có cơ sở lý thuyết trước, (2) dùng
nhiều symbol/khung thời gian độc lập nếu muốn tăng mẫu, (3) forward test demo phải dài và không được "ngó" để chỉnh tham số.

## 8. Giả thuyết và thí nghiệm (spec trước, tiêu chí bác bỏ ghi sẵn)

Mỗi thí nghiệm đổi **một biến**, chạy trên cùng cửa sổ 2018.01.01 → 2026.10.01 để so sánh với bảng §3, rồi mới sang
cửa sổ ngoài mẫu. Dưới đây ID `E*` là thí nghiệm không cần/ít cần code mới, `H*` là giả thuyết cần entry/exit mới.

| ID | Việc | Cách làm | Bác bỏ nếu |
|---|---|---|---|
| **E1** ✅ | Phân rã lãi gộp ở §5 (**đã chạy 2026-11-10**, xem §5.1) | từ journal `long_exit_run`/`long_base_nolock`: tách theo **hướng** (BUY/SELL) × **năm** × **phân vị lệnh** | gộp > 0 chỉ ở BUY, hoặc chỉ ở 1–2 năm, hoặc biến mất khi bỏ 0,5% lệnh tốt nhất ⇒ là beta/may mắn, không phải edge. **Kết quả: biến mất khi bỏ 0,5% ⇒ bác bỏ** |
| **E2** | Kiểm spread theo giờ | thêm cột spread vào journal; nhóm lệnh theo giờ server | lãi gộp/lệnh không khác giữa giờ rẻ và giờ đắt |
| **E3** | Port U1 vào V3, rồi đo V3 trên cửa sổ đầy đủ với BE ∈ {0, 1,0, 1,5R} | theo quy trình Giai đoạn B của guide V3 (`99-archive/MT5_EA_Lab_V3/EA/InfiniteRunnerXAUV3_UpgradeGuide_Vietnamese.md`) | V3 net không tốt hơn `long_exit_run` (−2.078) ngoài sai số ⇒ structure trailing không thêm giá trị |
| **H-A** | **Giảm tần suất**: vào lệnh tối đa 1–3 lần/ngày, `InpCooldownMinutes` ≥ 60 | chỉ đổi giới hạn entry (input có sẵn) | tổng chi phí giảm nhưng gộp/lệnh không tăng ⇒ chỉ giảm lỗ, không tạo lãi (kết quả vẫn hữu ích: đây là biến kiểm soát). *Biến thể ngược (bỏ giới hạn) đã đo 2026-11-10 → §5.2* |
| **H-B** ✅ | **Giữ lâu**: SL theo ATR khung H1, trail theo cấu trúc M15/H1 | `IR_SL_ATR`/`IR_TRAIL_ATR` (**đã đo 2026-11-10** → §5.4) | gộp/lệnh không tăng theo thời gian giữ. **Kết quả: dương + bền spread×2 nhưng BUY-only + theo năm ⇒ beta, bác bỏ** |
| **H-C** ✅ | **Lọc chi phí**: không vào lệnh khi spread > ngưỡng hoặc giờ roll-over | `InpMaxSpreadPoints` hạ 600→200 (**đã đo 2026-11-10** → §5.2); lọc giờ chưa làm | lệnh bị loại không kém lệnh giữ lại. **Kết quả: halved lệnh, DD 22,5%→17,2%, net ≈ 0 ⇒ chỉ giảm lỗ** |
| **H-D** ✅ | **Entry theo regime** (H1 context + M5 breakout K nến), 1 lệnh/regime | spec: [infinite-runner-regime-entry-spec.md](infinite-runner-regime-entry-spec.md); `IR_DIR_REGIME` mới, **không** sửa mode hiện có | OOS expectancy cận dưới CI ≤ 0. **Kết quả: −0,027R (CI bao 0), gross ≈ 0 ⇒ bác bỏ** |
| **H-E** | **Hồi phục sau khoá DD** (thay halt vĩnh viễn bằng pause + giảm risk) | cần ADR riêng vì nới hàng rào an toàn | DD tối đa vượt 15% hoặc halt tái diễn |
| **H-F** | Mean-reversion sau ngày biến động bất thường | spec mới; một nghiên cứu học thuật thấy hiệu ứng contrarian ngày kế tiếp ở vàng nhưng *giới hạn theo thời gian* (§10) | không tái lập ngoài mẫu |

Quy tắc chung (từ [`risk.md`](risk.md), [`testing.md`](testing.md) và bài học WW2/IR): không lấy kết quả đẹp nhất của một
đoạn ngắn; chia cửa sổ theo thời gian (phát triển / ngoài mẫu); chọn tham số **trước** khi nhìn OOS; ghi mọi lần chạy
(kể cả âm) vào evidence; nhân đôi spread khi đánh giá.

## 9. Cổng chấp nhận (không nâng nhãn nếu chưa qua)

| Cổng | Điều kiện | Nhãn sau cổng |
|---|---|---|
| G0 — Tái lập | `.set` sinh từ `configs/demo/infinite_runner_demo.json`, scenario có tên, journal 18 cột, hash cấu hình | `NOT_RUN` → `PARTIAL` (hạ tầng) |
| G1 — Trong mẫu | expectancy ròng cận dưới CI 95% > 0 **với spread ×2**, ≥ n ở §7 | giữ `UNPROVEN` |
| G2 — Ngoài mẫu | walk-forward ≥ 3 cửa sổ liên tiếp, cùng dấu, DD ≤ 15%, không halt vĩnh viễn | giữ `UNPROVEN` |
| G3 — Real ticks | G1 lặp lại bằng real ticks + swap | giữ `UNPROVEN` |
| G4 — Forward demo | ≥ 3 tháng demo thật, số lệnh ≥ ngưỡng §7 hoặc ≥ 300 lệnh, không can thiệp tay | chỉ khi qua G4 mới xét đổi nhãn bằng một mục `PROGRESS.md` có bằng chứng |

Không cổng nào trong số này cho phép tài khoản real/live: phạm vi repo vẫn là demo + Strategy Tester (ADR 0002–0004).

## 10. Nguồn tham khảo ngoài (đọc có trọng số)

Tra cứu 2026-11-09. Chỉ dùng để *đặt giả thuyết*, không phải bằng chứng cho EA này.

| Nguồn | Ý chính (diễn đạt lại) | Trọng số |
|---|---|---|
| [IDEAS/RePEc, *Financial Analysis* v60 (2018) 177–196](https://ideas.repec.org/a/eee/finana/v60y2018icp177-196.html) | Thử momentum/đảo chiều trên dữ liệu futures hàng hoá theo phút với chi phí thực tế: chiến lược ngày không bù nổi chi phí do vòng quay cao | Cao (học thuật, đồng nghĩa với §3) |
| Moskowitz, Ooi & Pedersen (2012), *J. Financial Economics* 104(2) | Time-series momentum xuất hiện ở chân trời dài trên nhiều tài sản | Cao, nhưng **không** phải khung M5 |
| [Springer, *Financial Markets and Portfolio Management* (2021)](https://link.springer.com/10.1007/s11408-021-00380-w) | Sau ngày lợi suất bất thường, vàng có xu hướng đảo chiều ngày kế tiếp; hiệu ứng giới hạn theo thời gian | Trung bình (cơ sở cho H-F) |
| [Donati & Jung, luận văn thạc sĩ CBS](https://research.cbs.dk/en/studentProjects/gold-price-dynamics-around-the-clock/) | Mùa vụ trong ngày của vàng; chiến lược khai thác thắng thị trường **khi chưa tính chi phí** | Thấp–trung bình (luận văn) |
| [MQL5 blog 2026-08-18, backtest vàng với real tick](https://www.mql5.com/en/blogs/post/774275) | Chi phí là yếu tố bậc nhất; lợi thế theo khung giờ hẹp phân rã nhanh | Thấp–trung bình (thực hành) |

## 11. Việc cần chủ dự án quyết

1. **Chấp nhận khung:** V3 là *phòng thí nghiệm exit* (đo MFE capture), không phải bản thay V2 — đồng ý?
2. ~~Cho phép chạy **E1** trước~~ — **E1 đã chạy 2026-11-10 và bác bỏ edge** (§5.1); quyết định còn lại là
   *đầu tư tiếp vào hướng khác hay dừng*.
3. Quyết định chính sách **khoá DD** (H-E): giữ halt vĩnh viễn (an toàn, bot không chạy lâu) hay pause + giảm risk (cần ADR).
4. Đặt **equity demo và risk %** hợp lý với §2/§7 (nếu equity < $2.000, V3 theo risk-lot sẽ bỏ qua mọi lệnh).

## 12. Tái lập các bảng §3–§4

Chỉ cần các file đã commit trong `evidence/infinite-runner/` (không cần MT5). Lưu thành `scratch.py` rồi chạy
`.venv\Scripts\python.exe scratch.py` từ thư mục gốc repo (không commit file này):

```python
import json, math
from pathlib import Path

EV = Path("docs/30-research/evidence/infinite-runner")
S = 0.19  # spread suy ra, đơn vị giá (≈ 190 điểm)

for name in ("long_base_nolock", "long_exit_run", "long_fixedrr", "long_fixedrr15", "long_fixedrr_clean"):
    j = json.loads((EV / f"infinite_runner_{name}.json").read_text(encoding="utf-8"))
    n, net = j["trades"], j["net"]
    aw, al = j["avg_win"], abs(j["avg_loss"])
    p = j["wins"] / n
    p_be = al / (aw + al)                      # winrate hoà vốn
    gross = net + n * S                        # lãi gộp trước spread (xấp xỉ)
    print(f"{name:20s} n={n:6d} p={p:.4f} p*={p_be:.4f} net={net:9.1f} "
          f"N*s={n*S:8.1f} gross={gross:8.1f} ({gross/n/5:+.4f}R/lệnh)")
```

Spread suy ra từ lần chạy SL/TP cố định: `s = A − p × (A + B)` với `A = 5,0`; `B = 5,0` (1:1) hoặc `7,5` (1:1,5). Số trong §3
dùng `s = 0,19`. Lệch lớn giữa `N × s` và net đo được là dấu hiệu cần phân rã (E1), không phải bằng chứng edge.

## 13. Kết luận & "cách tốt nhất" (khuyến nghị)

Bảy hướng entry/exit đã đo — legacy M5, E-A (bỏ cổng M1), exit step/trail-rộng/không-trail, `IR_DIR_EMA_MTF`, H-D
(regime), H-B (trend khung lớn + ATR) — **đều không tạo edge**; mọi cấu hình dương đều là **đuôi** (kiểm bằng
`net_without_tp`) hoặc **beta** (kiểm bằng spread×2 và E1 hướng × năm). Ứng viên "đẹp" nhất (H-B, §5.4) dương và
bền spread×2 nhưng **chỉ ở BUY và theo năm** ⇒ là beta của uptrend vàng, không phải lợi thế giao dịch.

**Cách tốt nhất để KIỂM TRA (đã áp dụng cho mọi arm):** một ứng viên chỉ đáng tin khi qua **cả ba** — (1) net > 0
**khi nhân đôi spread**; (2) `net_without_tp` không âm mạnh (không phải đuôi); (3) E1 hướng × năm: dương ở **cả
hai hướng** và **nhiều năm**. Hạ tầng miễn phí, chạy lại được: `scripts/tester/analyse_ir.py` (CI/`p*`/spread),
`scripts/tester/ir_breakdown.py` (E1), `scripts/run_gates.py`, và evidence pack nhỏ đã commit.

**Cách tốt nhất để NÂNG CẤP (khuyến nghị, theo thứ tự):**

1. **Dừng tinh chỉnh tín hiệu hiện tại.** Bảy hướng, 0 edge: dữ liệu không ủng hộ thêm tham số/exit nào. Giữ
   **U1** (sửa deadlock) làm lợi ích vận hành thực — robot không còn tự chết.
2. **Nếu muốn tiếp: đổi DỮ LIỆU/Ý TƯỞNG, không đổi tham số.**
   - **Đa tài sản / đa khung**: chạy cùng logic trên nhiều symbol (EURUSD, XAGUSD, chỉ số…) để tăng **mẫu độc
     lập** — cách thực tế nhất để kết luận nhanh.
   - **H-F** (đảo chiều sau ngày bất thường, có nguồn học thuật §10): cần **spec + code mới**, mẫu lớn, OOS.
   - **Cổng ML (T4)**: chỉ có nghĩa khi tín hiệu nền đã có **gross edge**; hiện chưa có, nên **chưa nên** làm.
3. **Cổng chấp nhận G1–G4 (§9)** áp cho mọi ứng viên mới; **không nâng nhãn** `UNPROVEN` khi chưa có forward demo.

Nói ngắn: **giá trị của InfiniteRunner là hạ tầng demo (đã chứng minh), không phải chiến lược (chưa chứng minh).**
