# Bằng chứng — nhãn trạng thái và quy tắc trích dẫn

Mỗi tuyên bố trong bộ tài liệu này phải trỏ được về một bằng chứng cụ thể: file thật, đường dẫn thật,
ngày chạy thật. Tài liệu này chưng cất từ `EVIDENCE.md` + `TEST_REPORT.md` (V2) và
`IMPLEMENTATION_STATUS.md` (V3) — bản gốc chỉ đọc nằm trong `99-archive/`. Số liệu chi tiết theo từng
phiên nằm trong [`../PROGRESS.md`](../PROGRESS.md); con số trong trang này chỉ là đối chiếu nhanh,
luôn lấy từ lần chạy mới nhất ghi trong PROGRESS.

## 1. Chín nhãn trạng thái

Sáu nhãn **hợp đồng** dùng để kết luận trạng thái deliverable; ba nhãn **phụ** chỉ dùng trong ngữ cảnh
lịch sử/giới hạn, không dùng để chốt trạng thái một bot hay một deliverable.

| Nhãn | Nghĩa | Loại |
|---|---|---|
| `DONE` | Deliverable và acceptance criteria đạt, đã chạy thật, có bằng chứng | hợp đồng |
| `PASS` | Kiểm tra cụ thể đã chạy và đạt | hợp đồng |
| `PARTIAL` | Đã làm một phần, phạm vi chưa đủ để kết luận đầy đủ | hợp đồng |
| `NOT_RUN` | Chưa chạy, không có bằng chứng; không được thay bằng suy luận | hợp đồng |
| `BLOCKED` | Bị chặn bởi đầu vào còn thiếu (CSV reference, quyết định, dữ liệu) | hợp đồng |
| `UNPROVEN` | Đã chạy nhưng chưa chứng minh được kết luận mong muốn | hợp đồng |
| `FAIL` | Đã chạy và không đạt; phải ghi ID/lỗi thật | phụ |
| `BLOCKED_PENDING_ADR` | Bị chặn bởi quyết định phạm vi, chờ ADR mới | phụ |
| `READY_FOR_MANUAL_VALIDATION` | Compile + test offline đạt, runtime chưa xác minh | phụ |

Quy tắc đặt nhãn:

- Không nâng nhãn (`NOT_RUN`/`BLOCKED`/`PARTIAL` → `PASS`) nếu chưa có log, CSV hoặc report thật.
- `PASS` yêu cầu lệnh/test đã chạy thật và có output lưu lại; đọc source và thấy "nó phải chạy đúng"
  không đủ (V3: *never mark compile/test/backtest/demo as passed based on source inspection alone*).
- `PARTIAL` nghĩa là chỉ một phần acceptance criteria được kiểm; ghi rõ phần nào đã kiểm, phần nào chưa.
- `BLOCKED` phải nêu đúng thứ còn thiếu (source, tool, dữ liệu, quyết định ADR); `NOT_RUN` nghĩa là
  không tuyên bố được gì.
- Lợi nhuận của mọi chiến lược hiện là `UNPROVEN` — đây là nhãn đứng yên cho tới khi có forward test
  dài hơn; kết quả tester không tự động nâng nó.

Trạng thái hiện tại theo bot (không nâng nhãn trong trang này; nguồn: [`../10-bots/README.md`](../10-bots/README.md)):

| Bot | Nhãn | Ghi chú |
|---|---|---|
| PATrendRiderXAUv1DemoEA | `PARTIAL` | đường lệnh có bằng chứng thật; chưa có ENTRY trên chart demo (§52.4) |
| GridDemoEA | `NOT_RUN` | chưa có journal demo/tester của bot |
| DCADemoEA | `NOT_RUN` | chưa có journal demo/tester của bot |
| InfiniteRunnerXAUV2DemoEA | `NOT_RUN` | mọi phiên demo/tester có lệnh chưa ghi kết quả (§65–§67) |
| WonderwhalesDemoEA | `UNPROVEN` | tester đã chạy thật (§69.4: 41 ENTRY, net −625.72); phiên demo chart `NOT_RUN` |
| LabSignalEA | `PASS` | §48.5 — tester PASS, 0 trade đúng thiết kế signal-only |
| LabOnnxInference | `PARTIAL` | §50 — tester + chart chạy được; parity Track B vẫn `BLOCKED` |
| Các EA lab còn lại | `NOT_RUN` | chưa có mục bằng chứng riêng trong PROGRESS |
| Parity Pine ↔ MQL5 (Track B) | `BLOCKED` | thiếu CSV reference từ Pine; comparator đã sẵn sàng |

## 2. Bảng bằng chứng theo tuyên bố

