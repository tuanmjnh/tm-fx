# Ghép bot EA với AI — mức tích hợp, pipeline ONNX, ràng buộc parity

> Ghi chú 2026-11-11: repo nay chỉ còn bot InfiniteRunner; các EA/indicator được nhắc trong tài liệu này là lịch sử.

**Tách từ:** mục 11 của guide cũ `ea-anatomy-and-ai.md` (file cũ đã bị tách thành `docs/10-bots/ea-anatomy.md` + tài liệu này; nguyên văn còn trong git
history — ánh xạ cũ → mới xem `99-archive/LINK_MAP.md`).
**Phạm vi:** mọi nhận định lấy từ source và artifact thật của repo (MQL5 build 6292).
**Trạng thái tổng:** AI chỉ ở mức **cửa thêm** trên tín hiệu; chưa có bằng chứng parity trên dữ liệu
thật. Chi tiết trạng thái từng hạng mục ở mục 5.
**Đọc kèm:** giải phẫu chung của EA ở [`../10-bots/ea-anatomy.md`](../10-bots/ea-anatomy.md);
chi tiết pipeline ONNX ở [`onnx.md`](onnx.md); ML baseline ở [`ml-baseline.md`](ml-baseline.md).

---

## 1. Ba mức tích hợp AI (tăng dần chi phí)

| Mức | Là gì | Trong repo | Ưu | Nhược / rủi ro |
|---|---|---|---|---|
| A — scoring rule-based | indicator tự cho điểm `rawScore ∈ [-1,1]` → `score100 = 50 + rawScore*50`, cổng `okScore = score100 > InpScrNoTrade` | `PriceActionMTFContract.mqh` + `PinePlanSimEA` | Đang chạy thật; rẻ, dễ audit, không cần model | Tĩnh: cổng điểm không học từ dữ liệu. Lưu ý quirk `Q11`: cửa short gần như luôn bị chặn ⇒ bot chỉ BUY |
| B — ML inference ONNX | Python train → xuất ONNX → EA `OnnxRun` ra xác suất → dùng xác suất làm **cửa thêm** | `LabOnnxInference.mq5`, `scripts/export_onnx_model.py` | Đã chạy được trên chart + Strategy Tester; parity có fixture | Chỉ đọc feature từ fixture, **chưa** đọc feature từ bar live; model tuyến tính đầu tiên |
| C — AI quyết định sizing/hướng + EA thực thi | model chọn hướng/kích thước, EA vẫn giữ RiskGuard + ExecGuard | chưa tồn tại | Phát huy tối đa model | Độ phức tạp + rủi ro lớn nhất; `NOT_RUN` — và chỉ được làm trên demo, sau ADR riêng |

Thứ tự tăng chi phí và rủi ro là A → B → C. Mức A và B là **lọc tín hiệu** (EA vẫn tự giữ toàn bộ cổng
rủi ro); mức C mới để model đụng vào quyết định lệnh — và nó phải qua ADR trước khi tồn tại.

## 2. Pipeline B: offline train → export ONNX → EA đọc tín hiệu

```text
CSV nến/synthetic ─► scripts/generate_synthetic_ml_dataset.py
                  ─► scripts/train_ml_baseline.py --config … --out-dir reports\ml\… --store … --db … --experiment-id …
                       (feature pipeline + label không rò rỉ + time split có purge + logistic)
                  ─► reports\ml\demo-phase7-ml\model.json   (12 feature, mean/scale, threshold)
                  ─► scripts/export_onnx_model.py --model … --out-dir models\candidates\demo-phase7-ml
                          --fixture python\tests\fixtures\onnx_feature_fixture.csv --opset 13 --tolerance 1e-5
                  ─► models\candidates\demo-phase7-ml\model.onnx  (SHA-256 ghi trong 30-research/onnx.md)
                  ─► copy vào DATA_FOLDER\MQL5\Files
                  ─► LabOnnxInference.mq5: OnnxCreate(30) → matrixf(1,12) → OnnxRun(113) → probability
```

Điểm chính của từng chặng:

| Chặng | Nơi | Bắt buộc |
|---|---|---|
| Tạo dataset | `scripts/generate_synthetic_ml_dataset.py` | CSV nến hoặc synthetic; không dùng dữ liệu ngoài repo |
| Train | `scripts/train_ml_baseline.py` | feature pipeline + label không rò rỉ + time split có purge |
| Export | `scripts/export_onnx_model.py` | `--fixture` + `--opset 13` + `--tolerance 1e-5`; ghi SHA-256 |
| Đóng gói test | `LabOnnxInference.mq5` | `#property tester_file "model.onnx"` + fixture (Tester agent xoá sạch sandbox `MQL5\Files` mỗi lần chạy — không copy tay được, phải qua `tester_file`) |
| Chạy | `OnnxCreate` → `matrixf(1, InpFeatureCount)` → `OnnxRun` | in xác suất từng hàng; không gửi lệnh |

