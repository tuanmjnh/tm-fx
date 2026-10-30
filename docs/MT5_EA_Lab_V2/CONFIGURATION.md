# Cấu hình

**Nguyên tắc:** preset JSON là nguồn kiểm tra và snapshot; EA **không** đọc JSON trực tiếp. Người dùng nhập input trên chart/tester. Một input sai có thể làm hỏng cấu hình dù validator đã pass file JSON.

## 1. Nguồn cấu hình

| File | Dùng cho | Vai trò |
|---|---|---|
| `configs/demo/pa_trendrider_xau_demo.json` | `PATrendRiderXAUv1DemoEA` | Preset demo execution, `execution_mode=DEMO_ONLY`, `InpEnableExecution=false` |
| `configs/sim/pa_trendrider_xau.json` | `PATrendRiderXAUv1SimEA` | Preset mô phỏng, `execution_mode=SIMULATION_ONLY` |
| `configs/sim/grid_lab.json` | `GridLabEA` | Preset mô phỏng bounded grid |
| `configs/sim/dca_lab.json` | `DCALabEA` | Preset mô phỏng bounded DCA |
| `configs/sim/runner_trailing.json` | `RunnerTrailingLabEA` | Preset trailing runner |
| `configs/sim/pine_plan_lab.json` | `PinePlanSimEA` | Preset plan-driven |
| `configs/project.example.json` | validator | Cấu hình project mẫu |

Validator `scripts/validate-project.py` và `python/src/mt5_ea_ai_lab/sim_configs.py` kiểm tra fail-closed: EA name, execution mode, input đúng kiểu, cross-check (TP > 0, magic > 0, allowed symbols, kill switch, max positions = 1 cho DemoEA, magic demo khác magic sim).

## 2. PATrendRider DemoEA — input

### 2.1 Demo execution

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpEnableExecution` | `false` | `false` = dry-run, không gửi lệnh |
| `InpAllowedSymbols` | `"XAUUSD"` | Prefix allowlist, phân tách bằng dấu phẩy |
| `InpMagicNumber` | `25002001` | Magic riêng của DemoEA |
| `InpMaxSlippagePoints` | `30` | Deviation cho market order |
| `InpTakeProfitR` | `3.0` | TP = entry ± R × 3 |
| `InpKillSwitchFile` | `"PA_TREND_RIDER_DEMO_STOP.txt"` | File trong `MQL5/Files` |

### 2.2 Journal và state

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpEnableLog` | `true` | Ghi CSV |
| `InpLogFile` | `"pa_trendrider_demo.csv"` | Journal 18 cột |
| `InpPersistState` | `true` | Persist ledger/state |
| `InpStateFile` | `"pa_trendrider_demo_state.csv"` | File state |
| `InpResetStateOnInit` | `false` | Reset state khi init |
| `InpDebug` | `false` | Log chi tiết |

### 2.3 Timeframe và dữ liệu

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpTrendTF` | `PERIOD_H1` | Bias cấp cao |
| `InpStructureTF` | `PERIOD_M15` | Xác nhận cấu trúc |
| `InpEntryTF` | `PERIOD_M5` | Entry |
| `InpTrendBars` | `300` | Số bar H1 |
| `InpStructureBars` | `300` | Số bar M15 |
| `InpEntryBars` | `400` | Số bar M5 |

### 2.4 Cấu trúc và tín hiệu

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpSwingLeft` / `InpSwingRight` | `2` / `2` | Số bar hai bên để xác nhận fractal |
| `InpSpreadBufferMultiplier` | `2.0` | Buffer spread cho mức phá |
| `InpAtrBreakBufferMultiplier` | `0.10` | Buffer ATR cho BOS/CHoCH |
| `InpTrendMinDeltaAtr` | `0.05` | Ngưỡng tối thiểu để coi là trend |
| `InpRetestZoneAtr` | `0.25` | Nửa rộng vùng retest = 0.25 × ATR |
| `InpConfirmationBodyAtr` | `0.5` | Body tối thiểu = 0.5 × ATR |
| `InpConfirmationCloseZone` | `0.25` | Close phải nằm trong 25% ngoài của range |
| `InpMaxSignalAgeBars` | `8` | Tuổi tối đa của BOS |

