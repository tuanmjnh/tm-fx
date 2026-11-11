# Kế hoạch nâng cấp tổng thể (dành cho AI agent và người duy trì)

**Ngày:** 2026-11-09 · **Đối tượng đọc:** AI coding agent (Codex, Claude Code…) làm việc trong repo này, và chủ dự án
khi giao việc cho agent. **Đọc kèm:** [`../../AGENTS.md`](../../AGENTS.md), [`roadmap.md`](roadmap.md),
[`../PROGRESS.md`](../PROGRESS.md), [`../20-operations/evidence.md`](../20-operations/evidence.md).

Tài liệu này là **bản đồ việc**, không phải bằng chứng. Mọi con số "hiện trạng" bên dưới được đo ngày 2026-11-09 bằng
các lệnh ở §4; nhãn trạng thái của từng bot vẫn lấy từ [`roadmap.md`](roadmap.md) và không được nâng ở đây.

## 1. Mục tiêu nâng cấp (một câu mỗi hướng)

1. **Tin được:** cổng kiểm tra tự động, tài liệu khớp code, không số liệu lỗi thời.
2. **Đo đúng:** mọi kết luận về chiến lược dựa trên expectancy **sau chi phí** có khoảng tin cậy, không dựa vào winrate.
3. **Có edge hay không:** InfiniteRunner (và các bot khác) chỉ được "nâng cấp" khi có bằng chứng, theo
   [`../30-research/infinite-runner-long-run-study.md`](../30-research/infinite-runner-long-run-study.md).
4. **AI đúng chỗ:** model ML/ONNX là *cổng lọc* trên một tín hiệu đã có lợi thế gộp đo được, không phải nguồn tín hiệu.
5. **Agent làm việc an toàn:** một lệnh chạy mọi cổng, danh sách "không được làm" rõ ràng, việc nhỏ có tiêu chí chấp nhận.

## 2. Hợp đồng bất biến — agent không được vi phạm

Nguồn: [`../../README.md`](../../README.md) "Ranh giới an toàn", [`../../AGENTS.md`](../../AGENTS.md), ADR 0002–0006.

| # | Quy tắc | Cách kiểm |
|---|---|---|
| I1 | Chỉ tài khoản **demo** hoặc Strategy Tester; không bao giờ real/live | `ExecGuard.ExecContextAllowed`; `validate_demo_execution.py` |
| I2 | Mọi lệnh đi qua `mt5/Include/Exec/ExecBroker.mqh` (điểm gửi lệnh duy nhất) | `validate-project.py` quét API cấm ngoài `Exec/*` |
| I3 | SL **và** TP bắt buộc trên mọi lệnh; kill switch; magic duy nhất; ledger rủi ro có trần cứng | validator + test guard |
| I4 | Không credential, không login automation, không `WebRequest`/socket | `validate-project.py` |
| I5 | `docs/99-archive/` và `archive/` **chỉ đọc**; `docs/PROGRESS.md` **chỉ thêm cuối** (append-only) | `check_docs_links.py` miễn trừ có chủ đích |
| I6 | Không nâng nhãn (`NOT_RUN`→`PARTIAL`→`PASS`) khi chưa có bằng chứng thật trong `PROGRESS.md` | [`../20-operations/evidence.md`](../20-operations/evidence.md) |
| I7 | Không tuyên bố lợi nhuận từ backtest/mô phỏng; lợi nhuận mọi chiến lược là `UNPROVEN` | glossary |
| I8 | **Không bịa kết quả.** Không có MT5 → ghi rõ "chưa compile / chưa chạy tester", để `NOT_RUN` | quy tắc của tài liệu này |
| I9 | Không commit dữ liệu tài khoản, secret, `.ex5`, dữ liệu thô (`datasets/raw`, `reports/*`, journal > 1 MB) | `.gitignore` |
| I10 | Nới một hàng rào an toàn (vd. khoá drawdown) cần **ADR riêng** và quyết định của chủ dự án | ADR README |