Một lệnh cho cả chuỗi nghiên cứu (backtest + ML + báo cáo): `scripts\run_pipeline.py --config … --run-id …`.

## 3. Ràng buộc: bảng cấu hình phải khớp tuyệt đối giữa Python và MQL5

Đây là phần nguy hiểm nhất của mức B: model **không biết** nó đang được cho ăn feature sai — lệch một
cột là **sai âm thầm** (chạy 0 error, ra số sai). Mọi dòng trong bảng dưới phải khớp tuyệt đối:

| Hợp đồng | Nơi khai (Python) | Nơi EA phải khớp | Lệch thì |
|---|---|---|---|
| Thứ tự feature | `feature_schema.json` / `metadata.input.feature_names`: `return_1, return_3, return_5, return_10, ema_gap, ema_slope, volatility, return_z, stochastic, range_ratio, body_ratio, volume_z` | code dựng vector | model vẫn chạy, ra số **sai mà không báo lỗi** |
| Số feature | 12 | `InpFeatureCount` (dựng `matrixf(1, InpFeatureCount)`) | `OnnxRun` trả lỗi, EA in `OnnxRun failed at row …` rồi dừng |
| Kiểu dữ liệu | `float32`, input shape `[batch,12]` | `matrixf` + cast `(float)` | sai dtype ⇒ lỗi run |
| Chuẩn hoá | mean/scale **nhúng trong graph** (Sub/Div) | EA *không* tự chuẩn hoá | chuẩn hoá 2 lần ⇒ xác suất vô nghĩa |
| Ngưỡng quyết định | `decision_threshold = 0.5` trong `reports\ml\demo-phase7-ml\model.json` | nơi gate ENTRY | đổi ngưỡng = đổi chiến lược, phải ghi rõ trong preset |
| Opset / IR | opset 13, IR 8 | runtime ONNX của build 6292 | build terminal khác: `CHƯA KIỂM` |
| Đóng gói khi test | `#property tester_file "model.onnx"` + fixture | — | Tester agent không có model ⇒ fail `5019` (`ERR_FILE_NOT_EXIST`) |
| Parity | dung sai tuyệt đối `1e-5`, 24 hàng | so Python ↔ ONNX | lệch là dừng, không "chấp nhận gần đúng" |

Vì sao nghiêm ngặt như vậy: feature lệch thứ tự hoặc lệch công thức không gây exception nào — model vẫn
trả xác suất hợp lệ. Cơ chế duy nhất phát hiện là parity test (`1e-5`, 24 hàng fixture) và việc **luôn
tính feature từ cùng một hàm** giữa Python và MQL5.

## 4. Công thức ghép an toàn (khuyến nghị)

```text
VÀO LỆNH  =  plan hợp lệ (SimPlan, RR ≥ InpPaRrMin)
          ∧  RiskGuard không block (spread/độ hở/cooldown)
          ∧  chưa HALTED (daily loss, drawdown)
          ∧  P(thắng) ≥ threshold            ← phần AI, chỉ là CỬA THÊM
```

Ba quy tắc không được phép đổi:

1. Model **không bao giờ** là cửa duy nhất; cổng rủi ro vẫn là chốt cuối. AI chỉ được **lọc** tín hiệu —
   không được bỏ qua SL/TP, không được nới `InpRiskPercent`, không được tắt kill switch hay RiskGuard.
2. Feature phải tính từ dữ liệu **đã đóng nến**, cùng công thức với lúc train (không leak).
3. Mọi đổi ngưỡng/feature phải thành preset + `.set` mới, kèm `config_hash`, không sửa tay trong GUI rồi báo cáo.

Hệ quả thực tế: mức B trong trạng thái hiện tại chỉ đủ để **chặn thêm lệnh** (xác suất thấp ⇒ không vào),
chưa đủ để **mở thêm lệnh** hay đổi khối lượng.

## 5. Trạng thái hiện tại

| Hạng mục | Trạng thái |
|---|---|
| Mức A (scoring rule-based) | ĐANG CHẠY trong `PinePlanSimEA` qua cổng `okScore` (quirk `Q11`: chỉ BUY) |
| Mức B — ONNX inference trong Tester | PASS build 6292, 24/24 hàng parity max diff `4.927e-08` (PROGRESS §50) |
| Mức B — ONNX đọc feature từ bar live | **chưa có** — chỉ chạy fixture |
| Mức C (AI quyết định sizing/hướng) | **`NOT_RUN`** — chưa tồn tại, phải qua ADR, chỉ trên demo |
| Parity trên dữ liệu thật (không phải fixture) | **`READY_FOR_MANUAL_VALIDATION`** — chưa có bằng chứng parity trên dữ liệu thật |
| Build terminal khác 6292 | **`CHƯA KIỂM`** |
| Lợi nhuận mọi chiến lược | **`UNPROVEN`** |

