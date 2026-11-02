# Review UI MF2 — 02/11/2026

Trạng thái: **UI đã tự review theo ủy quyền của owner, đã nối API thật**.
Owner yêu cầu ngày 02/11: tự quyết các phần còn lại, không hỏi thêm; vì vậy không
chờ duyệt từng màn. Chưa có UAT backend thật vì thiếu thông tin đăng nhập dev.
Ảnh gốc: `docs/design/mentor/mentor_home.png`, `mentor_pages_1.png`, `mentor_pages_3.png`,
`mentor_pages_4.png`. Đã mở ảnh gốc và đối chiếu ảnh render.

## Chạy bản xem trước

```sh
flutter run -t tool/mentor_preview.dart
```

Chọn thiết bị Flutter khi được hỏi. Entrypoint chỉ chạy debug, không đọc tài khoản,
cookie hay dữ liệu backend thật. Thanh công cụ đầu màn có nhãn dữ liệu mẫu;
cuộn ngang để chọn trạng thái, các màn, ngôn ngữ vi/en và chữ ×1/×1,3.
Ngày mẫu cố định 02/11/2026, 14:15 tại Asia/Ho_Chi_Minh; không phụ thuộc giờ máy.
Nút mở link chỉ thông báo trong preview, không mở một Meet thật.

Đã build/chạy trên iPhone 17 Simulator. Ảnh runtime:
[Home iOS](design/mentor/review/mf2_ios_home.png).

## Ảnh render kiểm tra

| Vùng UI | Ảnh |
| --- | --- |
| Home, 390×844, chữ ×1 | [Home thường](../test/goldens/mf2_home_390_vi.png) |
| Home, 320×640, chữ ×1,3 | [Home chữ lớn](../test/goldens/mf2_home_320_vi.png) |
| Lịch, 320×640, chữ ×1,3 | [Lịch dạy](../test/goldens/mf2_schedule_320_vi.png) |
| Dạy thay, 320×640, chữ ×1,3 | [Dạy thay](../test/goldens/mf2_substitute_320_vi.png) |
| Nội dung sheet phòng | [Phòng học](../test/goldens/mf2_room_320_vi.png) |
| Nội dung panel thông báo | [Thông báo](../test/goldens/mf2_notifications_320_vi.png) |

Ảnh nội dung sheet/panel chưa bao gồm lớp nền mờ; chạy preview để xem sheet đầy đủ.
Golden được render bằng font bundle thật; đã xem và sửa cột giờ bị xuống dòng.

## Đã kiểm tra

- 27 test MF2: model session/context/notification; enum/timezone/URL không hợp lệ;
  mốc bắt đầu/kết thúc; tuần DST 167/169 giờ; chọn buổi Home; lọc/thứ tự dạy thay.
- Widget: lịch loading/rỗng/lỗi/dữ liệu ở 320×640 chữ ×1,3, vi/en;
  Home đủ trạng thái; thông báo đủ trạng thái/tắt chat; khóa bấm lặp và không tự
  chuyển chấm đã đọc trước khi callback hoàn tất; phòng có/không link và sao chép.
- Không đưa fixture vào `lib/main.dart` hay thay route sản phẩm bằng dữ liệu mẫu.
  Các màn nhận dữ liệu và callback; adapter API/provider riêng đã nối vào router thật.
- P0 bổ sung test request chưa tới interceptor khi đổi phiên: chụp sessionEpoch
  ngay lúc tạo request, không để lệnh cũ đi bằng phiên mới.

## Khác thiết kế có chủ đích

- Nút tuần trước/sau, Hôm nay; dải ngày cuộn ngang khi chữ lớn để giữ vùng bấm ≥44px.
- Nút Điểm danh/Vào phòng xếp dọc ở màn hẹp; giờ luôn một dòng.
- SCHEDULED hết giờ dùng “Đã hết giờ”, không giả lập lifecycle COMPLETED.
- Dạy thay hôm nay/sắp tới trước, lịch sử mới nhất sau.
- Chỉ thông báo CHAT_MESSAGE từ contract; thẻ dạy thay riêng lấy từ lịch.
- Thông báo hiện ngày/giờ tuyệt đối theo timezone server thay nhãn thời gian tương đối.
- Preview cho thử mọi trạng thái nhưng không chứng minh MinIO/chat/server dev hay UAT.

## Chưa hoàn tất trong MF2

API/provider thật đã có phân trang + join tên lớp/context (tối đa 3 context đồng thời),
timer thông báo/foreground, lưu đóng notice theo user/sessionId, đóng sheet khi 403.
Đã có test API về cursor, lỗi trang sau, mutation không tự retry và đổi phiên;
test vòng đời xác minh dừng poll khi push màn con/background, đọc lại khi trở về.
Còn kiểm tra tài khoản chỉ dạy thay và UAT thiết bị/backend với dữ liệu thật.
Nút Điểm danh trong preview hiện thông báo chờ MF3, không ghi dữ liệu.
