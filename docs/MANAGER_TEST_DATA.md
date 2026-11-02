# Dữ liệu và ca nghiệm thu Manager

Ngày 02/11/2026. Không lưu mật khẩu, cookie, URL ký hay hồ sơ thật trong repo.

## Fixture tự động

`tool/preview/manager_fixtures.dart` dùng HTTP adapter trong RAM, chặn mọi path
không khai báo bằng501; không fallback ra mạng. `tool/manager_preview.dart` có
assert debug guard, không được import bởi lib/main.dart/release.

Một Manager/Mentor/Student tổng hợp; khóa + Unit + lớp; một đơn nghỉ FULL_DAY có
một học viên trùng lịch; tài liệu PENDING_REVIEW của Mentor và DRAFT của Manager;
order CASH/PENDING 1.000.000 VND; timetable, candidates, incomplete, attendance,
audit, conflict OPEN và buổi học bù còn3 chỗ. Các UUID `00000000-0000-4000-8000-...`
chỉ là dữ liệu kiểm tra. Fixture mô phỏng commit mất phản hồi/409/GET lỗi/giữ phản
hồi để đổi actor; không thay bằng chứng business transaction/backend thật.

- `test/manager_logic_test.dart`: role, DTO, paging, receipt, material unknown,
  CASH đối soát, epoch, favorites, upload READY/lost complete.
- `test/manager_widget_test.dart`: router thật + HTTP adapter,19 màn vi/en ở
  320×640 chữ1,3; leave ack, nhập tiền/checkbox, giữ HTML khi sửa và đổi actor.
- Goldens `test/goldens/manager_*.png`:8 màn ×2 ngôn ngữ, phải mở xem trước bàn giao.
- Upload controller dùng MemoryFilesApi/MemoryUploadClient, không tải object thật.

## UAT môi trường có backend và người dùng thật

Chưa có account/dataset riêng được cấp cho lượt Manager này. **Chưa chạy**, không
được đánh dấu đã pass dựa trên fixture. Không dùng order/đơn nghỉ thật để thử ghi.

| Ca | Chuẩn bị / kết quả cần chứng minh | Trạng thái |
| --- | --- | --- |
| Phiên3 role | Login Student/Mentor/Manager ACTIVE, Admin từ chối; refresh/logout/relogin | Chờ môi trường UAT |
| Liên role đơn nghỉ | Mentor gửi đơn, Manager duyệt, Mentor đọc quyết định/lịch bù và Student thấy lịch mới | Chờ dữ liệu UAT |
| Hai Manager cùng đơn | Cùng expectedVersion, một quyết định thắng; người kia receipt replay hoặc409 đúng | Chờ hai actor |
| Tài liệu | Mentor nộp → Manager approve/publish → Student chỉ thấy bản hợp lệ; edit revoke | Chờ dữ liệu UAT |
| Native upload | PDF/ảnh/video, attachment/inline; iOS/Android picker, PUT/storage/worker READY, MIME/size/FAILED/cancel | Chờ storage/worker UAT |
| CASH | CASH/PENDING có hold; sai tiền, expired, hold invalid, PAYOS, PAID/review; mất mạng trước/sau commit | Chờ order tổng hợp backend |
| Hai actor CASH | Chỉ một thanh toán/enrollment, GET cuối giống nhau, không thu trùng | Chờ hai actor |
| Điều phối | Candidates đủ trang; đổi primary giữ override; session conflict/stale; replay lost ACK | Chờ lịch UAT |
| Chuyên cần | Counts/rate null có đối chứng; audits actor/action/reason chính xác | Chờ dataset |
| Học bù | Nội dung tương đương, capacity cuối, xung đột/target changed; place/cancel version đúng | Chờ dataset |
| Trợ năng | VoiceOver/TalkBack, bàn phím, vùng chạm, giảm chuyển động trên thiết bị | Chờ thiết bị/đánh giá riêng |

Sau debug preview phải build/cài `lib/main.dart` và xác minh màn app thật.
APK debug/iOS Simulator khác bản signed; TestFlight/Play vẫn cần cấu hình release.