Ngôn ngữ: tài liệu tiếng Việt có dấu, token kỹ thuật/tên input giữ tiếng Anh; commit theo kiểu
`feat(ir): …`, `fix(ir): …`, `docs(ir): …`, `test(ww): …`, `chore(...)` như lịch sử git hiện có.

## 3. Hiện trạng xuất phát (đo 2026-11-09)

| Hạng mục | Kết quả | Ghi chú |
|---|---|---|
| `python -m pytest -q` | **496 passed** | môi trường `requirements.txt` ghim; Python 3.12.3 (baseline ghi 3.11) |
| `validate-project.py` | `checks=7 fail=0` | |
| `validate_demo_execution.py` | `checks=8 fail=0` | |
| `check_docs_links.py` | `broken=0` | số `checked` xem lệnh chạy |
| `ruff check python scripts` | 165 lỗi (121 tự sửa được) | chưa có cấu hình ruff |
| Compile MQL5 | **chưa đo được** ngoài Windows/MetaEditor | `scripts/deploy_pineport.ps1` |
| Bằng chứng chiến lược | mọi bot `NOT_RUN`/`UNPROVEN`/`PARTIAL` | InfiniteRunner: không có edge chứng minh được |

Phát hiện cần sửa (đã kiểm chứng bằng code/lệnh):

- Kho hiện chỉ còn **một bot demo** (`InfiniteRunnerXAUV2DemoEA`); `mt5/Experts/` có đúng một file `.mq5` và
  `configs/demo/` có đúng một preset. Các EA/indicator khác đã bị gỡ khỏi repo.
- `mt5/Scripts/CloseDemoPosition.mq5` gọi `OrderSend` **trực tiếp** (include `ExecBroker.mqh` nhưng không dùng
  `ExecClosePosition`) và không tự kiểm demo/tester. File này nằm **tường minh** trong allowlist `EXEC_SOURCES` của
  `scripts/validate-project.py` nên validator xanh — là ngoại lệ có chủ đích, nhưng câu "mọi lệnh đi qua `ExecBroker`" ở
  README chưa nêu ngoại lệ đó. Rủi ro thấp (chỉ đóng vị thế magic `25006001` trên symbol hiện tại).
- `python/tests/test_data_loader.py` cứng `datetime64[ns, UTC]`; pandas mới đổi sang `us` ⇒ lỗi khi nâng phiên bản.
- Không có CI (`.github/` không tồn tại); cổng chỉ chạy tay.
- (Đính chính) `docs/PROGRESS.md` và `docs/99-archive/` có nhiều link tương đối cũ, nhưng đó là **miễn trừ có chủ đích**
  của `check_docs_links.py` — không sửa.

## 4. Lệnh chạy các cổng

```powershell
# từ thư mục gốc repo, trong .venv đã cài requirements.txt
.venv\Scripts\python.exe -m pytest -q
.venv\Scripts\python.exe scripts\validate-project.py
.venv\Scripts\python.exe scripts\validate_demo_execution.py
.venv\Scripts\python.exe scripts\check_docs_links.py
.venv\Scripts\python.exe -m ruff check python scripts      # chỉ sau khi T1.3 thêm cấu hình
# MQL5: không chạy được ngoài Windows. Compile + deploy:
#   scripts\deploy_pineport.ps1 -Apply -Force   (cần MetaEditor; ghi 0 errors / 0 warnings)
```

Một việc chỉ "xong" khi **mọi** cổng chạy được đều xanh **và** số liệu trong tài liệu liên quan được cập nhật.

## 5. Backlog ưu tiên

Ký hiệu: **P0** làm trước, **P1** tiếp theo, **P2** khi có thời gian. Mỗi dòng phải nhỏ đủ để một agent làm trong một lượt
và có tiêu chí chấp nhận kiểm được bằng lệnh. ID `T*` để không nhầm với `E*`/`H*` trong nghiên cứu InfiniteRunner.

