# Preset cấu hình — JSON là nguồn sự thật, `.set` là dẫn xuất

Repo hiện chỉ còn **một bot demo**: `InfiniteRunnerXAUV2DemoEA` (magic `25006001`, `XAUUSDm`, M5).

## 1. Nguồn sự thật

[`configs/demo/infinite_runner_demo.json`](../../configs/demo/infinite_runner_demo.json) — `DEMO_ONLY`,
`allow_live_trading=false`, `InpEnableExecution=true`, 61 input (khớp EA). `enum_map` và `assumptions` mô tả
các enum dùng số (ví dụ `InpDirectionMode`: 0 LEGACY, 1 EMA_MTF, 2 REGIME).

## 2. `.set` là dẫn xuất thủ công

Hai file `.set` tracked trong thư mục này là **viết tay** kèm chú thích tiếng Việt, đủ **61 input**:

| File | Dùng cho |
|---|---|
| [`infinite_runner_v2.set`](presets/infinite_runner_v2.set) | preset operator (Strategy Tester / chart demo) |
| [`infinite_runner_v2_demo_run.set`](presets/infinite_runner_v2_demo_run.set) | chạy **demo** (forward test): log/state riêng, lot cố định 0.01 |
| [`infinite_runner_v2_micro50.set`](presets/infinite_runner_v2_micro50.set) | ⚠ tài khoản **~$50** (nới trần daily/DD, tắt khoá chuỗi thua) — **aggressive, chưa kiểm định** |

`.set` nạp vào tester được resolve từ `MQL5\Profiles\Tester\` của Data Folder — `scripts/deploy_pineport.ps1`
(hoặc `scripts/tester/gen_ir_sets.py`) copy giúp. Hiện **chưa** có validator tự động cho `.set`; khi sửa input
của EA thì phải cập nhật JSON và `.set` cùng lúc.

## 3. Tài khoản tối thiểu

- Lot cố định `0.01` ⇒ **~$5 rủi ro/1R** (SL 5000 points = 5,00 giá, Exness 3 chữ số). Thực tế nên có **≥ $1.000**
  (trần `InpMaxDailyLossPct=1%` khiến tài khoản quá nhỏ bị halt sau 1–2 lệnh lỗ).
- Lot theo rủi ro `InpLotMode=1` (0,25%) cần **equity ≥ ~$2.000** mới vào được (dưới ngưỡng bot bỏ qua lệnh).
- Khoá `InpMaxDrawdownPct=8%` là **halt vĩnh viễn** (mở bằng tay). Chi tiết: [`../10-bots/infinite-runner.md`](../10-bots/infinite-runner.md).
