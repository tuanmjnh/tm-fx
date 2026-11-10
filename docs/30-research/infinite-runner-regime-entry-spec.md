# Spec — InfiniteRunner entry theo regime (H-D)

**Ngày:** 2026-11-10 · **Trạng thái:** spec đã duyệt để hiện thực (H-D trong
[long-run study](infinite-runner-long-run-study.md) §8) · **EA:** `InfiniteRunnerXAUV2DemoEA`
(magic `25006001`) · **Phạm vi:** demo / Strategy Tester · **Nhãn:** `NOT_STRATEGY_RESULT` đến khi qua
cổng G1–G4.

## 1. Vì sao làm

Mọi entry đã đo (EMA "legacy" M5, EMA_MTF) **không có edge**; các exit chỉ đổi hình dạng winrate. Phân tích E1
(study §5.1) cho thấy phần dương là đuôi, và chi phí **cố định theo lệnh** (~0,19 giá) trong khi edge (nếu có)
tích luỹ theo thời gian giữ. Giả thuyết H-D: **ít lệnh hơn, mỗi lệnh gắn với một regime khung lớn + xác nhận
breakout** ⇒ tỉ lệ lãi-gộp/chi-phí cao hơn. Đây là entry **mới**, không sửa mode hiện có.

## 2. Định nghĩa (chốt trước khi code)

`InpDirectionMode = 2` ⇒ **`IR_DIR_REGIME`**:

- **Bối cảnh H1** (nến H1 đã đóng, dùng lại `InpEmaFast`/`InpEmaSlow` + slope `InpSlopeBars`):
  - bull nếu `EMA_fast > EMA_slow` **và** slope `EMA_fast > 0`; bear là ảnh gương.
  - Không bull/bear ⇒ `NO_TRADE`.
- **Trigger M5** (nến M5 đã đóng): bull cần `close > max(high) của K nến M5 trước đó`; bear cần
  `close < min(low) của K nến M5 trước đó`. `K = InpBreakoutBars` (mặc định 12 ≈ 1 giờ).
- Vào lệnh khi **cả hai** đúng; một vị thế; quyết định trên nến đóng (không repaint).
- **Exit giữ nguyên** config hiện có (step trailing) cho lần đo đầu, để cô lập hiệu ứng **entry**.

Input mới: `InpBreakoutBars` (`int`, mặc định 12, khoảng 2…240). Mode 2 thêm vào enum
`ENUM_IR_DIRECTION_MODE` (`IR_DIR_REGIME = 2`).

## 3. Ràng buộc & an toàn

- Chỉ demo/tester; một điểm gửi lệnh `ExecBroker`; SL/TP bắt buộc; magic riêng — **không đổi**.
- Không sửa mode 0/1; mặc định preset ship **không đổi** (mode 0).
- Hàm quyết định phải **thuần** (không API) và có test trong `mt5/Scripts/IRCoreTests.mq5`.

## 4. Tiêu chí bác bỏ (ghi trước)

Chạy `infinite_runner_long_regime` (2018-2026, khoá daily/DD tắt) cạnh `long_base_nolock`:

- **Bác bỏ** nếu: (a) trong mẫu < 0 sau chi phí, hoặc (b) chỉ dương nhờ đuôi (`net_without_tp < 0` mạnh), hoặc
  (c) âm khi nhân đôi spread, hoặc (d) số lệnh quá ít để kết luận (`< 300`).
- **Giữ lại để đi tiếp** (walk-forward/OOS, G1–G2) chỉ khi vượt **cả bốn**.

## 5. Việc hiện thực

1. `IRDirection.mqh`: thêm `IR_DIR_REGIME=2`, hàm thuần `IRRegimeDecision(...)`.
2. EA: đọc channel M5 (`CopyHigh`/`CopyLow` K+1 nến), thêm nhánh mode 2 vào pipeline hướng; input
   `InpBreakoutBars`; fingerprint + validate.
3. `IRCoreTests.mq5`: test bull/bear/K cạnh; `gen_ir_sets.py`: scenario `infinite_runner_long_regime`;
   `sim_configs.py`: input + enum + cross-check.
4. Tài liệu: trang bot + preset (chỉ khi chốt được mode 2); PROGRESS.
