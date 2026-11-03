# Thiết kế: tái cấu trúc tài liệu `tm-fx` + bộ tài liệu bot cô đọng

- **Ngày:** 2026-11-03
- **Trạng thái:** APPROVED (chủ dự án duyệt 2026-11-03)
- **Phạm vi:** cấu trúc tài liệu, vị trí file, nội dung tài liệu mới. **Không** sửa logic EA, **không**
  sửa preset JSON, **không** chạy tester trong bước này.
- **Liên quan:** ADR 0001–0007, `docs/PROGRESS.md` §67–§69, commit `88df404` (lần di chuyển V1/V2/V3
  làm đứt toàn bộ link).

---

## 1. Vì sao (intent)

Chủ dự án nói: *"dự án loạn, không hiểu hướng đi và cấu trúc"*. Đây không phải vấn đề thẩm mỹ —
người đọc không xác định được **đọc gì trước, tin file nào, bot nào đang chạy được**. Hệ quả cụ thể:

1. Ba file cùng tự nhận là "điểm vào duy nhất", cả ba đều lỗi thời.
2. Ba bộ tài liệu chồng nhau (V1/V2/V3) với ba mức sự thật khác nhau, không rõ bộ nào còn hiệu lực.
3. 119/340 link tương đối trong `docs/` không resolve được — bấm vào là 404.
4. Chuẩn input của 5 EA demo khác nhau, nên không thể viết một trang cấu hình dùng chung.
5. Rác build/python ở thư mục gốc làm cây thư mục trông như bãi tạm.

Mục đích của lần việc này: **một điểm vào, một nguồn sự thật, một thứ tự đọc, một chuẩn input** —
để bước tiếp theo (chuẩn hóa input + suite chạy demo) có chỗ bám.

## 2. Mục tiêu / Không mục tiêu / Chống mục tiêu

**Mục tiêu**

- `docs/README.md` là điểm vào duy nhất; mọi tài liệu còn hiệu lực đều reachable từ đó trong ≤2 lần bấm.
- Mỗi bot demo có **một trang** (ý tưởng, input, preset, trạng thái bằng chứng), không rải rác.
- Một tài liệu chuẩn input (`10-bots/input-convention.md`) làm hợp đồng cho phase sau.
- V1/V2/V3 được **chưng cất** thành tài liệu mới cô đọng; bản gốc giữ nguyên trong `99-archive/`
  để tra cứu, đánh dấu read-only.
- 0 link chết trong vùng tài liệu hiện hành, và có cổng tự động để không tái phát.
- Thư mục gốc sạch: chỉ còn thứ thuộc về repo.
- Gate xanh lại: `validate-project.py` 0 fail, pytest 0 fail.

**Không mục tiêu**

- Không đổi hành vi EA, không đổi magic number, không đổi preset JSON.
- Không viết lại lịch sử `PROGRESS.md`.
- Không xóa kiến thức lịch sử (git history + `99-archive/` giữ).
- Không xây suite chạy demo tự động (đó là phase C, plan riêng).
- Không dịch lại tài liệu sang tiếng Anh.

**Chống mục tiêu** (dù kỹ thuật đúng vẫn tính là thất bại)

- Tạo thêm một "bộ tài liệu v4" nữa để rồi lại có 4 bộ chồng nhau.
- Di chuyển file nhưng để lại link chết, hoặc "sửa" bằng cách trỏ tất cả về `99-archive/`.
- Chưng cất thành tài liệu mới nhưng mất bằng chứng/trạng thái (`NOT_RUN`, `UNPROVEN`…).
- Làm gate xanh bằng cách tắt check thay vì sửa nguyên nhân.

## 3. Ràng buộc

Từ `AGENTS.md` và các ADR, áp dụng nguyên trạng:

- Chỉ demo / Strategy Tester; real/live bị cấm. Không credential, không login automation.
- Mọi lệnh đi qua `ExecBroker`; SL/TP bắt buộc; kill switch; magic duy nhất.
- Preset phải khớp **chính xác** tên `input` trong EA.
- Nhãn trạng thái `DONE` / `PASS` / `PARTIAL` / `NOT_RUN` / `BLOCKED` / `UNPROVEN` là hợp đồng,
  không được nâng cấp khi chưa có bằng chứng.
- Mỗi bước làm việc phải ghi vào `docs/PROGRESS.md`.
- Tài liệu tiếng Việt, giữ token kỹ thuật tiếng Anh.

Ràng buộc kỹ thuật phát hiện khi khảo sát:

- `scripts/validate-project.py` hard-code 18 đường dẫn tài liệu trong `REQUIRED_FILES` (cộng `README.md` gốc).
- `scripts/validate_demo_execution.py` hard-code 4 đường dẫn (`ADR`, `ADR_0003`, `ADR_0007`, `GUIDE`).
- **8 script khác cũng hard-code đường dẫn tài liệu** và sẽ hỏng âm thầm sau khi di chuyển:
  `validate_pineport.py` (4), `validate_longkaco.py` (3), `validate_pamtf.py` (3),
  `validate_tmfz.py` (3), `validate_tmind2.py` (2), `validate_tmxau2.py` (2),
  `package_pineport.ps1` (24), `deploy_pineport.ps1` (1, chỉ là dòng hướng dẫn in ra).
  `compare_pine_exports.py` và `package-source.ps1` chỉ nhắc trong docstring, không phải đường dẫn thật.