Mỗi dòng: tuyên bố | bằng chứng (file + sha256 nếu có) | nhãn. Hash ghi cho file gitignored để có thể
kiểm lại file có còn nguyên không; file trong repo thì đường dẫn là đủ.

| Tuyên bố | Bằng chứng | Nhãn |
|---|---|---|
| Compile toàn bộ source MQL5 0 errors / 0 warnings | `build-mql5.ps1` build 6292; log mỗi file trong `reports/build/`; dòng cuối log `Result: 0 errors, 0 warnings` | `PASS` |
| Static gate xanh | `validate-project.py` → `checks=14 fail=0`; `validate_demo_execution.py` → `checks=13 fail=0`; link check (chưa nối vào gate) → `broken=224` trên toàn repo — đều là link cũ tồn tại trước tái cấu trúc (checker miễn trừ `99-archive/`/`PROGRESS.md` nên không có số riêng cho file miễn trừ); Task 10 sẽ viết lại link và nối checker vào gate; 0 dòng BROKEN nào liên quan 4 file mới của task này (README/evidence/presets/troubleshooting) | `PASS` (cho hai gate `validate_*`) |
| Python test suite | `python -m pytest` → `436 passed` — số đo trong phiên làm việc 2026-11-03; `PROGRESS.md` §69.5 vẫn ghi kết quả cũ hơn (`428 passed, 2 failed`), Task 12 sẽ ghi số `436` vào §70; số thay đổi khi thêm test — luôn đọc kết quả lần mới nhất | `PASS` |
| Tester PA demo exec (`pa_trendrider_demo_exec`) | `reports/build/tester-reports/pa_trendrider_demo_exec/` — 28 ENTRY/28 EXIT, `config_hash=6B439450`; `tester_pa_trendrider_demo_exec.htm` sha256 `2BCB13BC…C8BEA4` | `PASS` (hành vi tester); lợi nhuận `UNPROVEN` |
| Tester Wonderwhales (`ww_demo_exec`) | `reports/build/tester-reports/ww_demo_exec/` — 41 ENTRY/41 EXIT, `config_hash=84AB2384`; `sim_ww_demo_exec.csv` sha256 `EDE0A513…BCDF6B`, `tester_ww_demo_exec.htm` sha256 `645A1F68…36691A`; SUMMARY `net=-625.72` | `PASS` (hành vi tester); chiến lược `UNPROVEN` |
| `ExecDemoProbe` — broker demo nhận lệnh thật | `reports/build/demo-exec-probe-20261029/` (gitignored, có `SHA256SUMS`): BUY 0.01 XAUUSDm deal 2468899165 @4045.79 → đóng deal 2468899168 @4045.55, pnl −0.24, 103 ms; magic probe `25002002` | `PASS` cho hạ tầng đặt lệnh |
| ENTRY của DemoEA do chiến lược tạo, trên chart demo | không có journal nào ghi `ENTRY` trên tài khoản demo; state `WAITING_FOR_SETUP` | `NOT_RUN` |
| Grid/DCA/IR phiên demo thật có lệnh | chưa có phiên nào; tester run Grid/DCA bị hoá vì terminal đang mở (§64.7) | `NOT_RUN` |
| Parity Pine ↔ MQL5 (Track B, các chỉ indicator) | comparator + test sẵn sàng nhưng **không có CSV reference từ Pine**; không tạo CSV giả | `BLOCKED` |
| Lợi nhuận của bất kỳ chiến lược nào | mọi số net đều là backtest/mô hình, cửa sổ ngắn, một symbol | `UNPROVEN` |

Ba điều kiện để một CSV tester được coi là bằng chứng hợp lệ (từ V2 §3): dòng tổng kết có `state` rõ
ràng, report `.htm` cùng run khớp số lệnh với journal, `config_hash` khớp preset đã dùng. Vi phạm một
trong ba → ghi bằng chứng là `INVALID`, không trích số.

### Chi tiết từng tuyên bố then chốt

**"Compile 0/0."** Nguồn duy nhất là dòng cuối của log MetaEditor (`Result: 0 errors, 0 warnings`)
**cộng với** file `.ex5` được tạo. MetaEditor CLI trả exit code 1 kể cả khi thành công — không dùng
exit code làm bằng chứng. Compile chỉ chứng minh cú pháp, không chứng minh hành vi runtime.

**"Gate xanh."** `validate-project.py` (layout, cấm API lệnh ngoài `Exec/*`, placeholder, preset) và
`validate_demo_execution.py` (guardrail từng EA demo, phạm vi ADR 0004/0007, guide) — mỗi lần chạy
ghi số `checks=N fail=0` vào PROGRESS; số cũ không tái sử dụng cho lần chạy khác. Gate xanh **không**
nâng nhãn runtime của EA nào: nó là bằng chứng về tĩnh, không phải về chạy.

