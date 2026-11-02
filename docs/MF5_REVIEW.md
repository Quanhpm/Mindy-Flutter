# MF5 — Tài liệu và tải file

02/11/2026. Đã tự review theo ủy quyền owner, nối API thật và kiểm tra bằng test.
Chưa coi là UAT backend/MinIO hoặc nghiệm thu thiết bị thật. Checkpoint kernel
trước đó ở `MF5_STATUS.md`; file này mô tả cả UI và các thao tác đã nối.

## Các màn và hành vi

- `/mentor/page/materials`: chọn lớp, đếm nội dung đã xuất bản từ dữ liệu đầy đủ.
  `/mentor/materials/:classId`: nhóm theo Unit, mới nhất trước, xem bài viết/file.
- `/mentor/page/upload`: chỉ chọn lớp chưa kết thúc/hủy, đếm submission của chính
  mentor theo trạng thái. `/mentor/upload/:classId`: chọn Unit và loại file, picker,
  tên/mô tả, tải → xác minh → tạo nháp, rồi mới có thao tác gửi duyệt riêng.
- Unit luôn hiển thị rõ để chọn; không đoán “Unit đang học” từ progress chưa có policy.
  File chọn qua native picker, đọc dung lượng thật từ cache và mở stream mới cho mỗi
  PUT; không giữ video 200 MiB dưới dạng một mảng bytes.
- Catalog chỉ hiển thị nội dung APPROVED ở đúng approvedRevision và đã published.
  Upload quản lý tất cả submission thuộc creator/class hiện tại. Đã duyệt nhưng chưa
  xuất bản có nhãn riêng; không hứa học viên đã xem được binary ấy.
- ARTICLE render canonical HTML bằng Flutter widgets, không thực thi script.
  Không gọi primary preview khi file chính null. Inline image theo data-file-id,
  attachments qua access đúng material/file/revision. Ảnh lỗi có nút lấy link mới.
- Mỗi lần mở binary xin signed URL mới, kiểm tra expiry và mở trình duyệt trong app.
  URL chỉ trong RAM, không ghi vào log, bản dịch, SharedPreferences hay HTML lưu trữ.
- Danh sách có chip đếm và lọc, lý do từ chối, sửa tên/mô tả, xóa nháp, gửi từng bản
  và gửi nhiều bản DRAFT có xác nhận. REJECTED phải sửa/lưu thành DRAFT với revision
  mới; không tự PATCH nội dung không đổi chỉ để lách bước sửa trước khi submit.
- Sửa/xóa/submit kiểm tra lớp chính, readonly, authorMaterials, canEdit/creator/class
  và expectedRevision. Server vẫn quyết định quyền cuối cùng. Bulk tuần tự, dừng ở
  lỗi đầu tiên và nêu số đã xác nhận; không báo thành công cho cả lô chưa gửi hết.
- 409 giữ text đang nhập, cho xem snapshot mới và xác nhận đã xem trước khi dùng
  revision mới; không retry mutation tự động. Mất response của
  edit/submit/delete chỉ kiểm tra bằng GET. Ack rồi reload lỗi chỉ đọc lại danh sách.
  Tài liệu bị xóa giữa luồng không khóa các tài liệu khác trong lớp mãi.
- Giữ flow chưa xác nhận trong RAM, reset khi đổi phiên; đóng modal chỉnh sửa cùng
  modal xác nhận khi epoch đổi. Trước khi rời upload/chọn file khác có xác nhận cho
  dữ liệu chưa gửi hoặc kết quả chưa rõ. Hủy không được tuyên bố lệnh tạo nháp đã
  rollback. Để trống tên giữ form cho sửa, chưa gửi intent hay giấu form vào flow lỗi.
- Dùng listener có thời hạn khi controller/reader đọc autoDispose future. Tránh
  nguồn bị dispose và báo REQUEST_CANCELLED nhầm khi modal không watch catalog.

## Thiết kế và kiểm tra

Nguồn đã mở: `design/mentor/mentor_pages_2.png`, `mentor_pages_3.png`.
Giữ header teal, nền kem, GlassCard, icon/font Staff, hai bước chọn lớp/tải file.
Sai khác có chủ đích: chọn Unit rõ ràng; thêm metadata/tiến độ/retry/kiểm tra kết quả;
phân biệt duyệt/xuất bản; REJECTED sửa trước khi gửi; không có Mở chương.

- 10 golden `test/goldens/mf5_*.png`: bốn màn chọn lớp/danh sách/upload × vi/en ở
  320×640, chữ ×1,3, reader bài viết và editor conflict sau khi cuộn đến snapshot mới.
  Đã mở ảnh, rà font/icon/cuộn/không overflow.
- 13 test upload controller + 5 contract/PUT ở kernel; 10 test action controller;
  4 test API/material model; 2 test bridge picker; 22 widget test.
- Bridge test gọi đúng method channel, single file, withData=false, size thật thay
  vì size báo sai, stream mở lại được, cancel, loại sai và file cache đã mất.
- `bash tool/check.sh`: analyze sạch, **175 test pass** toàn dự án.
- Build `lib/main.dart` cho iOS Simulator thành công trong **7,6s** sau kiểm tra cuối.
- Native preview đã chạy iPhone 17; Xcode build 22s. Ảnh:
  `design/mentor/review/mf5_ios_upload.png`. Preview dùng API trong RAM, không upload
  file của người dùng lên backend. Production không import `tool/preview/`.

## Phần cần kiểm chứng thật

- Backend/MinIO test: PUT thực, signature/TTL, complete mất response, worker READY/
  FAILED và cleanup lifecycle của intent mồ côi. Không có API xóa file mồ côi cho
  mobile nên app không tự tuyên bố đã dọn mọi intent lỗi.
- Mentor/Manager: gửi duyệt, approve/reject/publish, mất assignment giữa request,
  conflict revision trên hai thiết bị, nhiều trang và file lớn.
- Native picker thao tác trực tiếp/VoiceOver/máy thật. Công cụ UI báo Mac đang khóa,
  chưa chọn file thủ công trên Simulator trong lượt này; build/bridge mock không
  thay thế phép thử đó. Tài khoản seed backend vẫn chưa được cấp trong môi trường.


Bổ sung kiểm thử ở MF6: đã chạy native picker iOS chọn/hủy PDF tổng hợp 880 B;
Flutter UploadController/API → MinIO/worker thật → READY → DRAFT → signed download
→ submit pass. 39 test HTTP file/material backend pass trên test DB/storage riêng.
Bằng chứng và giới hạn cập nhật ở `MF6_REVIEW.md` và `MENTOR_UAT.md`; ghi chú
Mac khóa/thiếu môi trường ở trên là trạng thái tại thời điểm MF5, không phải kết quả mới.
