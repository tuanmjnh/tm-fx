# Audit GitHub và license

- **Trạng thái:** `DONE_METADATA` — cả 7 repo trong shortlist đã có commit SHA của default branch và
  trạng thái license file xác minh từ GitHub API + nội dung file license gốc.
- **Ngày audit:** 2026-10-29 (giờ máy GMT+7).
- **Phạm vi đã làm:** metadata repo, default branch, HEAD SHA, license file, SPDX, dòng đầu file license.
- **Phạm vi chưa làm:** đọc source từng repo, chạy build/test của họ (`NOT_RUN`). Không cần cho quyết
  định hiện tại vì **không dòng code ngoài nào được dùng**.
- **Kết luận quan trọng:** không có code third-party nào được copy vào repo này; mọi quyết định là
  `REFERENCE_ONLY` hoặc `REJECT`.

## 1. Sự thật đang có

- Shortlist 7 repo lấy từ
  [research/GITHUB_OPEN_SOURCE_RESEARCH.md](../archive/planning-inputs/MT5_EA_Lab_v2/research/GITHUB_OPEN_SOURCE_RESEARCH.md).
- HEAD SHA dưới đây là commit tip của **default branch** tại thời điểm audit, lấy từ
  `GET /repos/{owner}/{repo}/commits/{branch}`.
- License lấy từ `GET /repos/{owner}/{repo}/license` và đối chiếu nội dung
  `raw.githubusercontent.com/{repo}/{branch}/{license_path}`.
- Dữ liệu thô: [`reports/build/github_audit_meta.json`](../../reports/build/github_audit_meta.json).
- `pushed_at` của API là lần push gần nhất trên **bất kỳ** branch; với `EA31337/EA31337` nó mới hơn
  HEAD của `master`, nên chỉ HEAD SHA mới là mốc tham chiếu.

## 2. Kết quả audit

