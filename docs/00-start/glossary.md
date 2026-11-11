# Thuật ngữ — 30+ từ và 9 nhãn trạng thái

Mỗi thuật ngữ 1–2 câu, viết theo nghĩa **chúng được dùng trong repo này**. Khi một trang chuyên và
trang này lệch nhau, trang chuyên thắng — báo để sửa từ điển theo. Nguồn chuẩn cho nhãn trạng thái:
[`../20-operations/evidence.md`](../20-operations/evidence.md) mục 1.

## 1. Thuật ngữ

**EA (Expert Advisor)** — Con bot MQL5 chạy trong MetaTrader 5, được gọi mỗi tick/nến để quyết định
mở/đóng/bỏ qua vị thế. Repo hiện chỉ còn **một EA demo**: `InfiniteRunnerXAUV2DemoEA`
([`../10-bots/infinite-runner.md`](../10-bots/infinite-runner.md)).

**Magic number** — Số định danh của bot gắn lên mọi lệnh, để bot nhận "vị thế của mình": InfiniteRunner
`25006001` (`XAUUSDm`).

**Preset JSON** — Nguồn sự thật của cấu hình một bot, nằm ở `configs/demo/*.json`; key trong JSON
trùng đúng tên `input` trong EA (không có lớp dịch tên ở giữa). Đổi cấu hình bao giờ cũng đổi JSON
trước; preset cũ với tên input mới bị bỏ qua âm thầm — lỗi phổ biến nhất khi đổi cấu hình.

**`.set`** — File input định dạng của MetaTrader 5 cho Strategy Tester, là **dẫn xuất** từ preset
JSON. Sửa `.set` mà không sửa JSON là cấu hình rác: lần sinh lại sẽ mất giá trị đã sửa.

**Gate (cổng)** — Tập lệnh kiểm tra bắt buộc phải xanh trước khi coi công việc là xong:
`scripts/check_docs_links.py`, `scripts/validate-project.py`, `scripts/validate_demo_execution.py`
và `python -m pytest`. Gate xanh là bằng chứng tĩnh, không nâng nhãn runtime của EA nào.

**ADR** — Architecture Decision Record: một quyết định phạm vi/kiến trúc một file, nằm ở
[`../90-decisions/README.md`](../90-decisions/README.md). ADR sửa ADR khác thì cả hai giữ nguyên và
ghi rõ quan hệ trong đầu mỗi file.

**`ExecBroker`** — Điểm gửi lệnh duy nhất của repo (`mt5/Include/Exec/ExecBroker.mqh`); mọi lệnh của
5 EA demo phải đi qua đây. Không EA demo nào được gọi `OrderSend` trực tiếp — validator quét và fail
nếu vi phạm.

**`ExecGuard`** — Lớp kiểm tra ngữ cảnh trong `mt5/Include/Exec/`: chỉ cho phép tài khoản demo hoặc
Strategy Tester; tài khoản real/contest bị từ chối ngay tại `OnInit` (return `INIT_FAILED`). Hành vi
fail-closed — mọi ngữ cảnh lạ đều bị từ chối thay vì cho qua.

**Kill switch** — Công tắc dừng khẩn cấp bằng file: bot kiểm tra `InpKillSwitchFile` (ví dụ
`GRID_DEMO_STOP.txt`); file tồn tại → bot ngừng vào lệnh, và nếu `InpCloseOnKillSwitch=true` thì đóng
vị thế (hoặc cả giỏ) trước khi dừng.

**Dry-run** — Chế độ bot chỉ **log ý định**, không gửi lệnh nào: `InpEnableExecution=false`. Từ ADR
0006, mặc định của EA demo là `true` (bật execution), nên dry-run là override tường minh của operator,
không phải mặc định an toàn ngầm.

**State file** — File trạng thái của bot (`InpStateFile`, ví dụ `pa_trendrider_demo_state.csv`) ghi
vị thế đang mở, initial R, halt; bot khôi phục từ file này khi restart để không "quên" vị thế và
không mất halt đang dính.

**Journal CSV** — Sổ kế toán 18 cột của bot (`logged_at, bar_time, event, side, price, …, reason`),
mỗi quyết định một dòng; là bằng chứng chính khi đọc hành vi bot. Cột và cách đọc từng dòng:
[`first-run.md`](first-run.md) mục 4.