**"Tester PA có lệnh."** `pa_trendrider_demo_exec` (2026-10-29, XAUUSDm M5, 9 tháng): 28 ENTRY/28 EXIT,
33 TRAIL, SUMMARY `net=74.77|state=WAITING_FOR_SETUP|transitions=92`; state file đúng một tiền tố
`state=`. Chứng minh đường `ENTRY → EXIT → SUMMARY` chạy thật trong tester; **không** chứng minh lợi
nhuận (số mô hình, dữ liệu mô phỏng).

**"Tester WW có lệnh."** `ww_demo_exec` (2026-11-03, headless 56.3 s): `INIT mode=DEMO_EXECUTION|
magic=25007001|config_hash=84AB2384`, 41 ENTRY/41 EXIT, volume 0.03–0.10 theo ngân sách ~1%/lệnh, 2
HALT + 1 RESUME; SUMMARY `trades=41|wins=11|losses=30|net=-625.72|halted=HALTED`. Halt daily-loss tự
mở khoá sang ngày giao dịch mới, halt drawdown dính tới hết kỳ — đúng thiết kế. Chiến lược vẫn `UNPROVEN`.

**"`ExecDemoProbe` trên demo thật."** Tài khoản demo `464140826` (Exness-MT5Trial17, hedge): lần 1
`InpConfirm=false` đi hết guard **không gửi lệnh** (dry-run vẫn an toàn mặc định), lần 2 khớp lệnh
thật với SL/TP gắn trong request, đóng trong 103 ms, pnl −0.24 đúng bằng spread 240 points trên 0.01
lot. Đối chiếu được ba nguồn độc lập: log script, tab Trade, tab History của server. Chứng minh hạ
tầng đặt lệnh; không chứng minh DemoEA sẽ vào lệnh khi có tín hiệu.

**"Parity Track B `BLOCKED`."** Comparator và các test parity đã PASS trên dữ liệu tổng hợp, nhưng
chưa từng có CSV reference thật xuất từ Pine. Không sinh CSV giả để đầy mô; khi có CSV thật thì parity
mới được nhãn khác `BLOCKED`.

**"Lợi nhuận."** Không có bằng chứng đủ mạnh cho chiến lược nào: SimEA lỗ ở cả ba cấu hình; demo tester
PA dương nhẹ (+74.77) nhưng là mô hình; WW âm (−625.72) trong tester. Mọi số đều là **đơn vị mô hình**
(volume 1.0 hoặc tester demo, không slippage thực, không swap khi chưa ghi) — không phải cam kết.

### Bảng nhãn theo loại bằng chứng

| Loại bằng chứng | Chứng minh được | Không chứng minh được |
|---|---|---|
| Compile log + `.ex5` | cú pháp đúng | hành vi runtime |
| Static gate / validator | ràng buộc tĩnh của repo | EA chạy đúng trên thị trường |
| Contract test (vector cố định) | logic thuần đúng trên vector | tương tác broker |
| Strategy Tester (CSV + `.htm`) | hành vi EA trong mô phỏng | hiệu quả live, slippage/swap thực |
| Probe demo thật | hạ tầng đặt lệnh chạy được | chiến lược có lãi |
| Phiên demo có giám sát | hành vi EA trên tick thật | lợi nhuận dài hạn (cần forward test tuần tháng) |

## 3. Bằng chứng bị cấm dùng

Các loại dưới đây **không được trích dẫn** trong bất kỳ tài liệu hay tuyên bố nào, kể cả khi không còn
cách khác:

- Ảnh chụp màn hình không kèm log/CSV (và không có sha256).
- Log không lưu file — nói "mình thấy trong console" mà không có file để mở lại.
- "Chạy được trên máy tôi" — câu chữ không kiểm chứng được, không trỏ về file.
- Kết quả tester không có file `.htm`/`.csv` cùng run — số nói không khớp được với report.
- Suy luận từ source code ("đọc code thấy hàm đúng") dùng để nâng nhãn runtime.
- Số chép từ tài liệu cũ khi chưa chạy lại; CSV cũ trong `reports/` chỉ là bằng chứng lịch sử của
  phiên đó, không tái sử dụng cho phiên khác.
- Kết quả Grid baseline dương trong tester dùng để nói "grid có lãi" — cùng cấu hình lỗ ở edge
  scenario và bị halt.
- Mọi tuyên bố về tài khoản real — repo không có và không được có.
- Log chứa login/password/server/token: nếu thấy phải xoá và báo, không trích dẫn, không vào commit.

## 4. Nơi lưu bằng chứng

- **`reports/build/tester-reports/<scenario>/`** — thư mục bằng chứng chuẩn của mỗi lần chạy tester
  (CSV + `.htm` + `.png` + journal 18 cột). Toàn bộ `reports/` bị **gitignored**: bằng chứng lưu ở
  máy, repo chỉ giữ tham chiếu đường dẫn + nhãn + ngày.
