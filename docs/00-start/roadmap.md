# Lộ trình

Trạng thái trung thực của lab theo từng mảng, việc đã xong / đang dở / chưa làm, ba phase tiếp theo,
và lịch sử của các bộ tài liệu trước. Quy tắc xuyên suốt: **không nâng nhãn khi chưa có bằng chứng
thật** — nhãn nào dưới đây cũng phải truy ngược được về [`../PROGRESS.md`](../PROGRESS.md) hoặc
[`../20-operations/evidence.md`](../20-operations/evidence.md). Kết quả Strategy Tester chỉ chứng minh
hành vi trong mô phỏng; không kết quả nào là cam kết lợi nhuận hay bằng chứng sẵn sàng cho tài khoản thật.

## 1. Trạng thái hiện tại theo mảng

| Mảng | Nhãn | Một câu |
|---|---|---|
| Tài liệu | `PARTIAL` | Cây mới `00-start`…`99-archive` đã có entry layer, 8 ADR và link checker; phần viết lại link toàn repo (Task 10) chưa chạy nên cổng link-check chưa xanh. |
| PATrendRider XAU v1 (demo) | `PARTIAL` | Đường lệnh có bằng chứng tester thật (`pa_trendrider_demo_exec`: 28 ENTRY/28 EXIT, `config_hash=6B439450`); chưa có `ENTRY` nào do chiến lược tạo trên tài khoản demo. |
| Grid (demo) | `NOT_RUN` | EA + preset + validator sẵn sàng theo ADR 0004; chưa có journal demo/tester nào của bot. |
| DCA (demo) | `NOT_RUN` | EA + preset + validator sẵn sàng theo ADR 0004; chưa có journal demo/tester nào của bot. |
| InfiniteRunner XAU v2 (demo) | `NOT_RUN` | EA demo V2 là canonical theo ADR 0005; mọi phiên demo/tester có lệnh chưa ghi kết quả (PROGRESS §65–§67). |
| Wonderwhales (demo) | `UNPROVEN` | Tester đã chạy thật (`ww_demo_exec`: 41 ENTRY/41 EXIT, net −625.72 đơn vị mô hình); phiên demo trên chart `NOT_RUN`. |
| 6 indicator validator | `PASS` | 6 validator indicator (`validate_pineport`, `validate_pamtf`, `validate_tmfz`, `validate_tmind2`, `validate_tmxau2`, `validate_longkaco`) chạy `fail=0` trên vector cố định. |
| Python/sim | `PASS` | Suite pytest + `validate_sim_configs.py` xanh; số `passed` thay đổi khi thêm test — luôn đọc kết quả lần chạy mới nhất ghi trong `../PROGRESS.md`, không tái sử dụng số cũ. |
| ML/ONNX | `PARTIAL` | ML baseline + export ONNX + runtime MQL5 chạy được (24/24 hàng fixture); parity Track B vẫn `BLOCKED` vì thiếu CSV reference từ Pine. |
| Demo execution (hạ tầng) | `PASS` | `ExecBroker` + `ExecGuard` + kill switch + magic duy nhất đã được probe demo thật xác nhận (`ExecDemoProbe`: BUY 0.01 XAUUSDm, đóng trong 103 ms). |
| Demo execution (chiến lược) | `NOT_RUN` | Chưa có phiên demo thật nào ghi `ENTRY` do chính chiến lược bot tạo ra. |
| Cổng (gate) | `PARTIAL` | `validate-project.py` và `validate_demo_execution.py` xanh; link checker mới nối vào gate, chưa xanh toàn repo cho tới khi link rewrite xong. |
| Lợi nhuận mọi chiến lược | `UNPROVEN` | Mọi số net là đơn vị mô hình trên dữ liệu backtest/mô phỏng; nhãn này đứng yên cho tới khi có forward test dài hơn. |

Mười EA lab (6 sim + 3 signal + 1 inference) giữ nhãn riêng trong
[`../10-bots/README.md`](../10-bots/README.md): từng EA sim `NOT_RUN` (đã có scenario tester chạy thật
nhưng thiếu chu kỳ validation hoàn chỉnh và PROGRESS không ghi nhãn cho từng EA), `LabSignalEA` `PASS`
(§48.5 — 0 trade đúng thiết kế signal-only), `LabOnnxInference` `PARTIAL` (§50).

Cách đọc bảng trên đúng:

- **Một mảng một nhãn** — nhãn nói về deliverable của mảng đó, không trộn với nhãn của mảng khác.
  Ví dụ "hạ tầng demo execution `PASS`" không kéo "chiến lược demo" lên khỏi `NOT_RUN`.
