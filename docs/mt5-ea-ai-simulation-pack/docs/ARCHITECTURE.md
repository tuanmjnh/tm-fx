# Kiến trúc phần mềm

## Sơ đồ khối

```text
MT5 Strategy Tester
       |
       v
EA MQL5 (Grid / DCA / Runner)
       |
       +--> Strategy logic (chỉ tính quyết định)
       +--> RiskGuard (giới hạn cứng)
       +--> VirtualPortfolio (vị thế ảo, equity ảo)
       +--> CostModel (spread/commission/swap/slippage giả lập)
       +--> Logger (Journal/CSV)

Python tools
       +--> config validator
       +--> unit tests cho phép tính và RiskGuard
       +--> report parser/summary
       +--> test so sánh phép tính độc lập
```

## Quy ước thiết kế

- Strategy không sở hữu logic giới hạn rủi ro; trước mọi virtual entry/add phải gọi RiskGuard.
- VirtualPortfolio là nguồn dữ liệu chuẩn cho số vị thế, exposure, floating P&L và equity mô phỏng.
- CostModel phải phân biệt giá thị trường, giá khớp giả lập và phí.
- Logger không được ghi credentials hoặc thông tin nhận dạng tài khoản.
- Chỉ `SIMULATION_ONLY` được chấp nhận; không có module chuyển tiếp tới trade server.
- Mỗi run có ID, source revision (nếu lấy được), config hash, symbol/timeframe, date range, modelling mode và assumptions.

## Trạng thái RiskGuard

- `READY`: dữ liệu hợp lệ, có thể đánh giá tín hiệu.
- `BLOCKED`: điều kiện hiện tại không hợp lệ (spread, dữ liệu stale, cooldown...).
- `HALTED`: giới hạn cứng bị chạm; không tạo vị thế ảo mới cho đến khi kết thúc run hoặc thao tác reset được ghi log.

## Schema log khuyến nghị

`run_id, timestamp, strategy, strategy_version, config_hash, symbol, timeframe, event, reason, side, virtual_level, virtual_volume, price, virtual_sl, equity, floating_pnl, realized_pnl, drawdown_pct, exposure, modeled_cost, risk_state`

Tất cả units phải ghi rõ: points, price, percent, bars/seconds hoặc virtual lots. Không được trộn point với pip mà không chuyển đổi minh bạch.