- **Quy ước đặt tên scenario:** tên đối tượng + biến thể, viết thường, gạch dưới: bot (`pa_trendrider_demo_exec`,
  `ww_demo_exec`), scenario lab (`dca_baseline`, `grid_conservative_stress`, `plan_rr2`), test chuyên
  (`contract_PriceActionMTF`, `q8_block_count`, `demo_exec_gui_20261029`). Thêm ngày (`_20261029`) khi
  cùng một tên cần phân biệt nhiều lần chạy.
- **`reports/build/demo-exec-probe-20261029/`** — bằng chứng probe demo thật, kèm `SHA256SUMS`.
- **`reports/build/tester-sets/`** và **`reports/build/tester-run/`** — `.set` và `.ini` dùng cho lần
  chạy headless; copy `.set` sang `MQL5\Profiles\Tester\` trước khi chạy (nguyên nhân #7 trong
  [troubleshooting.md](troubleshooting.md)).
- **File gitignored cần hash** khi ghi vào bảng bằng chứng (sha256 toàn file, viết hoa hoặc thường
  đều được nhưng một file chỉ một quy ước); file trong repo không cần hash vì git tự bảo toàn nội dung.
- Không đổi tên/xoá thư mục report cũ — các nhãn trong PROGRESS trỏ theo đường dẫn đã ghi.
- Bằng chứng runtime không nằm trong git — nếu cần trao đổi, chia sẻ file + sha256, không dán vào commit.

### Quy trình ghi một bằng chứng mới

1. Chạy thật → file output nằm ở `reports/build/...` đúng quy ước tên.
2. Ghi dòng vào `PROGRESS.md` (append-only): ngày, scenario, số đo chính, đường dẫn, hash nếu gitignored.
3. Nếu tuyên bố thay đổi nhãn nào, nâng nhãn ở trang bot tương ứng **trong cùng commit**; không nâng
   nhãn ở nơi khác trước khi PROGRESS ghi bằng chứng.
4. Kết quả không tái lập được → giữ nhãn cũ, ghi `INVALID` cho lần chạy đó; không xoá bằng chứng cũ.

### Mối quan hệ với PROGRESS.md

`PROGRESS.md` là **log append-only**: mỗi phiên làm việc thêm mục mới, không sửa mục cũ. Trang này là
**bảng tra hiện hành**: khi hai nguồn lệch nhau, `PROGRESS.md` giữ nguyên giá trị lịch sử, còn nhãn
hiện hành lấy từ mục mới nhất có bằng chứng tương ứng. Ví dụ: §66.4 ghi tester InfiniteRunner 0 trade
với `.set` dry-run — sự kiện đó không đổi, nhưng trạng thái hiện tại của bot vẫn là `NOT_RUN` vì chưa
có lần chạy lại sau khi sửa (§67–§68) và sau chẩn đoán vị thế lạc (2026-11-03).

### Giới hạn trung thực của chính trang này

- Các hash ghi ở mục 2 tính tại thời điểm ghi; file trong `reports/` có thể được sinh lại bằng lần
  chạy khác — hash chỉ khớp với đúng file của đúng phiên được nhắc.
- Số đo (entries, net, wall time) trích từ `PROGRESS.md`, không phải đọc lại toàn bộ CSV; khi cần số
  chính xác từng cột, mở file gốc ở đường dẫn đã ghi.
- Trang này không chứa bằng chứng mới — mọi tuyên bố đều phải truy ngược về PROGRESS hoặc file trong
  `reports/`; trang chỉ chuẩn hoá cách ghi và cách cấm.

### Tuyên bố mà bằng chứng hiện tại KHÔNG hỗ trợ (đọc kỹ trước khi trích số)

| Tuyên bố cấm | Vì sao cấm |
|---|---|
| "Bot X có lãi" | mọi số net là mô hình/backtest, cửa sổ ngắn; nhãn lợi nhuận `UNPROVEN` |
| "Grid an toàn vì baseline dương" | cùng cấu hình edge lỗ và `HALTED` (DD 5.0003%) |
| "Tester 0 trade = bot hỏng" | 0 trade thường là kết quả đúng của bộ lọc; xem troubleshooting |
| "Gate xanh = EA chạy đúng" | gate là kiểm tra tĩnh, không phải bằng chứng runtime |
| "Parity đã đạt vì comparator pass" | comparator chỉ chạy trên dữ liệu tổng hợp, thiếu CSV thật từ Pine |
| "Probe thành công = chiến lược hoạt động" | probe chứng minh hạ tầng lệnh, không đụng tín hiệu |
