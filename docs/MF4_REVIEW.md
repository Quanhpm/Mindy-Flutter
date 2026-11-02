# MF4 — Lớp, báo cáo và học viên

02/11/2026. Đã tự review theo ủy quyền owner và nối API thật. Chưa có UAT với
tài khoản backend dev; các test dưới đây dùng adapter HTTP và dữ liệu mô phỏng.

## Hành vi

- Lớp phụ trách đọc hết trang `assignment=PRIMARY`, nhóm theo lifecycle; CANCELLED
  có nhóm riêng. Từng thẻ tải tổng quan độc lập, lỗi một thẻ không che danh sách.
- Số ghi danh lấy `total` server, gồm PENDING_PAYMENT/ACTIVE/COMPLETED, không suy ra
  từ chỗ trống. Hiện số Unit/buổi nhìn thấy, không dựng % hoàn thành khóa học.
- Chi tiết lớp ghép số buổi từ endpoint Unit/session theo ID, không đánh số theo
  vị trí sau khi lọc. Ngày/giờ dùng timezone response. Buổi đã hủy không tính vào lịch tuần.
- Nút vào phòng chọn buổi đang diễn ra hôm nay trước, rồi buổi sắp tới; bỏ các buổi
  không có quyền xem context. Lịch sử đã chốt dùng cùng cache báo cáo để hiện totals.
- Buổi hôm nay mở `showMentorAttendance`; lớp readonly không hiện nút ghi.
  Quyền và hạn sửa chi tiết vẫn do response attendance quyết định.
- Deep link phải qua workspace scope CLASS/PRIMARY hoặc BOTH. Không đọc roster,
  báo cáo hay lịch sử học viên cho mentor chỉ có scope SESSION.
- Chuyên cần lớp = tổng `present` / tổng `finalizedEligibleCount` từ toàn bộ summary
  server (gồm ghi danh lịch sử). Không lấy trung bình cộng các phần trăm đã làm tròn.
- Tỷ lệ từng buổi = present/eligible trong roster vật lý đã chốt, gồm khách MAKEUP.
  Không có người đủ điều kiện hoặc còn unmarked thì hiện —. Mất quyền/403 hiện
  giải thích, không thay thành 0%. Roster đọc tối đa 3 buổi đồng thời; lỗi từng buổi
  độc lập với tổng lớp. Chi tiết lớp và báo cáo dùng chung provider/cache.
- Danh sách học viên ghép bằng enrollmentId, kiểm tra studentId; thiếu summary không
  tự điền 0. Chỉ số trên trang này tính trên các ghi danh hiện tại của roster.
- Tìm tên Việt có/không dấu. Cần chú ý <80%; Đi học đều >=80%; null chỉ ở Tất cả.
  Sheet lọc có đếm, áp dụng, đặt lại; không có Bảo lưu vì backend chưa hỗ trợ.
- Sheet chi tiết dùng summary STUDENT_CLASS_HISTORY và lịch sử điểm danh toàn bộ
  ghi danh của học viên trong lớp; giải thích khác biệt với hàng ghi danh hiện tại.
  Có nhãn học bù/tín chỉ/loại trừ. Tiến độ chỉ trình bày giá trị đã lưu và nêu chưa
  có completion policy; không dùng storedUnitCount làm số Unit hoàn thành.
- Provider riêng tư reset theo sessionEpoch, request có CancelToken; sheet chi tiết
  và lọc đóng khi đổi phiên. Không persist roster/lịch sử vào máy.

## Thiết kế và bằng chứng

Nguồn: `design/mentor/mentor_pages_1.png`, `mentor_pages_2.png`, `mentor_pages_4.png`.
Giữ header teal, nền kem, GlassCard, typography/icon và bộ lọc Staff.
Sai khác có chủ đích: bỏ thanh tiến độ không có completion policy; thêm nhãn lớp hủy,
định nghĩa chỉ số, lỗi/mất quyền, bộ lọc và lịch sử thật thay toast thiết kế.

- Đã mở và kiểm tra 9 golden `test/goldens/mf4_*.png`, gồm bốn màn vi/en tại
  320×640, chữ ×1,3 và nội dung sheet học viên. Kiểm tra cuộn và không overflow.
- 9 test model/API/provider: null/0%, trọng số, policy, tìm tên, phân trang/metadata,
  guard dạy thay trước API riêng tư, ghép enrollment không phụ thuộc thứ tự,
  giới hạn đồng thời và cô lập 403 từng buổi.
- 16 widget test: bốn màn × hai ngôn ngữ, đổi nhóm lớp, tìm/lọc, readonly, lịch sử/
  học bù, loading/rỗng/lỗi và retry hiện trên UI.
- `bash tool/check.sh`: analyze sạch, **119 test pass** toàn dự án.
- Build iOS Simulator (`lib/main.dart`) thành công trong 10 giây. Bản preview cũng
  đã chạy native trên iPhone 17; ảnh `design/mentor/review/mf4_ios_classes.png`.
  Test entrypoint MF2–MF4 kiểm tra provider overrides và mở trang Lớp.
- Entrypoint debug: `flutter run -t tool/mentor_preview.dart`; mở Lớp/Báo cáo/Học viên
  từ tiện ích. Fixture chỉ trong `tool/preview`, không import vào `lib/`.

## UAT còn lại

Đối chiếu số với backend thật cho lớp nhiều trang, học viên có nhiều ghi danh,
học bù/credit, lớp readonly/CANCELLED và buổi mentor khác dạy thay. Thử thu hồi
assignment khi màn đang mở và đổi tài khoản giữa request. Chưa có tài khoản seed
được cấp nên chưa tuyên bố UAT dev/production đã đạt.