Bằng chứng chi tiết: [`../PROGRESS.md`](../PROGRESS.md) §50 (tester + parity fixture),
[`onnx.md`](onnx.md) (SHA-256 model, opset, graph), [`ml-baseline.md`](ml-baseline.md) (train).
Nhãn trạng thái dùng ở bảng trên theo bộ 9 nhãn dự án (6 hợp đồng `DONE/PASS/PARTIAL/NOT_RUN/BLOCKED/
UNPROVEN` + 3 phụ, gồm `READY_FOR_MANUAL_VALIDATION`); định nghĩa gốc trong PROGRESS, trang tổng hợp
bằng chứng sẽ có ở `20-operations/evidence.md` (chưa tồn tại khi viết dòng này).

---

## 6. Phụ lục: bối cảnh mức A trong repo

Mức A không phải "AI học máy" — nó là **cổng điểm tĩnh** do indicator tự tính, nhưng nó là khung mà cả
mức B lẫn mức C sẽ chèn vào, nên ghi lại tại đây:

- Nơi khai cổng: `PriceActionMTFContract.mqh` tính `rawScore` từ các buffer điểm của indicator; EA mô
  phỏng đổi sang thang 100 (`score100 = 50 + rawScore*50`) và so với `InpScrNoTrade`.
- Hành vi thật đã kiểm: với default `InpScrNoTrade=49`, điều kiện `score100 > 49` ⇔ `rawScore > -0.01`,
  trong khi nhánh SHORT đòi `rawScore < 0` — giao tử gần rỗng nên **cửa short gần như luôn bị chặn**
  (quirk `Q11` của indicator PriceActionMTF, đã gỡ cùng indicator PinePort).
- Hệ quả cho mức B/C: khi xác suất model thay cổng điểm, vẫn phải giữ nguyên các cổng còn lại
  (plan RR, RiskGuard, HALT) — nếu không, quirk Q11 chỉ chuyển từ "cổng điểm chặn" thành "cổng model chặn".

## 7. Phụ lục: những gì mức B còn thiếu để lên đường lệnh demo

Model logistic đầu tiên đã qua tester, nhưng để đưa tín hiệu ONNX vào một EA demo thật (đường `Exec/*`)
còn thiếu các mảnh sau — ghi rõ để phase sau không phải đoán:

| Mảnh còn thiếu | Vì sao cần |
|---|---|
| Feature builder cho EA demo (đọc bar live, tính 12 feature cùng công thức với Python) | hiện chỉ có fixture CSV cứng |
| Gate xác suất trong DemoEA, cấu hình qua preset (`InpFeatureCount` + threshold) | phải đi qua `configs/demo/*.json` + `.set`, không hard-code |
| Parity trên dữ liệu thật (không phải fixture 24 hàng) | `READY_FOR_MANUAL_VALIDATION` — chưa có bằng chứng |
| ADR riêng cho mức B trên đường lệnh | mức B hiện chỉ tồn tại ở EA inference không gửi lệnh |

Điều kiện tiên quyết chung: mọi thay đổi đều qua validator + compile trong cùng commit và ghi PROGRESS,
đúng quy tắc preset ở [`../10-bots/input-convention.md`](../10-bots/input-convention.md).

---

## 8. Phụ lục: checklist bật mức B lên đường lệnh (khi có ADR)

Đây là bản dịch của mục 7 sang dạng kiểm tra được — khi ADR cho phép mức B tham gia quyết định lệnh,
từng dòng dưới đây phải **đạt trước** khi merge, không phải "hứa sửa sau":

| # | Điều kiện kiểm | Cách kiểm |
|---|---|---|
| 1 | Feature builder của EA demo tính đúng 12 feature | contract test so với Python trên cùng bộ nến, lệch ≤ `1e-5` |
| 2 | `InpFeatureCount` + threshold nằm trong preset | `configs/demo/*.json` + validator từ chối khi thiếu |
| 3 | `.set` sinh từ preset, không sửa tay trong GUI | quy trình ở [`../20-operations/presets.md`](../20-operations/presets.md) |
| 4 | Model ONNX khớp SHA-256 đã ghi | so hash trước khi copy vào `MQL5\Files` |
| 5 | Gate xác suất chỉ **chặn thêm**, không mở thêm | review: đường `Exec/*` không đọc xác suất để tăng volume |
| 6 | RiskGuard/HALT vẫn chạy **trước** gate AI | test: xác suất cao vẫn bị block khi spread/cooldown vi phạm |
| 7 | Parity trên dữ liệu thật có bằng chứng | `READY_FOR_MANUAL_VALIDATION` chuyển thành mục bằng chứng ghi PROGRESS |
| 8 | ADR mới merge trước code | số ADR được tham chiếu trong trang bot tương ứng |

Bất kỳ dòng nào chưa đạt ⇒ mức B giữ nguyên địa vị hiện tại: chỉ chạy trong `LabOnnxInference`
(đọc fixture, in xác suất), không đụng vào đường `Exec/*`. Đây cũng là cách đọc trạng thái bảng ở mục 5:
mỗi dòng `NOT_RUN`/`PARTIAL` ở đó tương ứng một dòng checklist ở đây.