- Hai pytest test gọi hai validator trên, nên di chuyển tài liệu mà không cập nhật = đỏ gate.
- `validate-project.py` chỉ quét `mt5/`, nên file IR V3 nằm ngoài `mt5/` sẽ không còn bị bắt.
- Working tree đang bẩn: 11 file tracked bị sửa + 9 mục untracked, trong đó có ADR 0007 và
  `WonderwhalesDemoEA.mq5` mà validator coi là bắt buộc. `git mv` không chạy được trên file untracked,
  nên phải có bước 0 commit baseline trước khi di chuyển.

## 4. Hiện trạng đo được (2026-11-03)

| Hạng mục | Số đo |
|---|---|
| File trong `docs/` | 139 file / 2.1 MB |
| Trong đó là 3 pack V1/V2/V3 | 95 file (V1 46, V2 20, V3 29) |
| Tài liệu còn hiệu lực (ngoài 3 pack) | 44 file |
| Link tương đối đã kiểm | 340 |
| Link chết | **119** — 40 `archive/*`, 36 `v2/*`, 31 `file:///docs/...`, 12 `../../tm-trading` |
| EA demo gửi lệnh được | 5 (PA 25002001, Grid 25004001, DCA 25005001, IR 25006001, WW 25007001) |
| EA WIP làm đỏ gate | 1 (`mt5/Experts/InfiniteRunnerXAUV3DemoEA.mq5`, 6 dòng `AccountInfo*`) |
| Gate | `validate_demo_execution` 13/0 PASS · `validate-project` 14/1 FAIL · pytest 428 pass / 2 fail |
| Rác gốc | `reportsbuild-allsuite` (30 log), `pip-metadata-*`, `pip-unpack-*`, `pytest-of-tuanmjnh` (7.7 MB), `.pytest_cache`, `node_modules` + `package.json` + `pnpm-lock.yaml`, `build_test.log` |

## 5. Các hướng đã cân nhắc

**A — Chỉ sửa docs tối thiểu.** Viết lại 3 file entry, sửa 119 link, archive V1/V2/V3. Rẻ, nhanh,
nhưng giữ nguyên cấu trúc phẳng hiện tại: người đọc vẫn phải tự suy ra thứ tự đọc, và chuẩn input
vẫn không có chỗ đứng.

**B — Tái cấu trúc theo mục đích, một nguồn sự thật (đã chọn).** Chia `docs/` thành các tầng theo
mục đích đọc, chưng cất V1/V2/V3 thành tài liệu mới, thêm chuẩn input, dọn rác gốc, cô lập IR V3.
Không chạm logic EA. Đổi lại: di chuyển ~44 file và phải cập nhật đường dẫn trong 8 script.

**C — B + gộp thành suite EA chạy được.** Thêm tách `mt5/Experts/demo|lab`, `scripts/demo.ps1`,
sinh `.set` từ JSON, chuẩn hóa input **kèm sửa code 5 EA**. Đây là đích cuối, nhưng trộn hai loại
rủi ro (tài liệu + hành vi EA) vào một lần thay đổi.

**Chủ dự án chọn B**, kèm hai quyết định: chưng cất V1/V2/V3 thành bản mới thay vì chỉ archive, và
cô lập IR V3 ra ngoài vùng build. Lý do B thắng: nó tạo ra cấu trúc mà phase C có thể bám vào, mà
không đụng tới thứ đang chạy được.

### 5.1 Quyết định con đã chốt với chủ dự án

1. **Chưng cất, không chỉ archive.** V1/V2/V3 được đọc để rút ra nội dung còn đúng, viết lại thành
   tài liệu ngắn; bản gốc vẫn giữ trong `99-archive/` (read-only).
2. **IR V3 ra khỏi vùng build.** Chuyển `mt5/Experts/InfiniteRunnerXAUV3DemoEA.mq5` sang
   `archive/wip/2026-11-03_InfiniteRunnerXAUV3/` (ngoài `mt5/`), gate xanh lại; phát triển tiếp
   sau mà không chặn CI.

### 5.2 Quyết định kỹ thuật của tôi (ghi rõ để chủ dự án kiểm)