### 2.5 Risk

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpRiskPercent` | `0.25` | % balance rủi ro mỗi lệnh |
| `InpMaxPositions` | `1` | Chỉ một vị thế |
| `InpDailyLossLimitPct` | `1.0` | Khóa entry khi lỗ ngày đạt 1% |
| `InpMaxDrawdownPct` | `8.0` | Khóa drawdown |
| `InpMaxConsecutiveLosses` | `3` | Chuỗi lỗ tối đa trước cooldown |
| `InpCooldownMinutes` | `30` | Thời gian cooldown |
| `InpManualResetDrawdown` | `false` | Reset thủ công sau drawdown lock |
| `InpCommissionPerVolume` | `0.0` | Commission ước tính cho sizing |

### 2.6 Stops

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpBreakEvenAtR` | `1.0` | Dời SL về entry khi đạt 1R |
| `InpTrailingStartR` | `1.5` | Bắt đầu trailing khi đạt 1.5R |
| `InpAtrStopBuffer` | `0.2` | Buffer ATR cho SL cấu trúc |
| `InpAtrTrailingMultiplier` | `1.2` | Khoảng trailing = 1.2 × ATR |
| `InpMinSlAtr` / `InpMaxSlAtr` | `0.5` / `4.0` | Kẹp SL theo ATR |
| `InpUpdateOnClosedBarOnly` | `true` | Chỉ cập nhật trailing trên bar đã đóng |

### 2.7 Volatility và spread

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpAtrPeriod` | `14` | Chu kỳ ATR |
| `InpAtrBaselineBars` | `100` | Số bar baseline |
| `InpAbnormalAtrRatio` | `2.5` | ATR > 2.5× median → volatility_high |
| `InpMaxSpreadPoints` | `600.0` | Spread tối đa |
| `InpMaxSpreadAtrRatio` | `0.25` | Spread/ATR tối đa |

## 3. PATrendRider SimEA — khác biệt chính

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpInitialBalance` | `5000.0` | Balance ảo |
| `InpLogFile` | `"pa_trendrider_log.csv"` | Journal mô phỏng |
| `InpStateFile` | `"pa_trendrider_state.csv"` | State mô phỏng |
| `InpMagicNumber` | `25001001` | Magic riêng của SimEA |
| `InpEnableTrading` | `true` | Bật tạo vị thế ảo |
| `InpMaxVirtualExposure` | `1.0` | Exposure ảo tối đa |
| `InpSlippagePoints` | `0.0` | Slippage mô phỏng |

Các input chiến lược/risk/stops giống DemoEA. SimEA **không** có `OrderSend`, không có TP (thoát bằng SL cấu trúc, breakeven/trailing, hoặc reversal).

## 4. GridLabEA — input

| Nhóm | Input | Default | Ý nghĩa |
|---|---|---|---|
| Simulation | `InpInitialBalance` | `10000.0` | Balance ảo |
| | `InpLogFile` | `"sim_grid_log.csv"` | Journal |
| Grid | `InpGridSide` | `GRID_LONG` | Một chiều |
| | `InpSpacingMode` | `SIM_GRID_FIXED_POINTS` | Fixed hoặc ATR |
| | `InpSpacingPoints` | `300.0` | Khoảng cách fixed |
| | `InpAtrPeriod` / `InpAtrMultiplier` | `14` / `1.0` | Khoảng cách ATR |
| | `InpMaxGridLevels` | `5` | Tổng level gồm level đầu |
| | `InpBaseVirtualVolume` | `0.10` | Volume level đầu |
| | `InpVolumeMultiplier` | `1.50` | Hệ số volume |
| | `InpMaxLevelVolume` | `1.00` | Trần volume từng level |
| Exit | `InpExitMode` | `GRID_EXIT_BASKET` | Level hoặc basket |
| | `InpLevelTargetPoints` | `300.0` | Target từng level |
| | `InpBasketTargetPoints` | `600.0` | Target basket |
| | `InpBasketStopPoints` | `900.0` | Stop basket (bắt buộc) |
| Risk | `InpMaxSpreadPoints` | `50.0` (preset: `600`) | Spread cap |
| | `InpMaxVirtualExposure` | `2.0` | Exposure cap |
| | `InpMaxDailyLossPct` | `2.0` | Daily loss guard |
| | `InpMaxDrawdownPct` | `5.0` | Drawdown guard |
| | `InpHaltOnBreach` | `false` | Dừng khi breach |

