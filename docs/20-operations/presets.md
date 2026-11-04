# Preset cấu hình — JSON là nguồn sự thật, `.set` là dẫn xuất

Tài liệu này nói về các file cấu hình của **5 bot demo**: nguồn nào là chuẩn, file nào là dẫn xuất,
và quy tắc đổi preset an toàn. Phạm vi chạy của từng bot (guard, kill switch, kho rủi ro) xem
[demo-execution.md](demo-execution.md).

## 1. Nguồn sự thật: `configs/demo/*.json`

- File chuẩn cho **mọi** preset demo là JSON trong `configs/demo/`. Mỗi JSON khai báo: EA đích,
  `execution_mode` (bắt buộc `DEMO_ONLY`), `allow_live_trading: false`, symbol/timeframe, bảng
  `inputs`, bảng `enum_map` (map số enum sang tên), và `assumptions` (giả định vận hành).
- **Key trong `inputs` phải trùng chính xác tên input của EA, giữ nguyên tiền tố `Inp`** — ví dụ
  `InpEnableExecution`, không phải `EnableExecution`. EA không đọc JSON trực tiếp; JSON là bản khai
  báo mà validator và con người dùng để đối chiếu với input thật của EA.
- `validate-project.py` kiểm `configs/demo/*.json`: đúng EA đăng ký, đủ/trùng key input, không thừa
  thiếu, `execution_mode: DEMO_ONLY`, `allow_live_trading: false`, và `InpEnableExecution: true`
  (ADR 0006 — mặc định bật execution; dry-run là override có chủ đích).
- Giá trị enum trong JSON là **số** (`InpTrendTF: 16385` = `PERIOD_H1`); tên để người đọc ở cột
  `enum_map`/`assumptions`. `.set` cũng dùng số.
- `assumptions` trong JSON ghi rõ giả định vận hành (position model, sizing, kill switch, state) —
  đây là phần hợp đồng để đối chiếu với guard thật trong `mt5/Include/Exec/*`. Sửa input mà làm
  `assumptions` sai thì sửa cả hai, cùng một commit.

### Cấu trúc một preset JSON (đọc theo thứ tự)

| Khối | Ý nghĩa | Ai kiểm |
|---|---|---|
| `ea`, `version` | EA đích; phải khớp tên đăng ký trong validator | `validate-project.py` |
| `execution_mode`, `allow_live_trading` | phạm vi: chỉ demo/tester, cấm real | cả hai validator |
| `symbol`, `timeframe` | cặp và khung mặc định khi chạy | người chạy |
| `inputs` | toàn bộ input EA, key giữ `Inp`, giá trị là số/bool/string thật | `validate_preset` |
| `enum_map` | map số enum → tên dễ đọc (ví dụ `16385` → `PERIOD_H1`) | người đọc |
| `assumptions` | giả định vận hành kèm giới hạn trung thực | người review |

Ví dụ thật từ `pa_trendrider_xau_demo.json`: `"InpEnableExecution": true` (ADR 0006),
`"InpMagicNumber": 25002001`, `"InpMaxSpreadPoints": 600.0` (= 0.6 USD, so với spread Exness đo được
~150–300 points), `"InpKillSwitchFile": "PA_TREND_RIDER_DEMO_STOP.txt"`.

## 2. `.set` là dẫn xuất thủ công — chưa được kiểm tự động

**Nói thẳng: hiện không có script nào sinh hoặc validate file `.set`.** Các file
`presets/*.set` trong thư mục này được **viết tay** kèm chú thích tiếng Việt có dấu, mô tả từng input
kèm quy ước đơn vị. `validate-project.py` chỉ kiểm JSON trong `configs/` — **không** đọc, không so
khớp, không phát hiện lệch giữa `.set` và JSON.

Hệ quả thực tế:

- Nếu JSON đổi mà `.set` không đổi tay theo, `.set` sẽ âm thầm sai — tester nạp `.set` thì chạy bằng
  giá trị cũ, không có cảnh báo nào.