| # | Quyết định | Lý do |
|---|---|---|
| D1 | Giữ `docs/README.md` làm điểm vào duy nhất | Validator đã yêu cầu; đổi tên chỉ tạo thêm link chết |
| D2 | Giữ `docs/PROGRESS.md` ở gốc `docs/`, không đưa vào `00-start/` | Đây là log append-only 251 KB, không phải tài liệu đọc; validator cũng yêu cầu đường dẫn này |
| D3 | Dùng tiền tố số `00-`…`99-` cho thư mục | Thứ tự đọc hiện ra ngay trong cây thư mục, đúng vấn đề "không biết đọc gì trước" |
| D4 | Mỗi thư mục tầng có `README.md` ngắn (≤30 dòng) làm mục lục cục bộ | Giảm phụ thuộc vào một file entry khổng lồ |
| D5 | `configs/demo/*.json` là nguồn sự thật của preset; `.set` là dẫn xuất | Đã đúng như vậy trong code; tài liệu chỉ cần nói ra |
| D6 | Thêm `scripts/check_docs_links.py` và gọi nó từ `validate-project.py` | Chặn tái phát 119 link chết; pytest sẽ tự chạy nó |
| D7 | Thêm ADR 0008 ghi quyết định kiến trúc thông tin tài liệu | Ngăn lần sau lại sinh ra "pack v4" |
| D8 | `99-archive/` và `PROGRESS.md` được miễn kiểm link | Sửa link trong log lịch sử là viết lại lịch sử; archive là bản gốc bất biến |

### 5.3 Câu hỏi builder nêu và cách chốt

Một builder độc lập đã đọc bản DRAFT này và nêu 8 điểm phải đoán. Dưới đây là cách chốt; **cột "ai
quyết"** cho biết chỗ nào chủ dự án nên kiểm khi đọc.

| # | Câu hỏi | Chốt | Ai quyết |
|---|---|---|---|
| Q1 | Baseline commit: bắt đầu từ working tree hay `HEAD`? | **Thêm bước 0**: commit toàn bộ việc đang dở (WW bot, ADR 0007, validator, PROGRESS, preset IR) thành baseline, **trừ** file IR V3 (đi thẳng vào bước cô lập). Lý do: `HEAD` không tự nhất quán (thiếu ADR 0007 + preset WW), `git mv` không chạy trên file untracked, và revert cần baseline sạch | Tôi |
| Q2 | `README.md` gốc có trong phạm vi? | **Có.** Viết lại thành trang dẫn ngắn (≤60 dòng): 1 đoạn mô tả, bảng 5 bot demo, link `docs/README.md`, các con số đúng. Không nhồi lại nội dung roadmap | Tôi |
| Q3 | Bảng input trong trang bot dùng tên hiện tại hay tên chuẩn §9? | **Tên thật đang chạy** + cột `Tên chuẩn (phase C)` + bảng gap trong `input-convention.md`. Tài liệu phải cấu hình được **hôm nay**; chuẩn §9 là đích, không phải hiện trạng | Tôi |
| Q4 | Link trỏ ra ngoài repo tính là chết? | **Miễn, nhưng phải khai báo.** Checker bỏ qua target ngoài repo, đếm riêng vào dòng `external=N`, không tính fail. Link `file:///docs/...` (sai định dạng) → đổi thành đường dẫn tương đối. Link `file:///D:/...` và `../../tm-trading/...` → đổi thành câu trích dẫn văn bản (không phải link). Checker **không** kiểm anchor ở v1 | Tôi |
| Q5 | Link cũ `v2/*`, `archive/v1/*` trỏ về đâu? | Luật: **nội dung đã chưng cất → trang mới; bằng chứng gốc/prompt lịch sử → `99-archive/`.** `LINK_MAP.md` phải phủ cả tên cũ (`v2/`, `archive/v1/`) lẫn tên hiện tại (`MT5_EA_Lab_V2/`). Bảng ánh xạ cụ thể ở §7.1 | Tôi |
| Q6 | Phạm vi sửa path: 2 validator hay cả 8 script? | **Cả 8 script** (6 validator indicator + `package_pineport.ps1` + `deploy_pineport.ps1`). Đây là cập nhật đường dẫn, không phải sửa logic; bỏ sót thì gate vẫn xanh nhưng script chết âm thầm | Tôi |
| Q7 | Chuẩn nhãn trạng thái là 6 hay 9? | **Giữ đủ 9**, chia 6 nhãn hợp đồng (`DONE/PASS/PARTIAL/NOT_RUN/BLOCKED/UNPROVEN`) + 3 nhãn phụ (`FAIL`, `BLOCKED_PENDING_ADR`, `READY_FOR_MANUAL_VALIDATION`). Không đổi nhãn nào; glossary ghi rõ nhãn nào là hợp đồng | Tôi |
| Q8 | `10-bots/README.md` liệt kê bot nào? | **15 EA**: 5 demo + 10 lab (`DCALabEA`, `GridLabEA`, `LabOnnxInference`, `LabSignalEA`, `PATrendRiderXAUv1SimEA`, `PineMultiSignalLabEA`, `PinePlanSimEA`, `PineSignalLabEA`, `RunnerTrailingLabEA`, `WonderwhalesSimEA`). Cột `kind` phân biệt `demo / sim / signal / inference`; bot lab ghi magic `N/A`, preset trỏ `configs/sim/*.json` nếu có, ngược lại `N/A` | Tôi |

## 6. Cây tài liệu đích

