# Thiết kế: Reset dữ liệu/artifact local + sinh lại (giữ bộ tooling tester)

- **Ngày:** 2026-11-04
- **Trạng thái:** DRAFT — chờ chủ dự án duyệt
- **Phạm vi:** dọn các artifact dữ liệu local (gitignored) trong `reports/`, `experiments/`,
  `models/candidates/`; giữ bộ điều khiển Strategy Tester (`.ini` + `.set`) thành công cụ được commit;
  sinh lại các artifact có script tất định; và cập nhật tài liệu đang trích dẫn artifact bị dọn.
- **Nguồn tham chiếu:** `../specs/2026-11-03-tm-fx-docs-reorg-design.md` (cây tài liệu),
  `../plans/2026-11-03-tm-fx-docs-reorg.md`, `../../PROGRESS.md`.

---

## 1. Bối cảnh và mục tiêu

Sau khi tái cấu trúc tài liệu xong (phase A, 2026-11-03), repository còn tồn một lượng lớn artifact
sinh ra trong quá trình nghiên cứu (`reports/` ~133 MB, 5 database demo `experiments/*.sqlite`, model
ONNX `models/candidates/demo-phase7-ml/`). Phần lớn là scratch dùng một lần, nhưng một số bị tài liệu
còn hiệu lực trích dẫn (kể cả sha256) và một phần không sinh lại y hệt được.

**Mục tiêu:** dọn sạch artifact local để có mặt bằng sạch trước phase B/C; giữ lại đúng những gì dùng
lại được (bộ điều khiển tester); sinh lại các artifact có script tất định để chứng minh quy trình vẫn
chạy; giữ tài liệu trung thực (không trích dẫn bằng chứng đã bị xoá).

**Vì sao bây giờ:** phase B (chuẩn hoá input) và phase C (suite demo XAUUSD) sẽ tạo ra bộ bằng chứng
mới; dọn trước để không lẫn artifact cũ với artifact mới.

## 2. Goals / Non-goals / Anti-goals

**Goals**
- Dọn sạch artifact local bị gitignore trong `reports/`, `experiments/`, `models/candidates/`.
- Bảo toàn bộ điều khiển Strategy Tester (`.ini` + `.set`) dưới dạng file được Git theo dõi.
- Sinh lại được các artifact có script tất định (dataset mẫu, pipeline demo, ML baseline, ONNX).
- Cập nhật mọi tài liệu còn hiệu lực đang trích dẫn artifact bị dọn, giữ đúng quy tắc trung thực.
- Ghi lại sự kiện này vào `PROGRESS.md` (append-only).

**Non-goals**
- Không lấy dữ liệu thị trường thật; không nối broker; không tạo script tải dữ liệu.
- Không chạy lại Strategy Tester trong phase này (để phase C).
- Không sửa `configs/**`, không sửa logic/`input` trong `mt5/**`, không sửa preset.

**Anti-goals (thất bại dù kỹ thuật chạy được)**
- Xoá artifact rồi vẫn để tài liệu khẳng định bằng chứng hiện hữu (trích dẫn treo mà không đánh dấu).
- Đẩy nhầm artifact (~130 MB) hoặc `.sqlite` vào Git.
- Xoá thứ không sinh lại được mà không ghi lại rõ.
- Sửa nội dung `docs/99-archive/**` (bất biến).

## 3. Ràng buộc

1. **Chỉ demo/Strategy Tester.** Không real/live, không credential, không `MetaTrader5` Python.
2. **`docs/99-archive/**` bất biến**; `docs/PROGRESS.md` chỉ append.
3. **Không sửa `configs/demo/*.json`, `configs/sim/*.json`** — preset là nguồn sự thật, chỉ đọc.
4. **Không sửa `input`/logic `.mq5`/`.mqh`.**
5. **Không nâng nhãn trạng thái** của bot nào (bộ 9 nhãn cố định).
6. **Cổng phải xanh sau cùng:** `check_docs_links.py` `broken=0`; `validate-project.py` `checks=15 fail=0`;
   `validate_demo_execution.py` `checks=13 fail=0`; `pytest` `436 passed`.
7. Mọi lệnh chạy từ `D:\Applications\tm-fx` bằng `.\.venv\Scripts\python.exe`.

## 4. Các hướng đã cân nhắc

| Hướng | Nội dung | Đánh đổi | Kết luận |
|---|---|---|---|
| A | Chỉ dọn scratch, **giữ** toàn bộ bằng chứng tester | An toàn, docs không đổi; nhưng còn ~130 MB và chưa "mới" | Loại (không đạt mục tiêu dọn sạch) |
| B | **Dọn sạch** (kể cả bằng chứng tester) + sinh lại bằng chứng mới | Sạch nhất; tốn công, phải cập nhật docs, archive thành trích dẫn treo | **Chọn** |
| C | Chỉ sinh lại fixture/sample, không đụng `reports/` | Nhanh; gần như không dọn được gì | Loại |

