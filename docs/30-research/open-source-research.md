# Nghiên cứu mã nguồn mở — quy trình, tiêu chí, bài học

> Ghi chú 2026-11-11: repo nay chỉ còn bot InfiniteRunner; các EA/indicator được nhắc trong tài liệu này là lịch sử.

Nguồn chưng cất: `99-archive/MT5_EA_Lab_V3/research/GITHUB_RESEARCH_PROCESS.md` (quy trình) và
`99-archive/MT5_EA_Lab_V2/GITHUB_AUDIT.md` (audit đã chạy thật, 2026-10-29). Bằng chứng gốc nằm
trong archive; trang này giữ phần còn hiệu lực để làm theo. Nguyên tắc gốc: nghiên cứu code để **giảm
thời gian làm**, không phải để có chiến lược mới — không copy cả một chiến lược chỉ vì nó có
screenshot hay claim hiệu năng.

## 1. Quy trình 5 bước tìm repo tham chiếu

Mục tiêu: mượn ý tưởng và cấu trúc cho những phần chưa quen — kiến trúc EA, symbol utilities, trade
wrapper, logging, tester automation, strategy state, grid/basket accounting, test harness. Việc tái
sử dụng chỉ xảy ra sau khi audit license + nguồn xong, không trước.

1. **Search — dựng shortlist.** Tìm repo theo chủ đề cụ thể (MQL5 grid, DCA, trailing, bridge
   Python–MT5…). Chốt shortlist nhỏ, mỗi ứng viên ghi rõ định đọc phần nào. Shortlist là **nguồn gợi
   ý, không phải phê duyệt**: luôn kiểm tra lại trạng thái sống của repo tại thời điểm làm.
2. **Đọc license trước khi đọc code.** Mở `LICENSE`/`LICENSE.md`, ghi SPDX identifier và dòng đầu
   của license. Thiếu license = không copy, không redistribute; vẫn được đọc làm tham chiếu khái niệm.
   GPL-3.0 đặt nghĩa vụ lên bản phái sinh, nên chỉ cân nhắc vượt `REFERENCE_ONLY` sau một review
   tương thích license tường minh của chủ dự án.
3. **Đọc kiến trúc — đúng phần sẽ mượn.** Đọc source những điểm sẽ tái sử dụng: `CTrade`/`OrderSend`
   và code modify/close, xử lý magic, hedging/netting, chuẩn hóa tick-size và volume, stop/freeze
   check, retcode, idempotency, khôi phục state, kill switch. Ghi rõ repo là MQL4 hay MQL5 — nhiều
   repo "MT5" thực chất là MT4 hoặc Python.
4. **Chạy thử trong môi trường tách biệt.** Build/test của họ phải chạy được; kiểm tra dependency,
   script, binary `.ex5`, request mạng, credential, code obfuscate. Claim hiệu năng chỉ được tính khi
   tái lập độc lập trên dataset và config ghi nhận được — số star hay ảnh chụp không phải bằng chứng.
5. **Ghi quyết định.** Kết thúc mỗi audit là một quyết định `USE`, `REFERENCE_ONLY` hay `REJECT` kèm
   lý do. Hồ sơ audit tối thiểu cho từng repo:

   - URL canonical, ngày giờ audit, default branch, **commit SHA chính xác** của HEAD đã đọc;
   - ngày commit gần nhất và hoạt động maintain gần đây;
   - toàn văn file LICENSE + SPDX identifier (hoặc ghi rõ "không có");
   - file nguồn đã đọc, đặc biệt phần gửi/sửa/đóng lệnh và risk sizing;
   - tương thích MQL4/MQL5/Python và các dependency, script, binary, request mạng, credential,
     dấu hiệu obfuscate;
   - build/test workflow, độ phủ test, nguồn dữ liệu, khả năng tái lập;
   - các file đang cân nhắc dùng + tương thích license/attribution;
   - quyết định cuối cùng `USE` / `REFERENCE_ONLY` / `REJECT` + lý do.

   Quyết định nằm trong ADR/PROGRESS của repo này — không nằm trong chat, không nằm trong đầu.

### Ví dụ áp dụng: `santiquiroz/leviathan`

Một vòng audit hoàn chỉnh trên một repo của shortlist V2, ứng viên cho mảng "EA MQL5 + parity
backtest Python" — trùng đúng mối quan tâm parity của lab này:

- **Bước 1 (search):** vào shortlist với định nghĩa rõ phần cần đọc: cách tổ chức EA và phía Python
  backtest, không phải chiến lược của nó.
- **Bước 2 (license):** `LICENSE` tồn tại, SPDX = MIT, dòng đầu "MIT License / Copyright (c) 2026
  Santiago Quiroz" — tương thích, được đọc tiếp.