Ngoài `docs/`: `README.md` ở gốc repo được viết lại thành trang dẫn ngắn (≤60 dòng) — mô tả repo
bằng 1 đoạn, bảng 5 bot demo, link tới `docs/README.md`. Nó không còn tự nhận là "điểm vào duy nhất"
và không chứa roadmap.

```
docs/
├─ README.md                     # ĐIỂM VÀO DUY NHẤT (viết lại)
├─ PROGRESS.md                   # log append-only (giữ nguyên vị trí)
├─ superpowers/specs/            # tài liệu quy trình (không nằm trong luồng đọc)
├─ 00-start/
│  ├─ README.md
│  ├─ roadmap.md                 # viết lại từ MASTER_ROADMAP + V2/ROADMAP
│  ├─ first-run.md               # từ guides/beginner-first-run.md
│  └─ glossary.md                # MỚI: thuật ngữ + nhãn trạng thái
├─ 10-bots/
│  ├─ README.md                  # MỚI: danh mục 15 EA (5 demo + 10 lab), magic, preset, trạng thái
│  ├─ input-convention.md        # MỚI: chuẩn input dùng chung
│  ├─ ea-anatomy.md              # từ guides/ea-anatomy-and-ai.md (phần chung)
│  ├─ pa-trendrider.md           # MỚI: chưng cất V1 spec + V2 strategy doc
│  ├─ grid.md                    # MỚI: chưng cất V2/STRATEGIES/GRID_EA.md
│  ├─ dca.md                     # MỚI: chưng cất V2/STRATEGIES/DCA_EA.md
│  ├─ infinite-runner.md         # MỚI: chưng cất V2 upgrade pack + ADR 0005
│  └─ wonderwhales.md            # MỚI: từ indicators/wonderwhales.md + ADR 0007
├─ 20-operations/
│  ├─ README.md
│  ├─ install.md                 # từ guides/install-and-test.md
│  ├─ strategy-tester.md         # từ guides/strategy-tester.md
│  ├─ demo-execution.md          # từ guides/demo-execution.md (validator yêu cầu)
│  ├─ toolchain.md               # từ guides/toolchain.md
│  ├─ troubleshooting.md         # MỚI: chưng cất V2/TROUBLESHOOTING + V3/ZERO_TRADE_DIAGNOSTICS
│  ├─ presets.md                 # viết lại từ configurations/README.md
│  ├─ presets/                   # 4 file .set hiện có
│  └─ evidence.md                # MỚI: chưng cất V2/EVIDENCE + TEST_REPORT + V3/IMPLEMENTATION_STATUS
├─ 30-research/
│  ├─ README.md
│  ├─ architecture.md            # từ reference/
│  ├─ simulation.md              # từ reference/
│  ├─ risk.md                    # từ reference/
│  ├─ testing.md                 # từ reference/
│  ├─ release.md                 # từ reference/
│  ├─ parity.md                  # từ reference/
│  ├─ bounded-basket.md          # từ reference/
│  ├─ trailing-stop.md           # từ reference/
│  ├─ strategy-signal-spec.md    # từ reference/
│  ├─ data-dictionary.md         # từ reference/
│  ├─ pipeline.md                # từ reference/
│  ├─ ml-baseline.md             # từ reference/
│  ├─ onnx.md                    # từ reference/
│  ├─ experiment-store.md        # từ reference/
│  ├─ ai-integration.md          # MỚI: tách từ ea-anatomy-and-ai.md mục 11
│  ├─ open-source-research.md    # MỚI: chưng cất V3/GITHUB_RESEARCH_PROCESS + V2/GITHUB_AUDIT
│  └─ indicators/                # 8 file indicator (giữ nguyên nội dung)
├─ 90-decisions/
│  ├─ README.md                  # MỚI: mục lục ADR + trạng thái
│  ├─ 0001…0007                  # giữ nguyên
│  └─ 0008-docs-information-architecture.md   # MỚI
└─ 99-archive/
   ├─ README.md                  # MỚI: read-only, vì sao giữ
   ├─ LINK_MAP.md                # MỚI: đường dẫn cũ → mới
   ├─ MT5_EA_Lab_V1/             # git mv nguyên vẹn (46 file)
   ├─ MT5_EA_Lab_V2/             # git mv nguyên vẹn (20 file)
   └─ MT5_EA_Lab_V3/             # git mv nguyên vẹn (29 file)
```

**Quy tắc đọc:** `docs/README.md` → `00-start/` → `10-bots/` → `20-operations/` khi muốn chạy →
`30-research/` khi muốn hiểu sâu → `90-decisions/` khi cần biết vì sao → `99-archive/` chỉ để tra cứu.

## 7. Bản đồ di chuyển (old → new)

Di chuyển bằng `git mv` để giữ lịch sử. Bảng dưới là hợp đồng cho builder; mọi file không có trong
bảng thì **không được di chuyển**.

