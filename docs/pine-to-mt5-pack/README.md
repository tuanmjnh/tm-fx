# Pine-to-MT5 Lab — Documentation Pack

Bộ tài liệu hỗ trợ AI coding agent kiểm kê Pine Script, port logic có thể chuyển đổi sang MQL5, tích hợp bằng custom indicator + EA signal-only và kiểm chứng bằng Strategy Tester.

## Files

- `ROADMAP_PINE_TO_MT5_EA.md` — roadmap, kiến trúc, các phase, kiểm thử và tiêu chí nghiệm thu.
- `PROMPT_AI_PINE_TO_MT5_EA.md` — prompt ngắn để đưa vào IDE/coding agent.

## Sử dụng

1. Giải nén bộ tài liệu vào một thư mục dự án độc lập, ví dụ `pine-to-mt5-lab`.
2. Đặt/copy Pine source mà bạn có quyền sử dụng vào workspace hoặc chỉ định rõ đường dẫn cho AI. Không yêu cầu AI sửa repository gốc.
3. Mở thư mục bằng VS Code, Antigravity hoặc OpenCode.
4. Gửi nội dung `PROMPT_AI_PINE_TO_MT5_EA.md` hoặc yêu cầu đọc file đó.
5. Chỉ cho AI chạy Phase 0 trước; review báo cáo rồi mới cho triển khai phase tiếp theo.

Phiên bản được mô tả trong tài liệu là signal-only/backtest. Không có logic gửi lệnh tiền thật.