- **Bước 3 (kiến trúc):** phần cần đối chiếu là cấu trúc module EA và đường parity số; chưa đọc sâu
  vì chưa có nhu cầu `USE`.
- **Bước 4 (chạy thử):** `NOT_RUN` — hợp lý, vì chưa dòng nào được dùng; bước này chỉ bắt buộc khi
  đổi sang `USE`.
- **Bước 5 (quyết định):** `REFERENCE_ONLY`, ghi kèm branch `master` và HEAD SHA tại thời điểm audit
  (`4462796…`). SHA này là mốc; nếu repo có commit mới, audit phải chạy lại trước khi thay đổi quyết
  định.

Điểm mấu chốt: kết quả bước 4 là `NOT_RUN` **một cách có chủ đích** — quy trình không bắt buộc đọc
sâu và chạy thử mọi shortlist, chỉ bắt buộc khi một repo thực sự vào đường dùng.

## 2. Tiêu chí chấm một repo

Mặc định của mọi repo là `REFERENCE_ONLY`. Chỉ chủ dự án được đổi một repo sang `USE`, và chỉ khi
đạt đủ cả năm tiêu chí dưới đây; khi đó toàn bộ audit phải chạy lại tại đúng commit SHA đã ghi.

| # | Tiêu chí | Cái được kiểm tra |
|---|---|---|
| 1 | **License rõ ràng** | File license tồn tại, SPDX xác định, tương thích với kế hoạch license của repo này. Thiếu license là `REJECT` — không ngoại lệ. |
| 2 | **Còn maintain** | Có commit gần đây trên default branch. Repo xác chỉ dùng làm tham chiếu khái niệm; API MQL5 và quy tắc broker đổi nhanh nên code chết không được tin. |
| 3 | **Không look-ahead/repaint** | Điểm quyết định tính trên nến đóng, không đọc giá tương lai. Với indicator, làm audit buffer như các trang indicator trước đây (đã gỡ cùng PinePort). |
| 4 | **Có test** | Build/test workflow chạy được trong môi trường tách biệt, dataset tái lập được. Không test = claim không xác minh được = không `USE`. |
| 5 | **Kích thước đọc được** | Ưu tiên utility pattern nhỏ đọc hết trong một phiên; mượn pattern thay vì import cả EA. File càng lớn, càng khó audit hết đường gửi lệnh. |

Bốn thứ **không** phải tiêu chí nhưng hay gây nhiễu: số star, ảnh chụp màn hình, claim lợi nhuận,
độ mới của README. Bỏ qua cả bốn trừ khi tái lập được độc lập.

### Quy tắc quyết định

| Tình huống | Quyết định |
|---|---|
| Không có file license (API/URL 404) | `REJECT` ngay, không đọc tiếp source. |
| Có license, chưa đọc source, chưa có nhu cầu dùng | `REFERENCE_ONLY` — trạng thái mặc định của mọi shortlist. |
| Có license GPL và kế hoạch license của repo không phải GPL | `REFERENCE_ONLY`; muốn vượt phải có review tương thích tường minh của chủ dự án. |
| Đủ 5 tiêu chí + chủ dự án phê duyệt | `USE` — audit nguồn + build/test + attribution chạy lại tại đúng SHA trước khi copy dòng nào. |
| Repo có commit mới trên default branch so với SHA đã audit | Audit hết giá trị; chạy lại trước khi giữ nguyên hay thay đổi quyết định. |

## 3. Bài học từ audit V2

Audit V2 (2026-10-29) đã xác minh metadata — default branch, HEAD SHA, license file, SPDX — cho cả 7
repo trong shortlist. Kết quả: 6 `REFERENCE_ONLY`, 1 `REJECT`, và **0 dòng code ngoài được copy**.
Những bài học rút ra:

1. **Đọc license trước tiết kiệm đúng kiểu việc cần thiết.** `AlexKu111/GridBot-Mql5` không có file
   license (GitHub API trả 404) nên bị `REJECT` ngay ở bước 2 — không tốn một phút đọc source. Nếu
   quy trình là "đọc code trước, hỏi license sau", repo này đã ngốn thời gian vô ích.
2. **GPL-3.0 chặn cả ý định copy nhỏ.** `EA31337/EA31337` là kiến trúc EA phổ biến nhất trong
   shortlist, nhưng GPL đặt nghĩa vụ lên bản phái sinh và kế hoạch license hiện tại của repo này
   không phải GPL. Kết luận: chỉ đọc để tham khảo ý tưởng; mọi hình thức copy phải đi qua review
   tương thích tường minh của chủ dự án trước.