## 5. DCALabEA — input

| Nhóm | Input | Default | Ý nghĩa |
|---|---|---|---|
| Simulation | `InpInitialBalance` | `10000.0` | Balance ảo |
| | `InpLogFile` | `"sim_dca_log.csv"` | Journal |
| DCA | `InpDcaSide` | `DCA_LONG` | Một chiều |
| | `InpBaseVirtualVolume` | `0.10` | Volume entry đầu |
| | `InpTriggerMode` | `SIM_DCA_PRICE_DISTANCE` | Giá hoặc thời gian |
| | `InpDcaDistancePoints` | `300.0` | Khoảng cách giá |
| | `InpBarsBetweenAdds` | `5` | Số bar giữa add |
| | `InpMaxDcaAdds` | `3` | Tối đa add; `0` = không add |
| | `InpAddVolumeMultiplier` | `1.50` | Hệ số volume |
| | `InpMaxAddVolume` | `1.00` | Trần mỗi add |
| Exit | `InpBasketTargetPoints` | `600.0` | Target basket |
| | `InpBasketStopPoints` | `900.0` | Stop basket (bắt buộc) |
| Risk | `InpMaxSpreadPoints` | `50.0` (preset: `600`) | Spread cap |
| | `InpMaxVirtualExposure` | `2.0` | Exposure cap |
| | `InpMaxDailyLossPct` | `2.0` | Daily loss guard |
| | `InpMaxDrawdownPct` | `5.0` | Drawdown guard |
| | `InpHaltOnBreach` | `false` | Dừng khi breach |

## 6. Magic number

| EA | Magic | Ghi chú |
|---|---|---|
| `PATrendRiderXAUv1SimEA` | `25001001` | Không đụng vị thế thật/demo |
| `PATrendRiderXAUv1DemoEA` | `25002001` | Duy nhất được gửi lệnh demo |
| `ExecDemoProbe` | `25002002` | Probe một phát, tự đóng |
| Grid/DCA/Runner | Không dùng order API | Không có magic thật |

## 7. State và journal

| File | Vị trí | Nội dung |
|---|---|---|
| `pa_trendrider_demo.csv` | `MQL5\Files` | 18 cột: time, bar_time, ea, version, config_hash, symbol, tf, event, side, price, volume, sl, tp, pnl, balance, drawdown, detail... |
| `pa_trendrider_demo_state.csv` | `MQL5\Files` | State machine + ledger |
| `PA_TREND_RIDER_DEMO_STOP.txt` | `MQL5\Files` | Kill switch (sự tồn tại = khóa) |
| `pa_trendrider_log.csv` | `MQL5\Files` | Journal SimEA |
| `sim_grid_log.csv`, `sim_dca_log.csv` | `MQL5\Files` | Journal mô phỏng |

**Trước khi replay sạch:** xóa hoặc reset state file. Nếu không, EA khôi phục state cũ (kể cả `ERROR_SAFE_MODE` sau kill switch). Xem [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

## 8. Thay đổi cấu hình an toàn

1. Sửa preset JSON **và** input trên chart/tester cho khớp.
2. Chạy `validate-project.py` và `validate_demo_execution.py`.
3. Với DemoEA: giữ `InpEnableExecution=false` cho đến khi đã kiểm tra `INIT` + `mql_trade_allowed=1`.
4. Ghi lại `config_hash` trong journal; nếu hash đổi giữa phiên, dừng và điều tra.
5. Không tăng `InpRiskPercent`, không bỏ SL/TP, không đổi magic để lách guard.

## 9. Fail-closed

- Preset thiếu field bắt buộc → validator fail.
- Demo preset `execution_mode != DEMO_ONLY` → fail.
- `InpTakeProfitR <= 0`, `InpMaxPositions != 1`, allowed symbols rỗng, kill switch rỗng → fail.
- Demo magic trùng sim magic → fail.
- Project config liệt kê DemoEA như EA mô phỏng → fail.
- EA gặp input không hợp lệ → `INIT_FAILED` hoặc block entry, không tự sửa.
