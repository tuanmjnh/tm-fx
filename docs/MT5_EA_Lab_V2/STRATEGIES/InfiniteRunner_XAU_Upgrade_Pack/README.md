# InfiniteRunner_XAU Upgrade Pack

Gói này được tạo sau khi đọc source `InfiniteRunner_XAU.mq5` (V1.00) mà người dùng cung cấp.

## Nội dung

- `INFINITERUNNER_XAU_REVIEW_AND_UPGRADE_SPEC.md`: đánh giá source hiện tại và đặc tả kỹ thuật V2.
- `PROMPT_AI_UPGRADE_INFINITERUNNER_XAU.md`: prompt giao cho VS Code / Antigravity / OpenCode coding agent để triển khai từng phase.

## Cách dùng

1. Đặt source `InfiniteRunner_XAU.mq5` hiện tại vào workspace dự án.
2. Đặt hai tài liệu trong gói vào cùng workspace.
3. Yêu cầu coding agent đọc toàn bộ tài liệu và bắt đầu Phase 0.
4. Giữ nguyên V1, triển khai V2 thành file riêng.
5. Yêu cầu AI chỉ báo cáo compile/test khi thực sự có output từ MetaEditor/Strategy Tester.

## Phạm vi

- Ưu tiên Strategy Tester và tài khoản demo.
- Có hard guard ngăn EA gửi lệnh nếu tài khoản là REAL.
- Không đảm bảo lợi nhuận; mọi thông số phải được kiểm thử ngoài mẫu và forward test.
- Gói này gồm review/spec/prompt, không chứa bản EA V2 đã compile.