3. **Mốc tham chiếu là commit SHA, không phải `pushed_at`.** Với `EA31337/EA31337`, `pushed_at` của
   API mới hơn HEAD của `master` vì hoạt động diễn ra trên branch khác. Mỗi lần SHA mặc định đổi,
   audit cũ hết giá trị và phải chạy lại — bảng SHA trong audit là ảnh chụp tại một thời điểm, không
   phải sự thật vĩnh viễn.
4. **Metadata ≠ audit nguồn; đừng mở rộng phạm vi vô ích.** Audit V2 dừng ở mức metadata (7/7 có
   SHA + license); đọc source và chạy build/test của họ là `NOT_RUN` — và hợp lý, vì không dòng code
   nào được dùng. Phạm vi audit phải theo nhu cầu dùng thật: chỉ khi một repo được đổi sang `USE`
   thì checklist nguồn mới trở thành bắt buộc.
5. **Cùng chủ đề ≠ thay thế được nguồn sự thật.** `edisonq/Golden-Structure-V1` cùng mảng
   trend/structure nhưng **không phải** PATrendRider; không repo ngoài nào được thay thế
   `PATrendRiderXAUv1` hay các nguồn đã chọn, và mọi code gửi lệnh vẫn phải nằm trong các file
   `Exec/*` được ADR cho phép — copy một EA khác vào là vi phạm gate tĩnh.

Điều audit V2 chứng minh và không chứng minh: nó chứng minh *trạng thái metadata và license tại một
commit SHA*; nó không chứng minh code chạy đúng, không chứng minh hiệu năng, và không cho phép dùng
code dưới bất kỳ hình thức nào khi chưa có quyết định `USE`.

### Phương pháp tái lập một audit metadata

Audit V2 là audit metadata — không cần token, chỉ cần Internet (giới hạn 60 request/giờ/IP). Hai cú
gọi API cho mỗi repo: `GET /repos/{owner}/{repo}` lấy default branch, rồi
`GET /repos/{owner}/{repo}/commits/{branch}` lấy HEAD SHA; license đối chiếu bằng
`GET /repos/{owner}/{repo}/license` và đọc trực tiếp file license trên
`raw.githubusercontent.com`. Kết quả ghi thành bảng với các cột bắt buộc: repo, branch, HEAD SHA,
ngày HEAD, license file, SPDX, dòng đầu license, quyết định.

Hai quy tắc khi tái lập:

1. **Ghi cả kết quả âm.** License file không tồn tại phải hiện trong bảng là "không có" (SPDX =
   none), không được bỏ dòng — một `REJECT` im lặng sẽ bị hỏi lại.
2. **Không ghi đè audit cũ.** Bảng mới là ảnh chụp mới; nếu kết quả khác audit trước (SHA đổi, license
   đổi), giữ cả hai mốc thời gian để truy vết được khi nào sự thật thay đổi.

## 4. Quy tắc bắt buộc

- **Không copy code không rõ license.** Thiếu license, license không tương thích hay nghi ngờ nguồn
  gốc → chỉ đọc làm tham chiếu khái niệm. Không copy file, không copy hàm, không chép preset.
- **Không tin binary không rõ nguồn.** Không bao giờ dùng `.ex5` compiled từ repo ngoài như binary
  tin cậy — binary không đọc được nên không audit được.
- **`REFERENCE_ONLY` là mặc định.** Mọi repo mới vào shortlist ở trạng thái này. Chỉ chủ dự án đổi
  sang `USE`; khi đó audit license + nguồn + build/test + attribution chạy lại tại đúng commit SHA
  đã ghi, và thêm notice/`THIRD_PARTY_NOTICES` khi phù hợp.
- **Ghi nguồn vào ADR/PROGRESS.** Mọi quyết định `USE`/`REFERENCE_ONLY`/`REJECT` và mọi đoạn code
  chịu ảnh hưởng một repo ngoài được ghi rõ trong ADR tương ứng và nhật ký `docs/PROGRESS.md` —
  với URL, ngày audit và commit SHA.
- **Claim hiệu năng không lây nhiễm.** Không dùng repo ngoài để suy ra lợi nhuận hay độ khả thi;
  số liệu hiệu năng chỉ đến từ tester/simulation chạy trong repo này, với nhãn bằng chứng thật.
- **Câu trích thay cho link.** Tham chiếu ngoài repo trong tài liệu là câu trích văn bản, không phải
  link markdown (ADR 0008, hệ quả 3).

Trạng thái hiện tại: không repo nào ở `USE`; shortlist 7 repo và bảng audit đầy đủ nằm trong
`99-archive/MT5_EA_Lab_V2/GITHUB_AUDIT.md`, quy trình gốc nằm trong
`99-archive/MT5_EA_Lab_V3/research/GITHUB_RESEARCH_PROCESS.md`.
