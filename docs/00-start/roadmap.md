# Lộ trình

Trạng thái trung thực của lab theo từng mảng, việc đã xong / đang dở / chưa làm, ba phase tiếp theo,
và lịch sử của các bộ tài liệu trước. Quy tắc xuyên suốt: **không nâng nhãn khi chưa có bằng chứng
thật** — nhãn nào dưới đây cũng phải truy ngược được về [`../PROGRESS.md`](../PROGRESS.md) hoặc
[`../20-operations/evidence.md`](../20-operations/evidence.md). Kết quả Strategy Tester chỉ chứng minh
hành vi trong mô phỏng; không kết quả nào là cam kết lợi nhuận hay bằng chứng sẵn sàng cho tài khoản thật.

Kho hiện chỉ còn **một bot demo**: `InfiniteRunnerXAUV2DemoEA` (magic 25006001).

## 1. Trạng thái hiện tại theo mảng

| Mảng | Nhãn | Một câu |
|---|---|---|
| Tài liệu | `PASS` | Cây `00-start`…`99-archive` đã có entry layer, ADR và link checker; cổng link-check xanh (`check_docs_links.py` → `broken=0`). |
| InfiniteRunner XAU v2 (demo) | `NOT_RUN` | EA demo V2 là canonical theo ADR 0005; các phiên demo/tester có lệnh nhưng chưa ghi kết quả (PROGRESS §65–§67). |
| Python/ML | `PASS` | Suite pytest xanh; pipeline Python (dữ liệu → backtest → ML → store → report) chạy thật trên dataset synthetic. |
| ML/ONNX | `PARTIAL` | ML baseline + export ONNX + runtime MQL5 chạy được (24/24 hàng fixture); parity Track B vẫn `BLOCKED` vì thiếu CSV reference từ Pine. |
| Demo execution (hạ tầng) | `PASS` | `ExecBroker` + `ExecGuard` + kill switch + magic riêng đã được probe demo thật xác nhận (`ExecDemoProbe`). |
| Demo execution (chiến lược) | `NOT_RUN` | Chưa có phiên demo thật nào ghi `ENTRY` do chính chiến lược bot tạo ra. |
| Cổng (gate) | `PASS` | `validate-project.py`, `validate_demo_execution.py`, `check_docs_links.py` và `pytest` xanh; số chi tiết đọc lần chạy mới nhất trong `../PROGRESS.md`. |
| Lợi nhuận chiến lược | `UNPROVEN` | Mọi số net là đơn vị mô hình trên dữ liệu backtest/mô phỏng; nhãn này đứng yên cho tới khi có forward test dài hơn. |

Cách đọc bảng trên đúng:

- **Một mảng một nhãn** — nhãn nói về deliverable của mảng đó, không trộn với nhãn của mảng khác.
- **Nhãn không lây.** Tester của InfiniteRunner có lệnh không nâng bot khỏi `NOT_RUN`; probe demo thật
  PASS không nâng nhãn runtime của bot; validator xanh không nâng nhãn runtime của EA nào.
- **Mọi nhãn truy ngược được.** Muốn kiểm một nhãn, mở mục tương ứng trong `../PROGRESS.md`.

## 2. Đã xong / đang dở / chưa làm

**Đã xong** (có bằng chứng thật trong `../PROGRESS.md`):

| Việc | Bằng chứng |
|---|---|
| Pipeline Python end-to-end (validate → backtest → ML → store → report) | Chạy thật trên dataset synthetic, hai run lưu vào experiment store |
| ONNX inference runtime MQL5 | Harness inference MQL5 nạp model, 24/24 hàng fixture khớp tolerance, provider CPU (harness lab đã gỡ cùng các EA khác; giữ làm mốc lịch sử) |
| Hạ tầng demo execution | `mt5/Include/Exec/*`: guard, kill switch, magic riêng, SL/TP bắt buộc; `ExecDemoProbe` khớp lệnh thật trên tài khoản demo |
| EA demo compile + preset | Build 0 errors, 0 warnings; preset JSON trong `configs/demo/` |
| Tái cấu trúc tài liệu theo mục đích | ADR 0008; cây `00-start`…`99-archive`, entry layer, link checker `scripts/check_docs_links.py` |

**Đang dở** (một phần acceptance criteria đã kiểm, phần còn lại ghi rõ):

| Việc | Đã kiểm | Chưa kiểm |
|---|---|---|
| Chuẩn hoá input | Đặc tả duyệt + bảng gap quét từ source trong `../10-bots/input-convention.md` | Rà soát lại input EA demo theo chuẩn |
| Demo forward | Hạ tầng chạy được, probe PASS, tester có lệnh | `ENTRY` demo do chiến lược của bot trên tài khoản demo |
| Nghiên cứu InfiniteRunner | Study + evidence lưu trong `../30-research/infinite-runner-long-run-study.md` | Edge sau chi phí chưa chứng minh được |

**Chưa làm:**

| Việc | Điều kiện bắt đầu |
|---|---|
| Suite demo XAUUSD tự động (tester + chart demo) | Hạ tầng + input xong, cả ba lệnh cổng xanh |
| Đánh giá out-of-sample / walk-forward protocol | Suite demo cho số liệu forward thật, dữ liệu tách rõ train/test |
| Nghiên cứu AI (backlog) | Chỉ mở khi các mục trên xong và chủ dự án duyệt |