**Biến thể đã chốt trong hướng B:** bằng chứng Strategy Tester **không chạy lại trong phase này**. Bộ
`.ini`/`.set` được giữ làm công cụ; phase C sẽ dùng nó để sinh bằng chứng tester mới cho 5 bot demo.
Lý do: tránh chạy ~30 scenario hai lần, và nhiều số sẽ trùng lại vô ích.

## 5. Quyết định: xoá gì / giữ gì / sinh lại gì

### 5.1 Xoá (đều đã bị gitignore — không tạo diff Git)

| Đối tượng | Ghi chú |
|---|---|
| `reports/**` trừ `reports/README.md` | Toàn bộ `reports/build/**` (tester-reports, contract-reports, deploy*, packages ~11 MB, shots, lab, q8-diag, trendrider, demo-arm, demo-exec-probe-20261029, tester-run, tester-sets, …) và các thư mục lẻ (`backtests`, `ml`, `onnx`, `onnx-tmp`, `onnx-missing-check`, `pipeline`, `validation`, `parity`, `comparisons`, `config-snapshots`, `dataset-check`, `demo-watch`, `mt5`, `phase6-cli-check`, `plan_audit`, `build-demo`, `build-w10`, `backup-docs-20261028.zip`) |
| `experiments/*.sqlite` | Giữ `experiments/README.md` |
| `models/candidates/*` trừ `.gitkeep` | Giữ `models/registry.json` (`models: []`) |

### 5.2 Giữ (đã được Git theo dõi — chỉ đọc/không đổi)

`reports/README.md`, `experiments/README.md`, `models/registry.json`, `models/candidates/.gitkeep`,
`datasets/{raw,processed}/.gitkeep`, `datasets/samples/{README.md, parity_ema_cross.csv,
synthetic_ema_cross_demo.csv, synthetic_ml_demo.csv}`.

**`github-demo/` (13 MB, gitignored):** *đề xuất giữ* — là vật liệu audit cho
`docs/30-research/open-source-research.md`. **Cần bạn xác nhận** (xem §9, câu hỏi Q1).

### 5.3 Bảo toàn thành công cụ (file mới được Git theo dõi)

