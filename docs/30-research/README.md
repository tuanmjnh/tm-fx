# Nghiên cứu — kiến trúc, mô phỏng, dữ liệu và mã nguồn mở

Tài liệu kỹ thuật nền của lab. Chạy bot → `20-operations/`; hiểu chiến lược, rủi ro, mô phỏng → bảng dưới; ghép AI → `ai-integration.md`.

| File | Nội dung |
|---|---|
| [architecture.md](architecture.md) | Kiến trúc tổng thể: các lớp Python/MQL5, thư mục, ranh giới module. |
| [ai-integration.md](ai-integration.md) | Ba mức ghép AI vào EA, pipeline ONNX "B", bảng cấu hình phải khớp tuyệt đối. |
| [data-dictionary.md](data-dictionary.md) | Từ điển dữ liệu OHLCV: cột, đơn vị, quy ước timestamp. |
| [experiment-store.md](experiment-store.md) | Experiment store và so sánh run (Phase 6): schema, registry, metric. |
| [ml-baseline.md](ml-baseline.md) | ML baseline (Phase 7): feature, mô hình, cách đánh giá. |
| [onnx.md](onnx.md) | ONNX inference (Phase 8): export, session, parity số với MQL5. |
| [parity.md](parity.md) | Parity MQL5 ↔ Python: cùng input phải cho cùng output số. |
| [pipeline.md](pipeline.md) | Pipeline end-to-end (Phase 9): từ dữ liệu tới EA chạy được. |
| [release.md](release.md) | Checklist release nội bộ: các gate bắt buộc trước khi gọi là xong. |
| [risk.md](risk.md) | Rủi ro và giới hạn: sizing, trailing, daily loss, ranh giới cấm. |
| [simulation.md](simulation.md) | Simulation MQL5 core: thư viện `Sim/*`, runner và preset. |
| [strategy-signal-spec.md](strategy-signal-spec.md) | Đặc tả chiến lược và tín hiệu — baseline EMA crossover. |
| [testing.md](testing.md) | Quy ước test, metric và test plan cho Python và MQL5. |
| [infinite-runner-long-run-study.md](infinite-runner-long-run-study.md) | Nghiên cứu InfiniteRunner V2/V3 theo hướng chạy dài hạn, lãi nhỏ đều: mô hình "giá ngẫu nhiên trừ spread", bẫy lệch âm, thí nghiệm E1–E3/H-A…H-F và cổng G0–G4. |
| [infinite-runner-study.md](infinite-runner-study.md) | Nghiên cứu InfiniteRunner: cơ chế runner, trailing và các kết quả đo. |
| [infinite-runner-regime-entry-spec.md](infinite-runner-regime-entry-spec.md) | Đặc tả entry theo regime cho InfiniteRunner. |
| [trailing-stop.md](trailing-stop.md) | Mô phỏng trailing stop bằng Python: các loại, tham số, so sánh. |
| [open-source-research.md](open-source-research.md) | Quy trình 5 bước và tiêu chí chọn repo mã nguồn mở tham chiếu. |

Các file trên nằm trong `docs/30-research/` (ánh xạ cũ → mới xem `99-archive/LINK_MAP.md`).
