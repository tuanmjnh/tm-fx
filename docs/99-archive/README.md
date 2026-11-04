# Lưu trữ — bất biến, chỉ đọc

Thư mục này giữ ba bộ tài liệu đã bị thay thế: **lịch sử và bằng chứng**, không phải tài liệu đọc
hàng ngày. Không file nào trong `99-archive/` được sửa; nội dung phải giữ nguyên từng byte.

## Vì sao giữ

- **Lịch sử quyết định:** ADR và `PROGRESS.md` trỏ về các file này làm bằng chứng gốc cho các tuyên bố
  đã từng được ghi nhận (V1 phase report, V2 audit, V3 tester).
- **Truy vết:** khi kết luận trong cây mới bị nghi ngờ, bản gốc cho biết tuyên bố đó đến từ đâu.

## Bộ pack hiện có

| Pack | Số file | Là gì |
|---|---|---|
| [MT5_EA_Lab_V1/](MT5_EA_Lab_V1/) | 46 | Pack mô phỏng đầu tiên: roadmap, prompt AI, đặc tả PA_TrendRider, phase report 0–6. |
| [MT5_EA_Lab_V2/](MT5_EA_Lab_V2/) | 20 | Pack "hiện hành" cũ: risk model, evidence, troubleshooting, đặc tả Grid/DCA/InfiniteRunner, GITHUB_AUDIT. |
| [MT5_EA_Lab_V3/](MT5_EA_Lab_V3/) | 30 | Pack kế hoạch V3: roadmap, diagnostics 0-trade, research GitHub, input sources. |

## Quy tắc

1. **Không sửa** file nào trong thư mục này, kể cả sửa link chết; link cũ được ánh xạ ở
   [LINK_MAP.md](LINK_MAP.md), không sửa đích.
2. **Không link từ luồng đọc chính:** `docs/README.md` và các tầng `00-start`…`30-research` không trỏ
   vào đây ngoại trừ riêng `LINK_MAP.md` và các trích dẫn bằng chứng trong ADR/PROGRESS.

Tài liệu còn hiệu lực nằm ở [`../README.md`](../README.md); ánh xạ link cũ → mới:
[LINK_MAP.md](LINK_MAP.md).