| Nguồn (gitignored) | Đích (tracked) |
|---|---|
| `reports/build/tester-run/*.ini` (40 file) | `scripts/tester/ini/*.ini` |
| `reports/build/tester-sets/*.set` (27 file) | `scripts/tester/set/*.set` |
| — | `scripts/tester/README.md` — cách chạy headless: `terminal64.exe /config:<ini>`, `ShutdownTerminal=1`, copy `.set` vào `MQL5\Profiles\Tester\`, MT5 phải đóng |

Không commit report/CSV/HTM sinh ra. Runner tự động (`scripts/run_tester.ps1`) **hoãn sang phase C**.

### 5.4 Sinh lại (script tất định, chạy trong phase này)

| Artifact | Lệnh | Kỳ vọng |
|---|---|---|
| Dataset ML mẫu | `generate_synthetic_ml_dataset.py` (seed 20261027) | Ra **đúng byte cũ** → không đổi Git |
| Validation dataset | `validate_dataset.py` trên sample | `passed=true`; report ghi vào `reports/validation/` |
| Pipeline demo | `run_pipeline.py --config configs/pipeline.example.yaml --run-id data-reset-<date>` | Exit `0`; số khớp bảng §5 `pipeline.md` |
| ML baseline + ONNX | `train_ml_baseline.py` + `export_onnx_model.py` | Parity PASS (24 hàng), `model_sha256` khớp `pipeline.md` |

Tất cả ghi vào thư mục gitignored (`reports/`, `experiments/`, `models/candidates/`) — chứng minh quy
trình còn chạy được, không để lại rác trong Git.

## 6. Cập nhật tài liệu (giữ trung thực)

Sau khi dọn, các artifact bị trích dẫn **không còn tồn tại** cho tới phase C. Quy tắc xử lý:

1. **`docs/20-operations/evidence.md`** — bảng "Bằng chứng theo tuyên bố": các dòng trích sha256 của file
   trong `reports/build/tester-reports/…` và `reports/build/demo-exec-probe-20261029/` phải đổi sang
   trạng thái **"artifact đã dọn 2026-11-04 — bằng chứng tester sẽ sinh lại ở phase C"**, không còn khẳng
   định có thể kiểm lại ngay. Giữ nguyên con số đã ghi như *dấu vết lịch sử* (PROGRESS là bản ghi).
2. **Các trang bot** (`docs/10-bots/{pa-trendrider,wonderwhales,grid,dca,infinite-runner}.md`) — mục
   "Bằng chứng": thêm một câu chuẩn về việc artifact local đã dọn, chờ phase C; không đổi nhãn bot.
3. **`docs/20-operations/{strategy-tester,install,troubleshooting}.md`, `docs/30-research/{simulation,
   testing}.md`, `docs/30-research/indicators/*.md`, `docs/00-start/roadmap.md`** — chỉ sửa những câu
   trích *file cụ thể* hoặc *sha256*; câu mô tả thư mục `reports/build/tester-reports/` giữ nguyên.
4. **`docs/30-research/pipeline.md`** — nếu số sinh lại khớp, không đổi; nếu lệch, ghi rõ môi trường.
5. **`docs/99-archive/**`** — **không sửa**; các trích dẫn cũ ở đây chấp nhận là trích dẫn lịch sử treo.
6. **`docs/PROGRESS.md`** — append `§71. Reset dữ liệu local + sinh lại (2026-11-04)` ghi: đã dọn gì,
   giữ gì, sinh lại gì (kèm exit code/hash thật), và mục "Còn mở" nêu bằng chứng tester đang chờ phase C.

**Quyết định cần bạn chốt (Q2 §9):** các dòng trong `evidence.md` đang gắn nhãn `PASS` cho *hành vi
tester* (PA, WW) — giữ nhãn `PASS` kèm ghi chú "artifact đã dọn" (vì PROGRESS ghi lần chạy thật), hay
hạ xuống `NOT_RUN`/`PARTIAL` cho tới khi phase C chạy lại?

## 7. Quy trình thực thi (thứ tự)

1. **Kiểm kê trước khi xoá** ("check test cũ"): liệt kê mọi tài liệu trích dẫn artifact sắp xoá
   (đã có: `evidence.md`, 5 trang bot, `pipeline.md`, các trang operations/simulation/indicators);
   chạy `pytest` baseline (`436 passed`) và ghi lại.
2. **Sao chép tooling ra `scripts/tester/`** (`.ini`, `.set`) + viết `scripts/tester/README.md`.
3. **Xoá** artifact local theo §5.1 (giữ README/`.gitkeep`/registry).
4. **Sinh lại** theo §5.4; ghi lại exit code và hash thật.
5. **Cập nhật tài liệu** theo §6; append `PROGRESS.md` §71.
6. **Xác minh** theo §8.
7. Commit (một commit cho việc dọn + tooling + docs; artifact sinh lại nằm ngoài Git).

## 8. Xác minh (Definition of Done)

- [ ] `scripts/tester/` tồn tại với đủ 40 `.ini` + 27 `.set` + README; các file này tracked.
- [ ] `reports/` chỉ còn `README.md`; `experiments/` chỉ còn `README.md`; `models/candidates/` chỉ còn `.gitkeep`.
- [ ] `run_pipeline.py` exit `0`; `model_sha256` và metric khớp `docs/30-research/pipeline.md` §5 (hoặc ghi rõ lệch).
- [ ] ONNX export parity PASS.
- [ ] `pytest` `436 passed` (không phụ thuộc artifact đã xoá).
- [ ] `check_docs_links.py` `broken=0`; `validate-project.py` `checks=15 fail=0`; `validate_demo_execution.py` `checks=13 fail=0`.
- [ ] `git status` chỉ có thay đổi mong muốn: thêm `scripts/tester/**`, sửa các `.md` theo §6, không xoá file tracked nào ngoài dự kiến.
- [ ] Không có artifact (~130 MB, `.sqlite`, `.onnx`) lọt vào Git; `docs/99-archive/**` không đổi.
- [ ] `PROGRESS.md` §71 đã append, số liệu là số thật.

## 9. Câu hỏi cần bạn chốt

- **Q1.** `github-demo/` (13 MB, gitignored, vật liệu audit open-source) — **giữ** (đề xuất của mình)
  hay dọn luôn?
- **Q2.** Nhãn cho hành vi tester trong `evidence.md`/trang bot sau khi dọn artifact (xem §6) —
  giữ `PASS` + ghi chú "đã dọn, chờ phase C", hay hạ xuống `NOT_RUN`/`PARTIAL` tới khi chạy lại?
- **Q3.** Có cần **runner script** `scripts/run_tester.ps1` ngay bây giờ (dùng lại ở phase C), hay chỉ
  giữ nguyên bộ `.ini`/`.set` như bạn đã nói?

## 10. Phần để builder tự quyết

- Cách đặt tên/đường dẫn trong `scripts/tester/` (giữ nguyên tên file `.ini`/`.set` gốc).
- Nội dung `scripts/tester/README.md` (dựa trên `docs/20-operations/strategy-tester.md` và
  `docs/PROGRESS.md` §40/§41/§56).
- Thứ tự xoá/sinh lại miễn là §8 đạt.
- Cờ cụ thể cho `run_pipeline.py`/`train_ml_baseline.py`/`export_onnx_model.py` lấy từ `--help` và
  `docs/30-research/{pipeline,ml-baseline,onnx}.md`.
