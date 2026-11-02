# MF6 — hoàn thiện Mentor (02/11/2026)

Tự quyết/tự review theo ủy quyền owner trong chat. Phần code và kiểm tra tự động
đã tiến hành; UAT thiết bị và server dev vẫn được ghi riêng.

## Các lỗi đã tái hiện và sửa

- Đọc assignment lỗi từng trả `false` (mentor chính). Nay giữ lỗi và có Thử lại;
  loading/refresh/error chỉ hiện tiện ích dùng chung. Server vẫn kiểm tra scope.
- Tiện ích buổi mở trực tiếp từng chỉ `read(future)`, làm provider autoDispose và
  hủy lịch giữa chừng. Nay giữ listener đến khi đọc xong, bỏ toast của phiên cũ.
- StaffButton/MindyButton từng exclude semantics con mà không có tap action ở
  node cha. Nay trình đọc màn hình bấm được nút; disabled không có tap action.
- Skeleton dùng nhãn tiếng Anh cứng và ticker vẫn chạy khi giảm chuyển động.
  Nay nhãn theo locale, dừng ticker khi giảm chuyển động/TickerMode tắt.
- Lưu yêu thích đang chờ từng lấy key sau await, ghi sang tài khoản vừa đăng nhập.
  Nay chụp key theo user trước await, cả khi tải và lưu lựa chọn.
- Đã gỡ `MentorPlaceholderPage`, chuông giả báo đang phát triển và key dịch phase
  nội bộ. Route Mentor cũ/sai có thông báo không tìm thấy + nút Về trang chủ.
- Có kiểm tra key vi/en, kiểu dữ liệu, tham số nội suy và key literal trong `lib`.

## Bằng chứng

- `bash tool/check.sh`: analyze sạch, **189 test pass**, entrypoint live
  trong `test/live` mặc định skip và được runner riêng kích hoạt.
- `test/mentor_polish_test.dart`: 12 ca, các lỗi có test đỏ trước khi sửa.
  `test/i18n_completeness_test.dart`: 2 ca dịch.
- Hai golden lỗi assignment: `test/goldens/mf6_utilities_error_320_{vi,en}.png`,
  đã mở xem tại 320×640 chữ ×1,3. UI vẫn cuộn tới lịch/dạy thay sau khối lỗi.
- Golden Home MF2 nay truyền `NotificationBell` thật thay chuông tạm; đã mở xem
  lại bản 320 chữ ×1,3 và 390 chữ thường.
- iOS Simulator main entrypoint build thành công: **8,3 giây**.
- Backend sibling build thành công, 32 migration artifact được xác minh.
  Hai suite HTTP `phase42-attendance`/`phase46-mentor-workspace`: **7 test pass**
  trên PostgreSQL riêng, dùng Nest/guard/cookie/database thật.
- `tool/live/run_mentor_smoke.mjs` + `test/live/mentor_smoke_test.dart`: **1 luồng
  live pass**, dùng SessionController, ApiClient, schedule/workspace provider và
  AttendanceController thật: login → lịch hôm nay → start → PRESENT → save →
  finalize → logout. Không override API/model/controller bằng fixture Flutter.
- Đã chạy thêm mode `MINDY_UAT_FILES=1`: UploadController thật PUT PDF →
  PROCESSING/READY → DRAFT, GET link ký và tải đủ bytes, MaterialActions gửi duyệt
  → PENDING_REVIEW; sau đó finalize và logout. MinIO/worker/Nest/PostgreSQL thật.
- Suite HTTP `phase32-files`: **39 test pass** với MinIO private/versioned thật,
  gồm PDF/Office/MP4, Article, reject/edit/resubmit/approve/paid access/withdraw.
- Native picker trên iPhone 17/iOS 27: mở/hủy về form, rồi chọn PDF tổng hợp
  `Mindy-UAT-only.pdf`; app đọc đúng **880 B**; Hủy rời trang giữ file, Bỏ và rời trang về danh sách lớp. Chạy trên preview MF5 đã cài
  (code picker không đổi ở MF6). Ảnh `docs/design/mentor/review/mf6_ios_picker_selected.png`.

## Chạy lại luồng local

Backend sibling phải được cài dependency và build bằng Node 22 theo package.json.
Runner dùng `test/http/payment-server.mjs` đã có ở backend, tắt mail/PayOS/chat,
JWT sinh trong RAM, config Flutter tạm được xóa sau chạy. Mật khẩu chỉ nhận qua
biến `MINDY_UAT_PASSWORD`, phải khớp fixture HTTP của backend.

PostgreSQL kiểm thử đang dùng container riêng `mindy-flutter-uat-pg`, port chỉ
bind `127.0.0.1:25433`, user/base DB `mindy_flutter_test`, data ở tmpfs. Không dùng
DB/volume của owner. Runner cố định kiểm tra host/port/user/base DB trước khi tạo
`mindy_flutter_smoke_http_test`; fixture chỉ reset schema của DB con này.

```sh
MINDY_UAT_DATABASE_URL='<URL của PostgreSQL test riêng>' \
MINDY_UAT_PASSWORD='<mật khẩu fixture HTTP backend>' \
/usr/local/bin/node tool/live/run_mentor_smoke.mjs
```

Mode file thêm `MINDY_UAT_FILES=1`, `MINDY_UAT_MINIO_USER`,
`MINDY_UAT_MINIO_PASSWORD`; MinIO test riêng bind `127.0.0.1:19000`. Runner tạo
bucket UUID có versioning, worker thật poll 1 giây, chỉ xóa version/bucket mà lần
chạy đó tạo. PDF tổng hợp và config nằm trong thư mục tạm, không lấy file owner.
Container `mindy-flutter-uat-minio` dùng image build từ Dockerfile MinIO backend
và tmpfs riêng, không có volume production.

Corepack cũ trên máy tìm `pnpm.cjs` trong package pnpm 12.6 chỉ có `pnpm.mjs`.
Đã dùng Node 22 gọi trực tiếp `bin/pnpm.mjs` đúng phiên bản; không sửa manifest,
lockfile hay source backend để bỏ qua ràng buộc engine.

## Còn phải kiểm chứng

- Luồng live trên là tích hợp tầng state/API, chưa chứng minh thao tác toàn bộ UI
  trên thiết bị. Checklist chi tiết ở `MENTOR_UAT.md`.
- VoiceOver/TalkBack thật, picker Android/nhiều loại file, app nền/khôi phục và hai thiết bị.
- Upload trên môi trường dev, thông báo khi chat bật/tắt.
- Server dev/tài khoản owner và bản ký phát hành chưa được sử dụng.

Không đánh dấu toàn bộ MF6 Done bằng số test tự động. Các phần Học viên, MF7 và
phát hành tiếp tục theo plan trong khi các gate UAT thiết bị được giữ lại.
