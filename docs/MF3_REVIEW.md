# MF3 — Điểm danh

Ngày 02/11/2026. UI đã tự review theo ủy quyền owner, đã nối API thật.
**Chưa chạy UAT server dev hoặc hai thiết bị thật**; kiểm tra dưới đây là test mô phỏng
với contract nguồn backend. Không đánh dấu Done phần UAT live.

## Đã triển khai

- Sheet điểm danh mở từ Lịch dạy, Buổi dạy thay và tiện ích Đồng bộ sĩ số.
  Chi tiết lớp sẽ dùng cùng hàm công khai `showMentorAttendance` khi làm MF4.
- Start tạo snapshot, 3 trạng thái UNMARKED/PRESENT/ABSENT; không coi roster rỗng là vắng.
- Bản nháp giữ diff; regular ghi bằng enrollmentId, MAKEUP ghi bằng makeupPlacementId.
- Batch tối đa 100 dòng tổng cả hai nhóm, tuần tự; version lấy response trước.
- `IdempotentCall` snapshot sâu, bất biến. Retry thủ công giữ đúng key/body và batch.
  Không tự retry mutation. Mỗi thao tác mới mới tạo key mới.
- Mất response sau commit: receipt trả lại đúng kết quả; tiếp tục batch còn lại.
  Đã ack nhưng GET roster lỗi: retry chỉ GET, không gửi lại lệnh ghi.
- Giữ call chưa xác nhận trong RAM nếu đóng sheet; mở lại vẫn retry cùng key.
  Đổi phiên reset dữ liệu/call; không persist roster hay payload trong SharedPreferences.
- 409 version: tải roster, giữ phần diff còn khác và yêu cầu xem lại trước khi lưu.
- Bulk hiện xác nhận toàn roster, sync giải thích điều kiện thanh toán, finalize hiện
  totals server và cảnh báo UNMARKED thành ABSENT. Bản nháp phải lưu/bỏ trước các lệnh này.
- Quyền từ server; hết editableUntil thì khóa, dùng asOf server + thời gian đã trôi.
  Buổi COMPLETED vẫn được sửa Có mặt/Vắng nếu canEditAttendance còn hiệu lực.
- 403 mất assignment / 404 CLASS_SESSION_NOT_FOUND: đóng sheet và làm mới lịch.
  Bảng code lỗi theo contract mục 19.8; không so message.
- Đóng sheet khi chưa lưu phải xác nhận; đang gửi khóa bấm lặp; không báo thành công
  trước khi server xác nhận và roster đã đồng bộ.

## UI và preview

Ảnh đã mở và kiểm tra: [320×640, chữ ×1,3](../test/goldens/mf3_attendance_320_vi.png).
Màn có loading, lỗi + mã hỗ trợ + retry, chưa bắt đầu, đang điểm danh, đã chốt, hết hạn.
Đã kiểm tra vi/en. Sheet có vùng roster cuộn riêng và toàn sheet cuộn khi chữ lớn.

```sh
flutter run -t tool/mentor_preview.dart
```

Mở Lịch dạy → Điểm danh để thử server trong RAM, không gọi API/backend thật.
Fixture chỉ nằm trong `tool/preview/`, ngoài entrypoint release.

Khác ảnh thiết kế: giữ 3 trạng thái và bước Bắt đầu theo backend; không có danh sách
“học viên mới sẽ thêm” trước sync vì endpoint chưa cung cấp danh sách ấy. Chỉ hiển thị
pendingPaymentCount đúng nghĩa chờ thanh toán, báo số được thêm sau response.

## Bằng chứng kiểm tra

- Unit/API: parse, mảng UUID, tổng roster, lỗi snapshot đổi giữa trang, diff/batch,
  method/key/version và bảng lỗi 19.8.
- 8 test controller: 205 dòng/mất response batch 2, version nối tiếp, conflict 409,
  reload-only retry, start/finalize/correction, hết hạn, chống bấm lặp, đổi phiên,
  giữ key khi đóng/mở sheet và ranh giới editableUntil.
- 11 widget test: 3 trạng thái × vi/en tại 320 chữ lớn, loading/lỗi/hết hạn,
  lưu rồi mới toast, cảnh báo rời bản nháp, xác nhận chốt, quay lại lịch khi buổi bị xóa.
- Rà ảnh golden bằng font bundle thật. Check toàn dự án và iOS Simulator build
  được ghi cùng tiến độ trong REMAINING_WORK_PLAN.md.

## Còn cần UAT thật

Dataset M1/M2/M3, regular + khách MAKEUP, nhiều trang; CASH được Manager xác nhận rồi
sync; hai thiết bị cùng ghi; mất mạng thật; tài khoản bị thu hồi assignment; đồng hồ
qua ngày/hạn sửa. Cần backend test khả dụng và tài khoản được cấp (hiện chưa có seed password).