- **Nhãn không lây.** Tester của WW có lệnh không nâng WW khỏi `UNPROVEN`; probe demo thật PASS không
  nâng bất kỳ bot nào; validator xanh không nâng nhãn runtime của EA nào.
- **Mọi nhãn truy ngược được.** Muốn kiểm một nhãn, mở mục tương ứng trong `../PROGRESS.md` — số
  `(§n)` trong các trang bot chính là mục bằng chứng đó.

Hai nhãn phụ từng dùng trong quá khứ — `BLOCKED_PENDING_ADR` cho Grid/DCA demo (đã mở bởi ADR 0004)
và `READY_FOR_MANUAL_VALIDATION` cho parity Pine ↔ MQL5 — giữ nguyên trong lịch sử, không dùng để
chốt trạng thái hiện tại. Định nghĩa đủ 9 nhãn: [`glossary.md`](glossary.md) và
[`../20-operations/evidence.md`](../20-operations/evidence.md).

## 2. Đã xong / đang dở / chưa làm

**Đã xong** (có bằng chứng thật trong `../PROGRESS.md`):

| Việc | Bằng chứng |
|---|---|
| Pipeline Python end-to-end (validate → backtest → ML → store → report) | Phase 9, chạy thật trên dataset synthetic, hai run lưu vào experiment store |
| ONNX inference runtime MQL5 | `LabOnnxInference` nạp model, 24/24 hàng fixture khớp tolerance, provider CPU |
| Hạ tầng demo execution | `mt5/Include/Exec/*`: guard, kill switch, magic duy nhất, SL/TP bắt buộc; `ExecDemoProbe` khớp lệnh thật trên tài khoản demo |
| 5 EA demo compile + đăng ký validator/preset | Build 0 errors, 0 warnings (build 6292); preset JSON trong `configs/demo/` |
| Strategy Tester cho PA + WW demo exec | `pa_trendrider_demo_exec`, `ww_demo_exec` — CSV + `.htm` + journal 18 cột lưu trong `reports/build/tester-reports/` |
| Tái cấu trúc tài liệu theo mục đích | ADR 0008; cây `00-start`…`99-archive`, entry layer, link checker `scripts/check_docs_links.py` |
| Research mã nguồn mở | 7/7 repo có commit SHA + license, 0 `USE` (PROGRESS mục GitHub audit) |

**Đang dở** (một phần acceptance criteria đã kiểm, phần còn lại ghi rõ):

| Việc | Đã kiểm | Chưa kiểm |
|---|---|---|
| Tái cấu trúc tài liệu (phase A) | Cây mới, 8 ADR, entry layer, Task 5–8 viết trang bot/operations/research/archive | Viết lại link toàn repo, cổng link-check xanh |
| Chuẩn hoá input (phase B) | Đặc tả duyệt + bảng gap đã quét từ source 2026-11-03 trong `../10-bots/input-convention.md` | Sửa 5 EA demo theo 6 nhóm input, mỗi EA một commit |
| Demo forward | Hạ tầng chạy được, probe PASS, tester PA/WW có lệnh | `ENTRY` demo do chiến lược của từng bot trên tài khoản demo |
| Parity Pine ↔ MQL5 | Comparator + test PASS trên dữ liệu tổng hợp | CSV reference thật xuất từ Pine — thiếu là `BLOCKED`, không tạo CSV giả |

**Chưa làm:**

| Việc | Điều kiện bắt đầu |
|---|---|
| Suite demo XAUUSD tự động (5 bot × tester + chart demo) | Phase A + B xong, cả 3 lệnh cổng xanh |
| Đánh giá out-of-sample / walk-forward protocol | Suite demo cho số liệu forward thật, dữ liệu tách rõ train/test |
| Nghiên cứu AI (backlog) | Chỉ mở khi các mục trên xong và chủ dự án duyệt |

## 3. Ba phase tiếp theo

### Phase A — Tái cấu trúc tài liệu (đang chạy)

Phần còn lại của reorg: viết lại link trong toàn bộ tài liệu hiện hành trỏ về cây mới (bản ánh xạ
`docs/99-archive/LINK_MAP.md`), rồi làm cổng xanh.

- **Việc:** rewrite link cũ (`v2/`, `archive/`, đường dẫn tuyệt đối) theo LINK_MAP; không đụng
  `PROGRESS.md` và `99-archive/` (cả hai được miễn kiểm link vì là lịch sử bất biến).
