# ADR 0008 — Kiến trúc thông tin tài liệu: một cây theo mục đích, một điểm vào

- **Ngày:** 2026-11-03
- **Trạng thái:** Accepted (chủ dự án duyệt 2026-11-03)
- **Liên quan:** ADR 0001; `docs/PROGRESS.md` §53 (v1→v2), §70

## Bối cảnh
Ba bộ tài liệu chồng nhau (V1/V2/V3), ba file cùng nhận là "điểm vào duy nhất", 119/340 link chết,
5 EA 5 kiểu input.

## Quyết định
1. `docs/README.md` là điểm vào duy nhất; mọi tài liệu còn hiệu lực reachable trong ≤2 lần bấm.
2. Cây theo mục đích: `00-start`, `10-bots`, `20-operations`, `30-research`, `90-decisions`, `99-archive`.
3. Mỗi tầng có `README.md` ≤40 dòng làm mục lục cục bộ.
4. `99-archive/` là bất biến; `LINK_MAP.md` ghi ánh xạ cũ → mới.
5. `scripts/check_docs_links.py` là cổng bắt buộc; miễn `PROGRESS.md`, `99-archive/`, `archive/`.
6. `configs/demo/*.json` là nguồn sự thật preset; `.set` là dẫn xuất.

## Hệ quả
- Không tạo "pack v4"; tài liệu mới phải vào cây hiện có.
- Thêm tài liệu = thêm vào README của tầng + `REQUIRED_FILES`.
- Link ngoài repo phải là câu trích dẫn văn bản, không phải link markdown.

## Không thuộc phạm vi
Chuẩn hóa input (phase C), thay đổi logic EA, chạy tester.