**`config_hash`** — Vân tay của toàn bộ input một lần chạy; mọi dòng của cùng lần chạy phải cùng một
hash. Hai lần chạy hash khác nhau = hai cấu hình khác nhau, không được so số với nhau.

**Spread (points)** — Chênh lệch giá mua/bán, đo bằng `points` — đơn vị giá nhỏ nhất của symbol; trên
`XAUUSDm` spread thật thường 160–280 points. Đây là lý do phổ biến nhất của dòng `RISK|ENTRY_BLOCKED`
khi ngưỡng `InpMaxSpreadPoints` đặt thấp hơn spread thật.

**SL (stop-loss)** — Giá cắt lỗ gắn lên lệnh, **bắt buộc** trên mọi lệnh của EA demo (guard và
validator cùng ép). Không có SL = lệnh không hợp lệ, bot không gửi.

**TP (take-profit)** — Giá chốt lãi, cũng bắt buộc. Cách đặt khác nhau theo loại bot: bội số R
(`InpTakeProfitR`) cho PA/WW, TP an toàn xa cho IR, TP theo giỏ cho Grid/DCA.

**R-multiple** — Kết quả của một lệnh đo theo đơn vị rủi ro ban đầu (1R = khoảng cách giá vào tới
SL). TP của PA là `InpTakeProfitR=3.0`, nghĩa là chốt lãi ở 3 lần rủi ro ban đầu.

**Trailing stop** — SL tự động di chuyển theo giá có lợi để khoá lợi nhuận thay vì chờ TP; cơ chế
thoát chính của InfiniteRunner (`IRTrailing`): break-even trước, sau đó trailing từ initial R, SL
chỉ đi một hướng (monotonic).

**Break-even (BE)** — Bước trailing đầu tiên: khi giá đi có lợi quá `InpBreakEvenTriggerR` (đo bằng
R), SL dời về giá vào lệnh — từ đó lệnh không còn rủi ro gốc.

**Bounded grid** — Grid có trần cứng: tối đa `InpMaxGridLevels` tầng, volume/exposure có cap, giỏ có
SL/TP riêng tính từ entry bình quân. Không bao giờ là martingale vô hạn — tầng mới bị từ chối khi đã
chạm trần.

**Bounded DCA** — DCA có trần cứng tương tự: tối đa `InpMaxDcaAdds` lần bổ sung, mỗi lần cách nhau
`InpDcaDistancePoints`, tối đa một lần add mỗi bar, giỏ có SL/TP bắt buộc.

**Basket (giỏ)** — Tập các lệnh Grid/DCA cùng magic được coi là một khối: SL/TP tính từ entry bình
quân và cập nhật lại sau mỗi tầng; chạm daily loss/kill switch → đóng cả giỏ (`CloseBasket`), không
đóng lẻ từng chân.

**Runner** — Kiểu bot "một vị thế chạy liên tục" của InfiniteRunner: giữ lệnh bằng trailing SL thay
vì TP gần, để bắt trend dài; TP chỉ là mốc an toàn xa (`InpSafetyTpPoints`), không phải mục tiêu chính.

**PSAR** — Parabolic SAR, chỉ báo theo dõi stop (`iSAR`). Repo hiện **không** dùng; bot InfiniteRunner dùng
EMA + ATR.

**ONNX** — Định dạng model ML chạy được trong MQL5 (parity với Python cần thiết bị kiểm riêng).

**Parity** — Tính chất "cùng input → cùng output số" khi port logic giữa Python, Pine Script và MQL5.
Parity Pine ↔ MQL5 (Track B) hiện `BLOCKED` vì thiếu CSV reference thật xuất từ Pine; comparator chỉ
chạy trên dữ liệu tổng hợp.

**Warm-up** — Số nến đầu mà chỉ báo chưa cho giá trị ổn định (EMA seed, ATR Wilder, PSAR có thể lệch
ở đầu chuỗi); quy ước so parity bỏ qua vùng warm-up — lệch nhỏ ở đầu tắt dần, không tính là sai.

**Reason code** — Chuỗi token ổn định trong cột `reason` của journal giải thích vì sao bot quyết định
như vậy (ví dụ `max_virtual_exposure_reached`, `daily_loss_limit_reached`, `TARGET_HIT`); token là
hợp đồng, không đổi ý nghĩa giữa các lần đọc log.