### T1 — Tin được (vệ sinh, cổng, tài liệu)

| ID | Ưu tiên | Việc | Tiêu chí chấp nhận |
|---|---|---|---|
| T1.1 | P0 | Đồng bộ danh mục và bảng cổng trong `README.md`, `docs/README.md`, `docs/10-bots/README.md`, `docs/00-start/roadmap.md` với thực tế IR-only (một bot demo) | một con số bot duy nhất ở mọi nơi; bảng cổng khớp lệnh §4; `check_docs_links.py` xanh |
| T1.2 | P1 | `CloseDemoPosition.mq5`: đóng vị thế qua `ExecClosePosition` và kiểm demo/tester; **hoặc** giữ nguyên và ghi ngoại lệ vào README/`docs/20-operations/demo-execution.md` | một trong hai: không còn `OrderSend` ngoài `ExecBroker.mqh`, hoặc ngoại lệ được tài liệu hoá; `validate-project.py` xanh; nếu sửa code thì **compile thủ công** (`NOT_RUN` tới khi compile) |
| T1.3 | P1 | Thêm `[tool.ruff]` vào `pyproject.toml`; chạy `ruff check --fix`; xử lý phần còn lại bằng tay | `ruff check python scripts` = 0; `pytest` vẫn 496 passed |
| T1.4 | P1 | Sửa test dtype: kiểm `dtype.kind == "M"` và tz UTC thay vì chuỗi `ns` | test xanh với pandas 2.3.3 **và** bản mới hơn |
| T1.5 | P1 | Thêm CI (GitHub Actions, Ubuntu, Python 3.11): pytest + 3 validator + link check | workflow xanh trên nhánh chính; compile MQL5 vẫn thủ công, ghi rõ trong workflow |
| T1.6 | P2 | Ghi vào `docs/20-operations/install.md` Python 3.11 (baseline) và 3.12 (đã chạy 496 pass) | install.md khớp thực tế |

### T2 — Đo đúng (hạ tầng nghiên cứu)

| ID | Ưu tiên | Việc | Tiêu chí chấp nhận |
|---|---|---|---|
| T2.1 | P0 | `scripts/tester/ir_breakdown.py` (streaming, như `analyse_ir.py`): tách lãi/lỗ theo **hướng × năm × phân vị lệnh**; thêm test với journal tổng hợp | pytest xanh; chạy được trên journal 190 MB không nạp hết RAM; ghi nhãn `NOT_STRATEGY_RESULT` |
| T2.2 | P0 | Mở rộng `analyse_ir.py`: winrate hoà vốn `p*`, spread suy ra, expectancy + **CI bootstrap**, độ nhạy spread ×2 | công thức khớp [study §3–§4](../30-research/infinite-runner-long-run-study.md); test số học với dữ liệu tổng hợp |
| T2.3 | P1 | Thêm cột **spread** (và swap nếu có) vào journal; **tăng version schema** SimLogger, không phá cột cũ | validator + test journal cập nhật; `analyse_*` đọc được cả schema cũ |
| T2.4 | P1 | `gen_ir_sets.py`: tuỳ chọn real ticks và spread cố định; sinh cặp scenario IS/OOS (walk-forward) | scenario mới có tên, sinh từ JSON nguồn, không sửa tay `.set` |
| T2.5 | P2 | Ghi **mọi** lần chạy (kể cả âm) vào experiment store hiện có | `experiment-store.md` mô tả cách ghi; không xoá run |

### T3 — InfiniteRunner (theo [nghiên cứu](../30-research/infinite-runner-long-run-study.md))