| Cũ | Mới |
|---|---|
| `docs/MASTER_ROADMAP.md` | `docs/00-start/roadmap.md` (viết lại) |
| `docs/guides/beginner-first-run.md` | `docs/00-start/first-run.md` |
| `docs/guides/ea-anatomy-and-ai.md` | tách: `docs/10-bots/ea-anatomy.md` + `docs/30-research/ai-integration.md` |
| `docs/guides/install-and-test.md` | `docs/20-operations/install.md` |
| `docs/guides/strategy-tester.md` | `docs/20-operations/strategy-tester.md` |
| `docs/guides/demo-execution.md` | `docs/20-operations/demo-execution.md` |
| `docs/guides/toolchain.md` | `docs/20-operations/toolchain.md` |
| `docs/configurations/README.md` | `docs/20-operations/presets.md` (viết lại) |
| `docs/configurations/*.set` (4) | `docs/20-operations/presets/*.set` |
| `docs/decisions/0001…0007` | `docs/90-decisions/` (giữ tên) |
| `docs/reference/*.md` (14) | `docs/30-research/` (giữ tên) |
| `docs/indicators/**` (8) | `docs/30-research/indicators/` (giữ tên) |
| `docs/MT5_EA_Lab_V1/` | `docs/99-archive/MT5_EA_Lab_V1/` |
| `docs/MT5_EA_Lab_V2/` | `docs/99-archive/MT5_EA_Lab_V2/` |
| `docs/MT5_EA_Lab_V3/` | `docs/99-archive/MT5_EA_Lab_V3/` |

`README.md` ở gốc repo **không di chuyển**, chỉ viết lại tại chỗ.

Ghi chú: `docs/reference/parity.md` và `docs/indicators/parity.md` là hai tài liệu khác nhau. Bản
indicators nằm trong `indicators/` nên không xung đột tên.

### 7.1 Luật cho link cũ không có trong bảng §7

Các link `v2/*` và `archive/v1/*` trỏ tới thư mục **chưa từng tồn tại** trong cây hiện tại (di sản
của lần đổi tên `v2/` → `MT5_EA_Lab_V2/`). Không thể map máy móc; builder dùng bảng sau, và
`LINK_MAP.md` phải phủ cả tên cũ lẫn tên hiện tại.

| Link cũ | Trỏ về |
|---|---|
| `v2/README.md`, `v2/ROADMAP.md` | `00-start/roadmap.md` |
| `v2/RISK_MODEL.md` | `30-research/risk.md` |
| `v2/EXECUTION_AND_SAFETY.md` | `20-operations/demo-execution.md` |
| `v2/CONFIGURATION.md` | `20-operations/presets.md` |
| `v2/TROUBLESHOOTING.md` | `20-operations/troubleshooting.md` |
| `v2/EVIDENCE.md`, `v2/TEST_REPORT.md` | `20-operations/evidence.md` |
| `v2/STRATEGIES/PA_TRENDRIDER_XAU_V1.md` | `10-bots/pa-trendrider.md` |
| `v2/STRATEGIES/GRID_EA.md` | `10-bots/grid.md` |
| `v2/STRATEGIES/DCA_EA.md` | `10-bots/dca.md` |
| `v2/STRATEGIES/InfiniteRunner_XAU_Upgrade_Pack/*` | `10-bots/infinite-runner.md` |
| `v2/GITHUB_AUDIT.md` | `30-research/open-source-research.md` |
| `v2/BACKLOG_AI.md`, `v2/DECISIONS_REQUIRED.md`, `v2/PROMPT_AI_IMPLEMENT.md`, `v2/ENVIRONMENT.md` | `99-archive/MT5_EA_Lab_V2/` (kế hoạch cũ, không chưng cất) |
| `archive/v1/*`, `archive/planning-inputs/*` | `99-archive/MT5_EA_Lab_V1/` (bản gốc lịch sử) |
| `file:///docs/...` | đổi thành đường dẫn tương đối tới file mới tương ứng |
| `file:///D:/...`, `../../tm-trading/...` | câu trích dẫn văn bản, không phải link |

## 8. Đặc tả bộ tài liệu cô đọng

Nguyên tắc chưng cất: **giữ kết luận + bằng chứng + giới hạn; bỏ kế hoạch đã chết, prompt AI cũ,
roadmap theo phase đã xong.** Mỗi trang mới 150–400 dòng, riêng trang bot ≤200 dòng.

