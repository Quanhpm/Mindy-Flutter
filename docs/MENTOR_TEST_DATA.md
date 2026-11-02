# Dataset và UAT Mentor

Ngày 02/11/2026. Đây là đặc tả dataset cần tạo/kiểm tra trên backend local hoặc dev;
**chưa seed hay thay đổi server dev**. Không ghi mật khẩu trong repo.

## Tài khoản và dữ liệu

| Mã | Điều kiện | Ca kiểm tra |
| --- | --- | --- |
| M1 | Mentor chỉ có lớp PRIMARY | Đủ tiện ích lớp, roster/report/material |
| M2 | Mentor không có PRIMARY, được gán SUBSTITUTE một buổi | Chỉ lịch, phòng và điểm danh buổi; URL lớp không vượt quyền |
| M3 | Mentor có PRIMARY và SUBSTITUTE | Home, lịch và tên mentor chính đúng ở cả hai |
| C1 | Lớp OPEN/IN_PROGRESS, >100 enrollment hoặc mock nhiều trang | Phân trang không mất học viên |
| C2 | Lớp COMPLETED và lớp CANCELLED | readonly/capabilities; không suy quyền từ chip |
| S1 | Buổi SCHEDULED trong hôm nay theo timezone server | Roster thật rỗng, candidates provisional, start |
| S2 | Buổi IN_PROGRESS hôm nay có regular + MAKEUP | Diff 2 loại, bulk mọi trang, đồng bộ, chốt |
| S3 | Buổi COMPLETED còn editableUntil | Sửa PRESENT/ABSENT theo canEditAttendance; không về UNMARKED |
| S4 | Buổi đã hết editableUntil | Chỉ xem, xử lý 409 hết hạn |
| S5 | Buổi SCHEDULED ngày khác / CANCELLED / không có meetingUrl | Start bị chặn / chip huỷ / không nút Meet |
| E1 | CASH PENDING_PAYMENT rồi được Manager xác nhận | pendingPaymentCount và sync sau thanh toán |
| F1 | Tài liệu DRAFT/PENDING_REVIEW/APPROVED/REJECTED, cả published và chưa published | Lọc, canEdit, lý do từ chối, không nhầm APPROVED với xuất bản |
| F2 | File PDF/ảnh/video hợp lệ, file quá giới hạn/sai MIME | Upload READY/FAILED, không tạo nháp quá sớm |
| N1 | Chat bật và có thông báo đọc/chưa đọc | Cursor, badge, đọc từng/all |
| N2 | Chat tắt | Không badge giả, danh sách giải thích rỗng |

Seed sẵn trong backend: các tài khoản mentor demo; lấy mật khẩu từ môi trường seed
bằng luồng vận hành hiện có. Dữ liệu UI fixture dùng tên giả, không dựa tài khoản thật.

## Chuẩn bị an toàn

1. Chọn backend test, đăng nhập với tài khoản được cấp; không dùng production.
2. Đọc version mới nhất; gán mentor bằng API management và Idempotency-Key mới.
3. Dời một buổi **tương lai SCHEDULED** bằng
   `PATCH management/class-sessions/:id/schedule` (không dời buổi đã bắt đầu),
   giữ đúng duration/ngày dạy và kiểm tra xung đột mentor.
4. Xác nhận thiết bị truy cập được URL MinIO (thử một file nhỏ); xác nhận CHAT_ENABLED.
5. Tạo tài liệu nháp, submit, Manager approve/reject/publish trên dữ liệu test.
6. Ghi ID dùng UAT vào ghi chú cục bộ không commit; không lưu cookie/password/link ký.

## Ca bắt buộc trước Done

- Hai thiết bị đọc cùng version: thiết bị A lưu, B nhận SESSION_VERSION_CONFLICT;
  B đọc lại và xem bản nháp trước lệnh mới.
- Mất response sau ghi: retry giữ key/body, không nhân đôi hiệu ứng; đọc roster lại.
- >100 dòng: batch tuần tự, version nối tiếp; regular và MAKEUP đúng định danh.
- Đổi tài khoản khi request đang chạy: response/cookie cũ không lọt qua phiên mới.
- Chốt buổi còn UNMARKED: server đổi thành ABSENT; quyền sửa vẫn lấy từ response.
- Upload PUT hết hạn, complete mất response, PROCESSING lâu, FAILED; không tạo material rác.
- Lịch qua nửa đêm và DST ở timezone khác thiết bị; đầy đủ nhiều trang.
- Màn 320×640 chữ ×1,3 và 390×844; vi/en; loading/rỗng/lỗi/disabled.

## Nhật ký thực thi

Chưa chạy UAT thật. Chỉ đánh dấu sau khi có response/server và thiết bị kiểm chứng;
test mock không chứng minh server dev, MinIO, chat hay phân quyền tài khoản thật.