**Strategy Tester** — Máy thời gian của MT5: cho bot chạy lại dữ liệu quá khứ, headless hoặc visual;
kết quả tester chứng minh **hành vi trong mô phỏng**, không chứng minh hiệu quả live hay slippage/swap thực.

**Signal-only** — EA chỉ tạo vị thế ảo / ghi log, không gọi API lệnh nào; `0 trade` trong tab Results
là kết quả **đúng** của nhóm EA này (ví dụ `LabSignalEA` PASS với 0 trade theo thiết kế).

**Bằng chứng (evidence)** — File thật + đường dẫn thật + ngày chạy thật: CSV journal, report `.htm`,
log lưu trong `reports/build/`. Ảnh chụp không kèm log, "chạy được trên máy tôi" và suy luận từ source
**không** phải bằng chứng — danh sách cấm đầy đủ trong `evidence.md` mục 3.

**Bounded (giới hạn có chặn)** — Hậu tố dùng cho grid/DCA/basket: mọi con số mở rộng (số tầng, số lần
add, volume, exposure) đều có trần cứng do validator ép; không có cơ chế nào tăng vô hạn theo lỗ.

**`XAUUSDm`** — Symbol vàng chính của lab (vàng quy USD trên sàn Exness, hậu tố `m` là micro);
mọi preset demo nhắm symbol này, timeframe phổ biến M5/M15.

## 2. Chín nhãn trạng thái

Sáu nhãn **hợp đồng** dùng để chốt trạng thái deliverable; ba nhãn **phụ** chỉ dùng trong ngữ cảnh
lịch sử/giới hạn, không chốt trạng thái một bot hay deliverable. Quy tắc lớn nhất: **không nâng nhãn
khi chưa có log/CSV/report thật** — đọc source thấy "nó phải chạy đúng" không đủ (V3: *never mark
compile/test/backtest/demo as passed based on source inspection alone*).

### Hợp đồng (6)

| Nhãn | Nghĩa |
|---|---|
| `DONE` | Deliverable và acceptance criteria đạt, đã chạy thật, có bằng chứng lưu lại. |
| `PASS` | Một kiểm tra cụ thể đã chạy thật và đạt; output phải đọc lại được từ file đã lưu. |
| `PARTIAL` | Đã làm/kiểm một phần; tài liệu phải ghi rõ phần nào đã kiểm, phần nào chưa. |
| `NOT_RUN` | Chưa chạy, không có bằng chứng; không được thay bằng suy luận nào. |
| `BLOCKED` | Bị chặn bởi đầu vào còn thiếu (CSV reference, quyết định, dữ liệu) — phải nêu đúng thứ thiếu. |
| `UNPROVEN` | Đã chạy nhưng chưa chứng minh được kết luận mong muốn; lợi nhuận mọi chiến lược là nhãn này, đứng yên cho tới khi có forward test dài hơn. |

### Phụ (3)

| Nhãn | Nghĩa |
|---|---|
| `FAIL` | Đã chạy và không đạt; phải ghi kèm ID/lỗi thật, không ghi `FAIL` suông. |
| `BLOCKED_PENDING_ADR` | Bị chặn bởi quyết định phạm vi, chờ một ADR mới; dùng trong ngữ cảnh lịch sử, không chốt trạng thái hiện tại. |
| `READY_FOR_MANUAL_VALIDATION` | Compile + test offline đạt; runtime chưa được xác minh bởi con người. |

Ba quy tắc đặt nhãn thường gặp:

- `PASS` yêu cầu lệnh/test đã chạy thật và có output lưu lại; gate xanh không tự nâng nhãn runtime nào.
- `BLOCKED` phải nêu đúng thứ còn thiếu; `NOT_RUN` nghĩa là không tuyên bố được gì cả — hai nhãn này
  không thay thế nhau.
- Số liệu kèm nhãn phải ghi nguồn: dữ liệu synthetic hay thật, khoảng thời gian, giả định chi phí.

Trạng thái hiện hành của từng bot: [`../10-bots/README.md`](../10-bots/README.md) và
[`../20-operations/evidence.md`](../20-operations/evidence.md). Lịch sử từng lần chạy:
[`../PROGRESS.md`](../PROGRESS.md).