## 3. Ba phase tiếp theo

### Phase A — Tái cấu trúc tài liệu (xong)

Đã hoàn tất phần còn lại của reorg: viết lại link trong toàn bộ tài liệu hiện hành trỏ về cây mới (bản ánh xạ
`docs/99-archive/LINK_MAP.md`), cổng link-check đã xanh.

- **Việc:** rewrite link cũ (`v2/`, `archive/`, đường dẫn tuyệt đối) theo LINK_MAP; không đụng
  `PROGRESS.md` và `99-archive/` (cả hai được miễn kiểm link vì là lịch sử bất biến).
- **Xong khi (đã đạt):** `python scripts\check_docs_links.py` → `broken=0`; `python scripts\validate-project.py`
  → `fail=0`; `python -m pytest` → `0 failed`.
- **Chống mục tiêu:** không tạo thêm một "bộ tài liệu v4"; không "sửa" link chết bằng cách trỏ tất cả
  về `99-archive/`; không tắt check trong validator để cổng xanh.

### Phase B — Chuẩn hóa input

Áp dụng chuẩn input cho EA demo theo [`../10-bots/input-convention.md`](../10-bots/input-convention.md).

- **Việc:** thêm input thiếu theo ma trận gap; đổi tên group về `01 Execution`…`06 Strategy`
  đúng thứ tự; cập nhật preset JSON + `.set` **cùng lúc**; chạy `validate-project.py` (`fail=0`) +
  `scripts/build-mql5.ps1` (`0 errors, 0 warnings`); ghi mục mới vào `../PROGRESS.md` kèm `config_hash`
  mới nếu preset đổi.
- **Phạm vi:** EA demo + preset + validator. Không đổi logic chiến lược, không đổi magic number.
- **Xong khi:** EA demo khai input đúng chuẩn; validator ép đủ "preset đủ key, không thừa/thiếu".

### Phase C — Suite demo XAUUSD

Bot demo × (Strategy Tester headless + phiên demo trên chart) trên `XAUUSDm`.

- **Việc:** mỗi lần chạy ghi `config_hash` + journal CSV + report `.htm` vào
  `reports/build/tester-reports/<scenario>/` đúng quy ước tên trong
  [`../20-operations/evidence.md`](../20-operations/evidence.md); phiên demo chart chạy có giám sát,
  kill switch sẵn sàng, ghi mục mới vào `../PROGRESS.md`.
- **Mục tiêu:** bằng chứng **hành vi** cho bot trên tick thật của tài khoản demo — đủ dữ liệu
  forward cho đánh giá out-of-sample sau đó. Bot AI chỉ mở sau phase này.
- **Xong khi:** bot demo có ít nhất một phiên tester và một phiên demo có bằng chứng lưu lại
  (hoặc lý do `BLOCKED` ghi rõ thứ còn thiếu).
- **Giới hạn kết quả:** số net từ suite này vẫn là đơn vị mô hình — mục đích là hành vi và dữ liệu
  forward, không phải chứng minh lợi nhuận; nhãn lợi nhuận chỉ đổi sau khi có protocol out-of-sample
  và forward test dài hơn.

### Định nghĩa hoàn thành chung cho cả ba phase

- Source MQL5 compile được (`0 errors, 0 warnings`), hoặc blocker được ghi rõ — không tuyên bố compile
  khi chưa chạy compiler.
- Có test cho mọi giới hạn risk chính; demo hard-gate; tài khoản real bị từ chối tại `OnInit`.
- Mỗi lần chạy có report + config lưu đúng quy ước; mỗi bước có mục mới trong `../PROGRESS.md`.
- Không tài liệu nào hứa hẹn lợi nhuận; AI vẫn ở backlog cho tới khi phase C xong và chủ dự án duyệt.

## 4. Lịch sử

Ba bộ tài liệu trước đã bị thay thế và lưu trữ nguyên trạng trong `99-archive/` — **không còn là
nguồn sự thật**, chỉ để truy vết bằng chứng gốc. Không file nào trong đó được sửa, kể cả link chết.

- `docs/99-archive/MT5_EA_Lab_V1/` — pack mô phỏng đầu tiên.
- `docs/99-archive/MT5_EA_Lab_V2/` — pack "hiện hành" cũ: roadmap, risk model, evidence, đặc tả chiến lược.
- `docs/99-archive/MT5_EA_Lab_V3/` — pack kế hoạch V3: roadmap, diagnostics, research GitHub, input sources.

Ánh xạ link cũ → mới: `docs/99-archive/LINK_MAP.md`. Quyết định kiến trúc thông tin tài liệu (một cây
theo mục đích, một điểm vào, archive bất biến, link-check là gate):
[`../90-decisions/0008-docs-information-architecture.md`](../90-decisions/0008-docs-information-architecture.md).

Ba quy tắc với lịch sử này:

1. **Không trích số từ pack cũ** cho tuyên bố hiện tại — bằng chứng phải là lần chạy mới nhất ghi
   trong `../PROGRESS.md`; số cũ chỉ là lịch sử của phiên đó.
2. **Không sửa file nào trong `99-archive/`**, kể cả link chết bên trong.
3. **Không hồi sinh roadmap cũ.** Phase ở mục 3 trên đây là kế hoạch duy nhất; nếu một mục trong pack
   cũ mâu thuẫn, pack cũ thua.