| Repo | Branch | HEAD SHA | HEAD date | License file | SPDX | Dòng đầu license | Quyết định |
|---|---|---|---|---|---|---|---|
| [EA31337/EA31337](https://github.com/EA31337/EA31337) | `master` | `9b9bd38c4e49dd6916f4fe3936e50e97fca7a692` | 2024-09-19 | `LICENSE` | GPL-3.0 | `GNU GENERAL PUBLIC LICENSE / Version 3, 29 June 2007` | `REFERENCE_ONLY` — GPL không hợp kế hoạch license hiện tại |
| [santiquiroz/leviathan](https://github.com/santiquiroz/leviathan) | `master` | `44627962fae399ef9b734e04f44cb1045d5beaff` | 2026-09-25 | `LICENSE` | MIT | `MIT License / Copyright (c) 2026 Santiago Quiroz` | `REFERENCE_ONLY` |
| [BlamzKunG/XAUUSD-Grid-EA](https://github.com/BlamzKunG/XAUUSD-Grid-EA) | `main` | `9ffd0840f53b17c33396427721d02885e36b88cd` | 2026-08-29 | `LICENSE` | MIT | `MIT License / Copyright (c) 2026 BlamzKunG` | `REFERENCE_ONLY` |
| [ilyasyldrm0/MetaTrader5-BOT](https://github.com/ilyasyldrm0/MetaTrader5-BOT) | `main` | `6ed67cf51d5f1dcf9df720329656ccdb0186a4c0` | 2026-09-02 | `LICENSE.md` | MIT | `The MIT License (MIT) / Copyright (c) 2023` | `REFERENCE_ONLY` |
| [omidram/trading-bot](https://github.com/omidram/trading-bot) | `main` | `ccc1d1e2e592674371366e4b15628e35c58b2c21` | 2026-09-23 | `LICENSE` | MIT | `MIT License / Copyright (c) 2026` | `REFERENCE_ONLY` |
| [edisonq/Golden-Structure-V1](https://github.com/edisonq/Golden-Structure-V1) | `main` | `ad0b615fc0c40caef29e9677f0579932cd462f64` | 2026-01-26 | `LICENSE` | MIT | `MIT License / Copyright (c) 2026 Edison Quinones` | `REFERENCE_ONLY` — chiến lược **không** phải PA_TrendRider |
| [AlexKu111/GridBot-Mql5](https://github.com/AlexKu111/GridBot-Mql5) | `main` | `e4202e957bdcf5c66a78c17152d4ccb77e41e59b` | 2026-01-13 | **không có** (API `404`) | none | — | `REJECT` — không có license |

`REFERENCE_ONLY` nghĩa: chỉ đọc để tham khảo ý tưởng, không copy file, không copy hàm, không chép
preset. `REJECT` nghĩa: không dùng dưới bất kỳ hình thức nào.

## 3. Checklist trước khi dùng code (trạng thái từng mục)

| # | Mục | Trạng thái |
|---|---|---|
| 1 | URL, ngày kiểm tra, default branch, commit SHA | **DONE** — bảng §2 |
| 2 | Nội dung `LICENSE`, SPDX, ghi rõ nếu thiếu | **DONE** — 6/7 có license; AlexKu111 thiếu → REJECT |
| 3 | Đọc source, đặc biệt execution và tính volume | `NOT_RUN` — chưa cần vì không dùng code |
| 4 | Build/test workflow, độ phủ, tái lập claim | `NOT_RUN` |
| 5 | Dependencies, call mạng, xử lý secret, binary/obfuscation | `NOT_RUN` |
| 6 | Hỗ trợ MQL5/MT5 thật hay chỉ MT4/Python | `NOT_RUN` |
| 7 | Phần định dùng (kiến trúc/test/docs) | không áp dụng — không dùng phần nào |
| 8 | Attribution/license notice | không áp dụng — không copy file nào |
| 9 | Quyết định `USE` / `REFERENCE_ONLY` / `REJECT` | **DONE** — bảng §2, không có `USE` |

Chỉ khi chủ dự án đổi một repo sang `USE` thì mục 3–8 mới trở thành điều kiện bắt buộc; khi đó phải
audit lại tại đúng commit SHA ghi ở §2.

## 4. Ràng buộc riêng của repo này

- Không copy code GPL vào repo nếu chưa có quyết định license rõ ràng của chủ dự án.
- Không repo ngoài nào được thay thế `PATrendRiderXAUv1`; source hiện tại là nguồn sự thật.
- Không dùng repo ngoài để suy ra lợi nhuận, số star, hay ảnh chụp màn hình.
- Mọi code gửi lệnh vẫn phải nằm trong ba file Exec đã được ADR 0003 cho phép; copy một EA khác vào
  là vi phạm gate tĩnh.

## 5. Việc còn lại

- [x] Ghi commit SHA + license file cho cả 7 repo.
- [x] Quyết định `REFERENCE_ONLY`/`REJECT` cho từng repo; không có `USE`.
- [ ] Đọc source phần execution/risk — chỉ khi một repo được đổi sang `USE`.
- [ ] Chạy build/test của họ trong môi trường tách biệt — chỉ khi `USE`.
- [ ] Thêm notice + kiểm tra tương thích license — chỉ khi `USE`.

Audit được coi là đóng ở mức metadata. Quyết định có audit sâu hơn hay không thuộc chủ dự án — xem
[DECISIONS_REQUIRED.md](DECISIONS_REQUIRED.md) mục 3.

## 6. Cách tái lập

```powershell
# Cần Internet; GitHub API không cần token cho 7 repo này (giới hạn 60 request/giờ/IP)
$repos = @(
  "EA31337/EA31337","santiquiroz/leviathan","BlamzKunG/XAUUSD-Grid-EA",
  "ilyasyldrm0/MetaTrader5-BOT","omidram/trading-bot","edisonq/Golden-Structure-V1",
  "AlexKu111/GridBot-Mql5"
)
foreach ($r in $repos) {
  $meta = Invoke-RestMethod "https://api.github.com/repos/$r"
  $head = Invoke-RestMethod "https://api.github.com/repos/$r/commits/$($meta.default_branch)"
  "{0} {1} {2} {3}" -f $r, $meta.default_branch, $head.sha, $meta.license.spdx_id
}
```

Kết quả mong đợi khớp bảng §2. SHA sẽ đổi nếu repo có commit mới; khi đó phải audit lại, không được
coi bảng này là vĩnh viễn.
