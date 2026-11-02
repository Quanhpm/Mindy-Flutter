# Checklist UAT Mentor

02/11/2026 — agent tiếp tục tự quyết theo ủy quyền. Mỗi lần chạy ghi môi trường,
build/commit, thiết bị, role, mã lớp/buổi tổng hợp và kết quả. Không ghi mật khẩu,
cookie, signed URL hay dữ liệu học viên thật vào log/ảnh lưu repo.

## Bằng chứng hiện có

| Gate | Đã chạy | Còn lại |
| --- | --- | --- |
| Logic/API/widget/golden | 189 test; 320 chữ ×1,3 vi/en ở các màn chính | Rà thiết bị thường và thao tác dài |
| Backend HTTP + PostgreSQL riêng | 7 test attendance/workspace pass | Server dev và dataset đủ mọi trạng thái |
| Flutter state/API → Nest/PostgreSQL | Login → lịch → start → save → finalize → logout pass | Thao tác UI xuyên suốt trên thiết bị |
| Build iOS Simulator | Main app build pass | Android/thiết bị thật/bản ký |
| Trợ năng | Tap semantics của nút, disabled, nhãn loading và ticker có regression | VoiceOver/TalkBack thực tế, thứ tự focus |
| File | Picker iOS hủy/chọn PDF 880 B; Flutter → MinIO READY/draft/submit; 39 backend HTTP file test pass | Android, nhiều loại file và app nền trên thiết bị |

Các ca bên dưới chưa tự động coi là đạt chỉ vì có unit/widget test tương ứng.

## 1. Phiên và phân quyền

- [ ] Login Mentor chính, Mentor chỉ dạy thay và Student; đúng khu theo role.
- [ ] Tắt/mở app, access hết hạn nhưng refresh còn hạn; không kẹt splash.
- [ ] Đổi tài khoản trong lúc lịch/file/điểm danh đang chờ: không thấy dữ liệu,
  lỗi, cookie hay yêu thích của user trước.
- [ ] Mentor chỉ dạy thay không thấy tiện ích lớp chính; deep link lớp không có
  quyền bị chặn. Mạng lỗi khi đọc assignment có Thử lại, không cấp quyền mặc định.

## 2. Lịch, Home, phòng và thông báo (MF2)

- [ ] Nhiều trang lịch đọc đủ; tuần trước/sau, ngày có/không buổi, đúng timezone
  server kể cả khi timezone máy khác.
- [ ] Home ưu tiên buổi đang diễn ra, rồi buổi tới hôm nay; hết buổi hiện rỗng.
- [ ] Dạy thay chỉ hiện buổi SUBSTITUTE trong khoảng hỗ trợ, đúng mentor chính.
- [ ] Link Meet có/không có; sao chép, mở; bị gỡ assignment khi sheet đang mở thì
  đóng và làm mới lịch, không còn vào phòng/điểm danh.
- [ ] Thông báo chat bật/tắt; cursor đọc trang sau, badge, đọc một/tất cả khớp
  server. Poll dừng khi Home bị che hoặc app nền, cập nhật khi trở lại.

## 3. Điểm danh (MF3)

- [ ] Chưa start roster rỗng, không tự tính vắng. Start trong/ngoài ngày đúng quyền.
- [ ] PRESENT/ABSENT/UNMARKED, regular và makeup; roster trên 100 dòng đọc đủ.
- [ ] Chạm đổi, Có mặt tất cả, lưu diff nhiều batch, đồng bộ sau CASH được duyệt.
- [ ] Chốt có xác nhận, UNMARKED chuyển ABSENT theo server; sửa buổi đã chốt còn
  hạn nếu quyền cho phép, hết hạn không ghi được.
- [ ] Mất mạng trước/sau ACK và đóng/mở sheet: retry cùng key/body; ACK rồi GET
  lỗi chỉ tải lại. Không gửi lặp ngoài ý muốn.
- [ ] Hai thiết bị cùng sửa: người sau nhận 409, tải lại và xem nháp trước khi lưu.
- [ ] Có nháp khi rời sheet; huỷ/tiếp tục đều giữ hành vi đúng, đổi phiên đóng sheet.

## 4. Lớp, học viên và báo cáo (MF4)

- [ ] Chip lớp đúng trạng thái; readonly không cho ghi; CANCELLED không gọi units
  bị cấm. Đếm enrollment và Unit/buổi khớp server.
- [ ] Chi tiết chọn buổi hôm nay đúng giờ/trạng thái; không đọc roster của buổi
  mentor khác phụ trách. Một buổi lỗi không làm mất toàn báo cáo.
- [ ] Chuyên cần ghép đúng enrollmentId/studentId, trọng số từ counts, mẫu số 0
  hiện chưa có tỷ lệ. Phân biệt lịch sử toàn lớp/ghi danh hiện tại/roster vật lý.
- [ ] Tìm tên có/không dấu; filter dưới 80%, từ 80%, null; lịch sử makeup/excluded.

## 5. Tài liệu và upload (MF5)

Đã có bằng chứng iOS picker PDF/hủy và state/API live với PDF → READY → DRAFT →
PENDING_REVIEW. Các checkbox dưới giữ phạm vi rộng hơn (nhiều loại file, app nền,
ngắt mạng, nhiều thiết bị), chưa đánh dấu từ một ca PDF.

- [ ] Picker native chọn/hủy PDF, Office, ảnh, MP4; đo đúng file thực, tên/MIME/
  dung lượng lỗi không tạo intent. App nền trong upload và khi picker mở.
- [ ] PUT đúng requiredHeaders, không mang cookie API; progress, hủy, URL hết hạn,
  mất response complete; PROCESSING → READY/FAILED.
- [ ] READY mới tạo nháp. Create mất response: chỉ kiểm tra theo fileId, không POST
  lại; chưa xác định có nháp thì hiển thị rõ trước khi bỏ luồng.
- [ ] DRAFT gửi duyệt, REJECTED phải sửa trước; bulk dừng ở file lỗi, số thành công
  chỉ đếm ACK. APPROVED khác published, đúng creator/capabilities/readonly.
- [ ] Edit/delete/submit 409 và mất response: không ghi lại tự động; edit giữ input
  và chỉ dùng revision mới sau khi xem snapshot mới.
- [ ] ARTICLE, inline image và attachment mở đúng file cho phép; click lấy URL
  mới; URL hết hạn thử lại; logout không giữ URL/file của tài khoản trước.

## 6. UI và thiết bị (MF6)

- [ ] 320×640 chữ ×1,3 và máy thường, vi/en: loading/rỗng/lỗi/disabled, retry,
  safe area và bàn phím; form dài và danh sách dài không overflow.
- [ ] VoiceOver/TalkBack đọc tên và trạng thái, thứ tự focus, kích hoạt nút; icon
  có nhãn, vùng bấm đủ lớn, ảnh trang trí không gây nhiễu.
- [ ] Bật/tắt giảm chuyển động khi màn đang mở; loading/nhấn không tiếp tục chuyển
  động. Không tick nền vô ích.
- [ ] Deep link cũ/sai có lối về Home; bản release không có fixture/phase nội bộ.

Ghi rõ ca chưa chạy hoặc thất bại; chỉ đánh dấu nghiệm thu toàn phase sau khi các
gate tương ứng có bằng chứng. Không chặn phần việc độc lập khác trong plan.