| Tài liệu mới | Nguồn | Nội dung bắt buộc |
|---|---|---|
| `00-start/roadmap.md` | `MASTER_ROADMAP.md`, `V2/ROADMAP.md`, `V3/ROADMAP_MT5_EA_LAB_V3.md` | Trạng thái hiện tại theo từng mảng; 3 phase kế tiếp (docs → input standardization → suite demo); bảng "cái gì đã xong / đang dở / chưa làm" |
| `00-start/glossary.md` | mới + ADR | 25–35 thuật ngữ: EA, magic, preset, `.set`, gate, ADR, `ExecBroker`, `NOT_RUN`…`UNPROVEN`, R-multiple, basket |
| `10-bots/README.md` | mới | Bảng **15 EA** (5 demo + 10 lab): file, `kind`, magic, preset, trang chi tiết, trạng thái bằng chứng |
| `10-bots/input-convention.md` | mới (xem §9) | Chuẩn input + bảng khác biệt theo loại bot + ánh xạ preset + **bảng gap hiện tại → chuẩn** |
| `10-bots/pa-trendrider.md` | `V1/PA_..._Specification_Vietnamese.md`, `V2/STRATEGIES/PA_TRENDRIDER_XAU_V1.md` | Ý tưởng, đa khung H1/M15/M5, luật vào/ra, bảng input, preset, bằng chứng, giới hạn |
| `10-bots/grid.md` | `V2/STRATEGIES/GRID_EA.md` | Luật lưới có chặn, trần level/volume, basket SL/TP, bảng input, preset |
| `10-bots/dca.md` | `V2/STRATEGIES/DCA_EA.md` | DCA theo thời gian vs averaging theo biến động, max adds, basket caps |
| `10-bots/infinite-runner.md` | `V2/STRATEGIES/InfiniteRunner_XAU_Upgrade_Pack/*`, ADR 0005 | Legacy EMA vs direction mode, trailing, safety TP xa, quirk đã biết |
| `10-bots/wonderwhales.md` | `docs/indicators/wonderwhales.md`, ADR 0007 | PSAR single-position, guard, kết quả tester −625.72 `UNPROVEN` |
| `20-operations/troubleshooting.md` | `V2/TROUBLESHOOTING.md`, `V3/ZERO_TRADE_DIAGNOSTICS.md`, `V3/NO_TRADE_DIAGNOSIS_TEMPLATE.md`, PROGRESS §68 | Cây quyết định "0 trade"; 7 nguyên nhân đã gặp thật, gồm bug `MQL_TESTER=0` headless và việc EA nhận vị thế lạc |
| `20-operations/evidence.md` | `V2/EVIDENCE.md`, `V2/TEST_REPORT.md`, `V3/IMPLEMENTATION_STATUS.md` | Định nghĩa **9 nhãn** (6 hợp đồng + 3 phụ); bảng bằng chứng theo tuyên bố; bằng chứng bị cấm dùng |
| `20-operations/presets.md` | `docs/configurations/README.md` | JSON là nguồn sự thật; `.set` là dẫn xuất; quy tắc đổi preset an toàn; magic table |
| `30-research/ai-integration.md` | `ea-anatomy-and-ai.md` mục 11 | 3 mức tích hợp AI, pipeline B, bảng cấu hình phải khớp tuyệt đối, công thức ghép an toàn |
| `30-research/open-source-research.md` | `V3/GITHUB_RESEARCH_PROCESS.md`, `V2/GITHUB_AUDIT.md` | Quy trình tìm repo tham chiếu; tiêu chí đánh giá; bài học từ audit |
| `README.md` (gốc repo) | viết lại | 1 đoạn mô tả, bảng 5 bot demo, link `docs/README.md`, không roadmap |

Mọi bảng input trong trang bot dùng **tên thật đang chạy** và có thêm cột `Tên chuẩn (phase C)`.
Bảng gap đầy đủ nằm trong `input-convention.md`; trang bot không được in tên input chưa tồn tại
trong code.

Bị loại bỏ khỏi luồng đọc (chỉ còn trong `99-archive/`): prompt AI cũ, roadmap theo phase đã xong,
`V3/inputs/legacy_sources/*` (bản copy EA), script/build pack của V3, `PROGRESS_TEMPLATE`,
`DECISIONS_REQUIRED` (đã được ADR thay thế).

## 9. Chuẩn input dùng chung (hợp đồng cho phase C)

Đây là **đặc tả**, không phải sửa code. Phase C sẽ áp dụng nó vào 5 EA.

**Thứ tự nhóm cố định (6 nhóm, đúng thứ tự này):**

| # | Group | Input bắt buộc |
|---|---|---|
| 1 | `01 Execution` | `InpEnableExecution`, `InpAllowedSymbols`, `InpMagicNumber`, `InpMaxSlippagePoints` |
| 2 | `02 Risk` | `InpRiskPercent`, `InpMaxPositions`, `InpCooldownMinutes`, `InpMaxDailyLossPct`, `InpMaxDrawdownPct`, `InpMaxConsecutiveLosses`, `InpMaxSpreadPoints`, `InpMaxExposure`, `InpHaltOnBreach` |
| 3 | `03 Stops` | SL/TP đặc thù theo loại bot (bảng dưới) |
| 4 | `04 Journal and state` | `InpEnableLog`, `InpLogFile`, `InpPersistState`, `InpStateFile`, `InpResetStateOnInit`, `InpDebug` |
| 5 | `05 Kill switch` | `InpKillSwitchFile`, `InpCloseOnKillSwitch` |
| 6 | `06 Strategy` | tham số riêng của bot, sub-group theo chủ đề |

**Quy tắc đặt tên**

- Tiền tố `Inp` + PascalCase; đơn vị nằm trong tên: `...Points`, `...Minutes`, `...Percent`, `...R`.
- Boolean đọc như mệnh đề: `InpEnableX`, `InpCloseOnKillSwitch`, `InpPersistState`.
- Tên file: `Inp<What>File`. Kill switch: `<BOT>_DEMO_STOP.txt`. Log/state: `<bot>_demo*.csv`.
- Không viết tắt ngoài `SL`, `TP`, `R`, `ATR`, `DCA`, `PSAR`.
- Tên input trong EA == key trong `configs/demo/*.json` (không bỏ `Inp`).