- File `.set` thực sự nạp vào tester **không phải** file trong thư mục này: tester resolve
  `ExpertParameters=<name>.set` từ `MQL5\Profiles\Tester\` của Data Folder. Muốn dùng thì phải copy
  thủ công (xem mục 6).
- **Phase C** (chuẩn hoá input — đặc tả ở [`../10-bots/input-convention.md`](../10-bots/input-convention.md))
  mới thêm bước sinh/kiểm `.set` từ JSON tự động. Cho tới khi đó, mọi thay đổi `.set` phải làm theo
  quy tắc mục 4 và người sửa chịu trách nhiệm so khớp bằng tay.

### Vị trí các file `.set` trong repo

| Thư mục | Gì ở đó | Trạng thái |
|---|---|---|
| `docs/20-operations/presets/` | 4 file `.set` có chú thích tiếng Việt (PA, Grid, DCA, IR) | trong git, viết tay, **chưa validator** |
| `reports/build/tester-sets/` | `.set` dùng cho từng scenario tester (`pa_trendrider_demo_exec.set`, `ww_demo_exec.set`, …) | gitignored, sinh thủ công cho lần chạy |
| `MQL5\Profiles\Tester\` (Data Folder) | nơi tester thực sự đọc | copy tay trước mỗi lần chạy |

Ba nơi này **không** tự đồng bộ. File trong docs là bản có chú thích để người đọc; file trong
`tester-sets` là bản chạy từng scenario; bản trong Data Folder là bản tester nạp. Lệch giữa ba nơi là
nguyên nhân #7 trong [troubleshooting.md](troubleshooting.md).

## 3. Bảng 5 bot: JSON, `.set`, magic

| Bot | JSON (nguồn sự thật) | `.set` (dẫn xuất thủ công) | magic |
|---|---|---|---|
| PA TrendRider | `configs/demo/pa_trendrider_xau_demo.json` | `presets/pa_trendrider_xau.set` | 25002001 |
| Grid | `configs/demo/grid_demo.json` | `presets/grid_demo.set` | 25004001 |
| DCA | `configs/demo/dca_demo.json` | `presets/dca_demo.set` | 25005001 |
| InfiniteRunner | `configs/demo/infinite_runner_demo.json` | `presets/infinite_runner_v2.set` | 25006001 |
| Wonderwhales | `configs/demo/wonderwhales_demo.json` | **không có** `.set` | 25007001 |

Ghi chú:

- Wonderwhales **chưa có** `.set` trong thư mục này: bot được thêm sau (ADR 0007), file dùng cho
  tester là `reports/build/tester-sets/ww_demo_exec.set` (sinh cho lần chạy cụ thể, gitignored). Muốn
  có `.set` có chú thích cho WW thì viết tay theo mẫu của 4 file kia, hoặc đợi phase C sinh tự động.
- `infinite_runner_v2.set` đặt tên theo bot V2 (`InfiniteRunnerXAUV2DemoEA`), không theo tên JSON
  (`infinite_runner_demo.json`) — khác tên nhưng cùng một preset về ý nghĩa; magic trong file mới là
  định danh thật.
- Đổi bất kỳ dòng nào trong bảng này (thêm bot, đổi magic) là thay đổi phạm vi — cần ADR, không phải
  sửa tài liệu.

### Đặc điểm nhanh từng preset

| Bot | Symbol/TF | Đặc điểm preset |
|---|---|---|
| PA TrendRider | XAUUSDm M5 | một vị thế; TP = `InpTakeProfitR` × R (3.0); spread buffer ×2 ATR; `InpMaxSpreadPoints=600` |
| Grid | XAUUSDm M15 | tối đa `InpMaxGridLevels` chân; volume mỗi chân có trần; SL/TP giỏ tính từ giá bình quân |
| DCA | XAUUSDm M15 | tối đa `InpMaxDcaAdds` lần add; bắt buộc basket SL; trần tổng exposure và drawdown |
| InfiniteRunner | XAUUSDm M5 | một runner; SL trong band `[InpMinStopPoints, InpMaxStopPoints]`; TP an toàn xa `InpSafetyTpPoints` bắt buộc; trail đơn điệu |
| Wonderwhales | XAUUSDm M15 | một vị thế theo `PinePort\Wonderwhales`; SL PSAR/ATR%/fixed + sàn `InpMinStopPoints`; TP = 2.0R; lot theo `InpRiskPercent` |

## 4. Quy tắc đổi preset an toàn

Đổi preset **không phải** sửa một file. Một thay đổi hoàn chỉnh gồm tất cả các bước sau **trong cùng
một commit**:

1. Sửa `configs/demo/<bot>_demo.json` (nguồn sự thật).
2. Sửa `.set` tương ứng trong `presets/` (nếu bot có) cho khớp từng key — so từng dòng bằng tay, vì
   chưa có validator cho `.set` (mục 2).
3. Chạy `python scripts\validate-project.py` → phải `checks=N fail=0` (và
   `validate_demo_execution.py` khi đụng phạm vi demo). Gate fail thì dừng, không sửa câu chữ để lách.
4. Ghi thay đổi vào `docs/PROGRESS.md`: ngày, bot, key đổi từ giá trị nào sang giá trị nào, lý do.

Cấm kèm theo:

- **Không đổi magic** — magic là định danh vị thế trên tài khoản; đổi magic là đổi phạm vi (cần ADR),
  và state file/journal cũ sẽ không còn khớp.
- **Không đặt `InpEnableExecution=false` trong preset demo** (ADR 0006). Dry-run là chế độ có chủ đích
  đặt tay ở chart/`.set` chạy thử, không phải cấu hình mặc định của bot demo.
- Không thêm key JSON mà EA không có input tương ứng — validator sẽ fail, nhưng đừng sửa validator
  để cho qua.
- Không đụng `configs/sim/*.json` (preset của EA mô phỏng) trong cùng commit với preset demo.

### Ví dụ một thay đổi đúng quy trình

Muốn tăng `InpMaxSpreadPoints` của PA từ 600.0 lên 800.0:

1. Sửa `configs/demo/pa_trendrider_xau_demo.json` → `"InpMaxSpreadPoints": 800.0`, cập nhật
   `assumptions` nếu có nhắc con số này.
2. Sửa `presets/pa_trendrider_xau.set` → dòng `InpMaxSpreadPoints=800.0` (và chú thích bên dưới nếu
   chú thích ghi số cũ).
3. Chạy `validate-project.py` + `validate_demo_execution.py` → `fail=0`.
4. Ghi vào `docs/PROGRESS.md`: ngày, "PA preset: InpMaxSpreadPoints 600.0 → 800.0, lý do …".
5. Copy lại `.set` vào `MQL5\Profiles\Tester\` nếu phiên tester kế tiếp dùng preset mới.

Thiếu bước 2 → tester vẫn chạy giá trị cũ; thiếu bước 4 → thay đổi không có bằng chứng.

## 5. Magic table

Magic phân vùng vị thế giữa các bot trên cùng một tài khoản — không bot nào chạm vị thế của bot khác.
Số `25002000` là gốc dãy của nhóm demo; probe dùng số kế bên PA.

| Magic | Đối tượng | Vai trò |
|---|---|---|
| 25002001 | `PATrendRiderXAUv1DemoEA` | bot demo PA — một vị thế theo magic |
| 25002002 | `mt5/Scripts/ExecDemoProbe.mq5` | probe đường gửi lệnh (script, không phải EA) — chủ đích khác magic PA để không đụng vị thế/state/journal của DemoEA |
| 25004001 | `GridDemoEA` | bot demo Grid — một **giỏ** theo magic, tối đa `InpMaxGridLevels` chân |
| 25005001 | `DCADemoEA` | bot demo DCA — một giỏ theo magic, tối đa `InpMaxDcaAdds` lần add |
| 25006001 | `InfiniteRunnerXAUV2DemoEA` | bot demo InfiniteRunner — một vị thế runner |
| 25007001 | `WonderwhalesDemoEA` | bot demo Wonderwhales — một vị thế theo tín hiệu `PinePort\Wonderwhales` |

Quy tắc:

- Probe `25002002` là script một phát để kiểm chứng hạ tầng lệnh; journal của EA demo PA **không được**
  chứa magic này (đã kiểm 2026-10-29: 0 dòng). Đừng tái dùng số này cho bot mới.
- Magic demo khác magic simulation; test Python kiểm điều này (`test_demo_execution.py`).
- State file và journal của mỗi bot gắn với magic của bot đó; đổi magic mà không đổi state file sẽ
  tạo trạng thái lệch (`restored=1` trên state không phải của mình).

## 6. Trước khi chạy tester: copy `.set` vào `MQL5\Profiles\Tester\`

Bước này bắt buộc với headless run và với chạy tay bằng preset có chú thích:

1. Copy file `.set` mong muốn vào `<Data Folder>\MQL5\Profiles\Tester\` (File → Open Data Folder).
   Tester **không đọc** file `.set` từ thư mục `docs/20-operations/presets/` hay `reports/build/tester-sets/`.
2. Nếu thiếu `.set`, tester **không lỗi** — nó chạy im lặng bằng **input mặc định của EA**. Dấu hiệu:
   journal ghi tên log mặc định (ví dụ `wonderwhales_demo.csv` thay vì `sim_ww_demo_exec.csv`),
   `config_hash` khác lần chạy trước, kết quả lệch hẳn kỳ vọng. Đây là nguyên nhân #7 trong
   [troubleshooting.md](troubleshooting.md); bằng chứng thật ở PROGRESS §69.4 (lần chạy WW đầu tiên
   thiếu bước copy, phát hiện lỗi halt vĩnh viễn trên input mặc định thay vì preset).
3. Xoá CSV cũ trong thư mục agent tester (`%APPDATA%\MetaQuotes\Tester\<hash>\Agent-*\MQL5\Files`)
   để không đọc nhầm output của lần chạy trước.
4. Với phiên sạch (không muốn kế thừa halt/drawdown cũ): bật `InpResetStateOnInit=true` hoặc xoá
   state file `*_state.csv` trong `MQL5\Files\` — state file persist qua `restored=1` và sẽ đưa bot
   về `HALTED` ngay khi khởi động nếu lần trước đã halt.

Quy ước đơn vị dùng chung cho vàng (XAUUSD/`XAUUSDm`, Exness 3 số lẻ): **1000 points = 1.0 USD** giá
vàng (3000 points = 3.0 USD). Khi đọc tham số `...Points` trong JSON/`.set`, nhớ đơn vị này trước khi
kết luận giá trị quá to/nhỏ.

### Kiểm tra nhanh sau khi copy `.set`

Trước khi nhấn Start (hoặc chạy headless), xác nhận bằng mắt trong tab Inputs của tester:

- `InpMagicNumber` khớp magic của bot (bảng mục 5) — sai magic là đụng vị thế của bot khác hoặc tạo
  vị thế lạc không ai quản.
- `InpEnableExecution=true` — nếu dòng này `false`, cả phiên chỉ là dry-run: không lỗi, không lệnh,
  và nguyên nhân #1 trong [troubleshooting.md](troubleshooting.md) sẽ diễn ra đúng như mô tả.
- `InpLogFile` là tên log của scenario (ví dụ `sim_ww_demo_exec.csv`), không phải tên mặc định của EA.
- Giá trị hiển thị trong tab Inputs khớp con số trong `.set` vừa copy (tester đã nạp đúng file).

Bốn dòng này là phiên bản rút gọn của checklist 6 mục trong [troubleshooting.md](troubleshooting.md) §4;
kết quả thật của phiên chạy thì vẫn phải ghi theo quy ước ở [evidence.md](evidence.md).

### Đọc file `.set` thế nào

File `.set` là plain text, cấu trúc:

```ini
[TesterInputs]
InpEnableExecution=true          ; 1 dòng giá trị...
; ...kèm khối chú thích tiếng Việt phía trên/dưới
InpMagicNumber=25002001
```

- Section bắt buộc là `[TesterInputs]`; tester đọc các dòng `Name=value`, bỏ qua dòng bắt đầu bằng `;`.
- Chú thích tiếng Việt có dấu nằm trong file là **cho người đọc**; tester bỏ qua chúng. Xoá chú thích
  không đổi hành vi, nhưng đừng xoá — đó là phần giữ file này dễ đối chiếu với JSON.
- Giá trị enum là số (`16385`), khớp `enum_map` trong JSON; đơn vị points theo quy ước đầu mục 6.