| ID | Ưu tiên | Việc | Tiêu chí chấp nhận |
|---|---|---|---|
| T3.1 | P0 | Chạy **E1** (cần journal `long_exit_run`/`long_base_nolock` trên máy chủ dự án): phân rã lãi gộp theo hướng × năm × đuôi; ghi kết quả vào §5 của nghiên cứu | kết luận rõ: beta/may mắn hay trend-persistence; commit evidence nhỏ (JSON/PNG) |
| T3.2 | P0 | Port bản sửa deadlock **U1** (`InpLossStreakCooldownMinutes`, `IRRisk.mqh`) vào bản V3, hoặc gộp V3 vào V2 sau cờ `InpEnableStructureTrailing=false` mặc định (**khuyến nghị**: một EA, một magic, một preset) | `IRCoreTests` xanh; không còn đường khoá vĩnh viễn trừ khi cố ý (`=0`); **compile thủ công** |
| T3.3 | P1 | **E2** (spread theo giờ) rồi **H-A/H-C** (giảm tần suất, lọc chi phí) — các biến kiểm soát rẻ nhất | kết quả ghi theo §8 của nghiên cứu, kể cả âm |
| T3.4 | P1 | **E3** V3/structure trailing × BE {0; 1,0; 1,5R} trên cửa sổ đầy đủ | so với `long_exit_run` (−2.078); kết luận bác bỏ/giữ |
| T3.5 | P1 | Soạn **ADR 0010** (đưa structure trailing vào bot demo hiện hữu) nếu T3.2 chọn gộp | ADR có trạng thái do chủ dự án chốt |
| T3.6 | P2 | **H-B** (giữ lâu, SL/trail khung lớn) và **H-D** (entry theo regime) — **spec trước**, mẫu lớn, OOS | cổng G1–G4 trong nghiên cứu §9 |
| T3.7 | P2 | **H-E**: chính sách hồi phục sau khoá drawdown (pause + giảm risk) | **ADR riêng** (I10); không đổi mặc định khi chưa có ADR |
| T3.8 | P2 | Cập nhật [`../10-bots/infinite-runner.md`](../10-bots/infinite-runner.md) khi bất kỳ việc nào ở trên đổi hành vi | trang bot khớp code, nhãn không đổi |

### T4 — AI/ML đúng chỗ

Cơ sở hiện có: ML baseline logistic + split có purge + label không rò rỉ + export ONNX + parity
([`../30-research/ai-integration.md`](../30-research/ai-integration.md), [`ml-baseline`](../30-research/ml-baseline.md)).
Hạn chế: chỉ chạy trên dữ liệu **synthetic**; parity Track B `BLOCKED` vì thiếu CSV tham chiếu từ Pine.

| ID | Ưu tiên | Việc | Tiêu chí chấp nhận |
|---|---|---|---|
| T4.1 | P1 | Nhãn **sau chi phí**: kết quả lệnh kế tiếp tính bằng R đã trừ spread (kiểu triple-barrier có spread), không dùng hướng giá thuần | test chống rò rỉ giữ xanh; tài liệu ghi định nghĩa nhãn |
| T4.2 | P1 | **Đường cơ sở bắt buộc:** "luôn vào" và "cổng ngẫu nhiên cùng N lệnh"; model chỉ có giá trị nếu thắng cả hai ngoài mẫu | báo cáo Δ expectancy + CI, ngoài mẫu walk-forward |
| T4.3 | P2 | Quy trình lấy dữ liệu thật XAUUSDm M5 từ MT5 (gitignored) + data card + checksum | `data-dictionary.md` cập nhật; không commit dữ liệu thô |
| T4.4 | P2 | Canary rò rỉ: xáo thứ tự thời gian ⇒ hiệu năng phải sụp về ngẫu nhiên | test pytest |
| T4.5 | Cần người | Mở khoá parity Track B: cung cấp CSV tham chiếu xuất từ Pine | chủ dự án cung cấp file |

Nguyên tắc: AI ở **mức B** (cổng thêm, xem `ai-integration.md` §1). Mức C (AI quyết định hướng/kích thước) cần ADR trước
và chỉ sau khi có tín hiệu nền với lợi thế gộp đo được. Một model không thể tạo edge từ dữ liệu không có edge.

### T5 — Agent làm việc an toàn