- **Xong khi:** `python scripts\check_docs_links.py` → `broken=0`; `python scripts\validate-project.py`
  → `fail=0`; `python -m pytest` → `0 failed` — cả ba ghi vào `../PROGRESS.md` ở lần chạy mới nhất.
- **Chống mục tiêu:** không tạo thêm một "bộ tài liệu v4"; không "sửa" link chết bằng cách trỏ tất cả
  về `99-archive/`; không tắt check trong validator để cổng xanh.

### Phase B — Chuẩn hóa input theo `input-convention.md`

Áp dụng chuẩn 6 nhóm input cho từng EA demo — **mỗi EA một commit**, không chạm 5 EA trong một commit,
theo thứ tự migration mục 7 của [`../10-bots/input-convention.md`](../10-bots/input-convention.md).
Thứ tự EA khuyến nghị: PA → Grid → DCA → IR → WW (PA trước vì có 2 input thiếu riêng; IR cuối để gom
đổi `Pts`→`Points` một lần).

- **Việc từng EA:** thêm input thiếu theo ma trận gap; đổi tên group về `01 Execution`…`06 Strategy`
  đúng thứ tự; đổi `Pts`→`Points` (chỉ IR, gom bước cuối); cập nhật preset JSON + `.set` **cùng lúc**;
  chạy `validate-project.py` (`fail=0`) + `scripts/build-mql5.ps1` (`0 errors, 0 warnings`); ghi mục
  mới vào `../PROGRESS.md` kèm `config_hash` mới nếu preset đổi.
- **Phạm vi:** 5 EA demo + preset + validator. Không đụng EA mô phỏng, không đổi logic chiến lược,
  không đổi magic number.
- **Xong khi:** cả 5 EA demo khai input đúng chuẩn 6 nhóm; validator ép đủ "preset đủ key, không
  thừa/thiếu"; ma trận gap mục 5 của `input-convention.md` không còn ô "thiếu".

### Phase C — Suite demo XAUUSD

5 bot × (Strategy Tester headless + phiên demo trên chart) trên `XAUUSDm`.

- **Việc:** mỗi lần chạy ghi `config_hash` + journal CSV + report `.htm` vào
  `reports/build/tester-reports/<scenario>/` đúng quy ước tên trong
  [`../20-operations/evidence.md`](../20-operations/evidence.md); phiên demo chart chạy có giám sát,
  kill switch sẵn sàng, ghi mục mới vào `../PROGRESS.md`.
- **Mục tiêu:** bằng chứng **hành vi** cho từng bot trên tick thật của tài khoản demo — đủ dữ liệu
  forward cho đánh giá out-of-sample sau đó. Bot AI chỉ mở sau phase này.
- **Xong khi:** mỗi bot demo có ít nhất một phiên tester và một phiên demo có bằng chứng lưu lại
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

- `docs/99-archive/MT5_EA_Lab_V1/` — pack mô phỏng đầu tiên: `MASTER_ROADMAP_v1.md`,
  `ROADMAP_MT5_EA_AI_LAB_v1.md`, prompt AI, đặc tả PA_TrendRider, phase report 0–6.
- `docs/99-archive/MT5_EA_Lab_V2/` — pack "hiện hành" cũ: `ROADMAP.md`, risk model, evidence,
  troubleshooting, đặc tả Grid/DCA/InfiniteRunner, GITHUB_AUDIT.
- `docs/99-archive/MT5_EA_Lab_V3/` — pack kế hoạch V3: `ROADMAP_MT5_EA_LAB_V3.md`, diagnostics
  0-trade, research GitHub, input sources.

Ánh xạ link cũ → mới: `docs/99-archive/LINK_MAP.md`. Quyết định kiến trúc thông tin tài liệu (một cây
theo mục đích, một điểm vào, archive bất biến, link-check là gate):
[`../90-decisions/0008-docs-information-architecture.md`](../90-decisions/0008-docs-information-architecture.md).

Ba quy tắc với lịch sử này:

1. **Không trích số từ pack cũ** cho tuyên bố hiện tại — bằng chứng phải là lần chạy mới nhất ghi
   trong `../PROGRESS.md`; số cũ chỉ là lịch sử của phiên đó.
2. **Không sửa file nào trong `99-archive/`**, kể cả link chết bên trong — bản gốc phải giữ nguyên
   từng byte để truy vết được.
3. **Không hồi sinh roadmap cũ.** Phase ở mục 3 trên đây là kế hoạch duy nhất; nếu một mục trong pack
   cũ mâu thuẫn, pack cũ thua.