**SL/TP theo loại bot** (mọi loại đều bắt buộc có SL và TP thật, khác nhau ở *cách* đặt):

| Loại | SL | TP | Input đặc thù |
|---|---|---|---|
| `single_position` (PA, WW) | cấu trúc/ATR | `InpTakeProfitR` (bội số R) | `InpMaxPositions=1` |
| `runner_trailing` (IR) | cấu trúc hoặc fixed | TP an toàn xa `InpSafetyTpPoints` + trailing | `InpTrailStartPts`, `InpTrailDistancePts`, `InpTrailStepPts`, `InpBreakEvenTriggerR` |
| `bounded_grid` (Grid) | mỗi lệnh | basket TP | `InpMaxGridLevels`, `InpSpacingPoints`, `InpBasketTargetPoints`, `InpBasketStopPoints` |
| `bounded_dca` (DCA) | mỗi lệnh | basket TP | `InpMaxDcaAdds`, `InpDcaDistancePoints`, `InpBasketTargetPoints`, `InpBasketStopPoints` |

**Bất biến kiểm được bằng máy** — cột "hiện tại" cho biết validator đã ép hay chưa:

| Bất biến | Hiện tại | Phase C |
|---|---|---|
| `InpEnableExecution` mặc định `true` (ADR 0006) | Đã ép (cả 5 EA + preset) | Giữ |
| Magic duy nhất: probe 25002002, PA 25002001, Grid 25004001, DCA 25005001, IR 25006001, WW 25007001 | Đã ép | Giữ |
| Mọi EA có `InpKillSwitchFile` | Đã có ở cả 5 | Giữ |
| Mọi EA có `InpCloseOnKillSwitch` | **PA thiếu** | Thêm vào PA |
| Mọi EA có `InpRiskPercent` / `InpMaxPositions` / `InpCooldownMinutes` | **Grid/DCA thiếu** | Thêm, hoặc ghi rõ `N/A` có lý do trong trang bot |
| Preset JSON đủ key trùng tên input, không thừa/thiếu | Đã ép một phần | Ép đủ |

**Bảng gap hiện tại → chuẩn** (bắt buộc có trong `input-convention.md`):

| Vấn đề | Bot đang lệch | Chuẩn |
|---|---|---|
| Tên group | `Demo execution` (cả 5) | `01 Execution` |
| Tên group | `Journal` (Grid, DCA) vs `Journal and state` (PA, IR, WW) | `04 Journal and state` |
| Tên group | `RiskGuard` (Grid, DCA) vs `Risk` (IR, WW) | `02 Risk` |
| Tên group | `Exit` (Grid, DCA), `Stops and target` (WW) | `03 Stops` + `06 Strategy` |
| Kill switch tách khỏi Execution | Cả 5 EA đặt trong `Demo execution` | `05 Kill switch` |
| `InpCloseOnKillSwitch` | PA không có | Thêm, mặc định `true` |
| `InpRiskPercent` / `InpMaxPositions` / `InpCooldownMinutes` | Grid, DCA không có | Thêm (grid/DCA dùng `InpMaxPositions` = số level tối đa) |
| Tên TP/SL | `InpTakeProfitR` (PA, WW) vs `InpSafetyTpPoints` (IR) vs `InpBasketTargetPoints`/`InpBasketStopPoints` (Grid, DCA) | Giữ, nhưng khai báo theo loại bot ở bảng trên |
| Hậu tố đơn vị | IR dùng `Pts` (`InpTrailStartPts`, `InpTrailStepPts`) trong khi 4 EA kia dùng `Points` | Chuẩn hoá về `Points`; phase C đổi tên + cập nhật preset cùng lúc |
| `InpMaxDailyLossPct` | PA đang là `InpDailyLossLimitPct` | Đổi tên ở phase C |
| `InpMaxExposure` | IR và WW dùng `InpMaxLots` | Phase C thay bằng `InpMaxExposure` |

## 10. Dọn rác thư mục gốc

| Mục | Hành động | Ghi chú |
|---|---|---|
| `reportsbuild-allsuite/` | xóa | 30 log compile, tên bị gõ sai; log sinh lại được, `*.log` đã gitignore |
| `pip-metadata-6127bt5c/`, `pip-unpack-fo46zcow/` | xóa | rác pip |
| `pytest-of-tuanmjnh/` | xóa | 7.7 MB temp của pytest |
| `.pytest_cache/` | xóa | cache |
| `node_modules/`, `package.json`, `pnpm-lock.yaml` | xóa + thêm `node_modules/` vào `.gitignore` | không có code JS nào dùng |
| `build_test.log` | xóa | log build, đã gitignore |
| `reports/` (133.7 MB), `github-demo/` (13.2 MB) | **giữ** | đã gitignore; `reports/` là kho bằng chứng, `github-demo/` là vật liệu audit |