| ID | Ưu tiên | Việc | Tiêu chí chấp nhận |
|---|---|---|---|
| T5.1 | P0 | Thêm con trỏ tới tài liệu này vào `AGENTS.md` và `docs/README.md` | link resolve; `check_docs_links.py` xanh |
| T5.2 | P1 | `scripts/run_gates.py`: chạy mọi cổng ở §4, in một bảng PASS/FAIL, exit ≠ 0 nếu có cổng đỏ | pytest cho chính script; chạy được không cần MT5 |
| T5.3 | P2 | Mẫu mục `PROGRESS.md` (chỉ thêm cuối): ngày, việc, lệnh, kết quả, nhãn, đường dẫn bằng chứng | mẫu nằm trong `evidence.md` |

## 6. Quy trình cho mỗi việc

1. **Đọc** `AGENTS.md`, mục tương ứng trong bảng §5, trang bot/nghiên cứu liên quan. Đừng viết từ con số 0 khi chức năng
   chưa quen: so sánh với mã nguồn mở trước (quy tắc "Open Source First" trong `AGENTS.md`).
2. **Chạy cổng nền** (§4) và ghi số trước khi sửa. Nếu đã đỏ trước khi bạn đụng vào, báo ngay.
3. **Một thay đổi, một mối quan tâm.** Đổi một biến mỗi thí nghiệm. Không gộp sửa hạ tầng với đổi chiến lược.
4. **Python:** viết test trước, rồi code. **MQL5:** không compile được ⇒ ghi rõ "chưa compile", nhãn `NOT_RUN`; không viết
   "0 errors" nếu chưa chạy MetaEditor.
5. **Chạy lại cổng**, cập nhật tài liệu và chỉ mục (`docs/README.md`, README của thư mục liên quan).
6. **Evidence:** kết quả chạy thật (kể cả âm) → mục mới ở cuối `PROGRESS.md` + file nhỏ trong `docs/30-research/evidence/`
   (PNG/JSON). Không commit journal thô.
7. **Commit** theo kiểu lịch sử git hiện có; mô tả *vì sao*, không chỉ *cái gì*.
8. **Báo cáo trung thực:** nêu cái đã chạy, cái **chưa** chạy, và mọi giả định.

Không làm: sửa `archive/`, `docs/99-archive/` hay mục cũ của `PROGRESS.md`; tắt validator để "cho xanh"; nới trần rủi ro,
SL/TP bắt buộc hay kiểm tra demo; thêm `WebRequest`/socket; tối ưu tham số trên một cửa sổ ngắn rồi kết luận.

## 7. Điểm cần con người quyết

| Quyết định | Vì sao agent không tự làm |
|---|---|
| Gộp V3 vào V2 hay giữ bot thứ bảy | thêm/đổi bot demo cần ADR (I10) |
| Chính sách khoá drawdown (halt vĩnh viễn hay hồi phục) | nới hàng rào an toàn |
| Equity demo và risk % cho thử nghiệm | quyết định vận hành |
| Cung cấp journal Strategy Tester, dữ liệu XAUUSDm và CSV Pine | nằm trên máy dự án, bị gitignore |
| Nhãn nào được nâng sau forward test | cần bằng chứng và phê duyệt |

## 8. Prompt khởi động mẫu cho agent

```text
Bạn đang làm việc trong repo tm-fx (MT5 EA & AI Lab). Đọc AGENTS.md và docs/00-start/ai-upgrade-plan.md.
Việc của bạn: <ID trong bảng §5, ví dụ T1.1>.
Ràng buộc: tuân thủ §2 (hợp đồng bất biến); chạy cổng ở §4 trước và sau khi sửa; không nâng nhãn; không bịa số liệu;
nếu cần MT5 mà không có, ghi rõ "chưa chạy" và để NOT_RUN.
Đầu ra: danh sách file đã đổi, kết quả từng cổng (trước/sau), việc chưa làm, và các giả định.
```