## 11. Cô lập IR V3

- Chuyển `mt5/Experts/InfiniteRunnerXAUV3DemoEA.mq5` → `archive/wip/2026-11-03_InfiniteRunnerXAUV3/`.
- Kèm một `README.md` trong thư mục đó: đây là WIP, **không** được build/deploy, lý do cô lập
  (6 dòng `AccountInfo*` vượt ranh giới `ExecBroker`), điều kiện để đưa trở lại.
- Không thêm vào `scripts/deploy_pineport.ps1` (hiện cũng chưa có).
- Kết quả kỳ vọng: `validate-project.py` trở lại `fail=0`; 2 pytest đang đỏ tự xanh.

## 12. Cơ chế di chuyển & kiểm chứng

Thứ tự bắt buộc (mỗi bước là một commit nhỏ, có thể rollback):

0. **Baseline:** commit toàn bộ việc đang dở (WW bot, ADR 0007, validator, `PROGRESS.md`, preset IR)
   thành một commit "baseline before docs reorg". Không commit `mt5/Experts/InfiniteRunnerXAUV3DemoEA.mq5`
   ở bước này — nó đi thẳng vào bước 1.
1. Cô lập IR V3 → chạy gate, xác nhận xanh trước khi động vào tài liệu.
2. Dọn rác gốc + cập nhật `.gitignore`.
3. `git mv` theo bảng §7 (một lần, không copy) — **chưa sửa nội dung**.
4. Cập nhật đường dẫn trong **8 script** (xem §3): `validate-project.py` (`REQUIRED_FILES`),
   `validate_demo_execution.py` (`ADR`, `ADR_0003`, `ADR_0007`, `GUIDE`), 6 validator indicator,
   `package_pineport.ps1`, và dòng hướng dẫn trong `deploy_pineport.ps1`.
5. Sinh `99-archive/LINK_MAP.md` từ bảng §7 + §7.1, rồi viết lại link trong toàn bộ tài liệu hiện
   hành (trừ `PROGRESS.md` và `99-archive/`).
6. Viết tài liệu mới theo §8 và §9; viết lại `docs/README.md`, `00-start/roadmap.md`, `README.md` gốc.
7. Thêm `scripts/check_docs_links.py`; gọi từ `validate-project.py`; miễn `PROGRESS.md` và `99-archive/`.
8. Thêm ADR 0008; thêm mục vào `docs/PROGRESS.md`.
9. Chạy toàn bộ cổng + kiểm tra thủ công.

**Kiểm chứng (định nghĩa hoàn thành)**

```powershell
.\.venv\Scripts\Activate.ps1
python scripts\check_docs_links.py     # broken=0, external=N (ngoài PROGRESS.md + 99-archive/)
python scripts\validate-project.py     # SUMMARY: checks=N fail=0
python scripts\validate_demo_execution.py  # SUMMARY: checks=13 fail=0
Get-ChildItem scripts\validate_*.py | Where-Object Name -match 'longkaco|pamtf|pineport|tmfz|tmind2|tmxau2' | ForEach-Object { python $_.FullName }
python -m pytest -q                    # 430 passed, 0 failed
git status --porcelain                 # không còn mục rác
```

Kiểm tra thủ công: từ `docs/README.md` bấm được tới 5 trang bot, 4 tài liệu vận hành, 8 ADR, và
`99-archive/README.md`; mỗi trang bot hiển thị đúng magic + preset + nhãn trạng thái.

## 13. Còn lại cho builder

Builder được tự quyết:

- Câu chữ cụ thể trong từng trang, miễn giữ đúng dữ kiện và nhãn trạng thái.
- Chia nhỏ `install.md`/`demo-execution.md` nếu thấy quá dài, miễn `demo-execution.md` giữ nguyên
  đường dẫn (validator đọc nó).
- Thứ tự commit trong khoảng 10 bước ở §12.
- Có thể gộp bước 5 và 6 nếu thấy link rewrite dễ hơn khi viết lại nội dung.

Builder **không** được:

- Sửa `input`/logic trong bất kỳ file `.mq5` nào (kể cả để "cho đẹp chuẩn mới").
- Sửa `configs/demo/*.json`.
- Xóa nội dung trong `99-archive/` hoặc viết lại link bên trong nó.
- Nâng nhãn trạng thái của bất kỳ bot nào, hoặc đổi bộ 9 nhãn đang dùng.
- Tắt/bỏ qua check trong validator để làm gate xanh.
- Biến link ngoài repo (`tm-trading`, ổ D:) thành link nội bộ giả; phải đổi thành câu trích dẫn.
- Đưa `InfiniteRunnerXAUV3DemoEA.mq5` trở lại `mt5/`.

## 14. Rollback

Mỗi bước là commit riêng. Nếu bước 5–6 hỏng, `git revert` commit đó là đủ: bước 3–4 chỉ là di
chuyển + cập nhật đường dẫn, nội dung chưa đổi. `99-archive/` là `git mv` nên luôn khôi phục được
nguyên trạng.
