# MF5 — checkpoint tầng dữ liệu và trạng thái tiếp theo

02/11/2026. Nhánh `flutter/mf5-materials`, kế thừa MF4 `060f71b`.
Checkpoint kernel được giữ dưới đây để truy vết. Cập nhật: UI/chọn file/xem bài viết/
gửi duyệt/sửa-xóa đã triển khai và có golden/test, xem `MF5_REVIEW.md`.
**UAT thật chưa hoàn tất** (tài khoản backend, MinIO, thao tác picker/máy thật).

## Đã có

- Model file, upload intent/status, material metadata/detail/access; parser kiểu chặt,
  scope Course Unit, MIME/size, nullable trước READY và các tham chiếu attachment/image.
  Cùng ảnh được dùng inline và đính kèm là hợp lệ theo backend; không cấm nhầm.
- API tài liệu: list hết trang, detail, create, patch, submit, delete, GET asset access
  với expectedRevision; API file: intent/status/complete. Mutation đi qua ApiClient/Origin.
- Provider catalog đọc các Unit tối đa 3 đồng thời, guard lớp chính và reset theo phiên.
- UploadClient Dio riêng, không API cookies/Origin/baseUrl, PUT stream và tiến độ,
  không theo redirect; lỗi không giữ DioException/requestOptions có signed URL.
- Allowlist theo `files/domain/file-upload-policy.ts`: 25 MiB thông thường, 200 MiB MP4,
  PDF/Office/ảnh/audio/source; kiểm tra tên, extension, MIME và dung lượng trước intent.
- Controller: xin intent → PUT → complete → chờ READY → tạo **nháp**, không tự submit.
  Poll 2 giây, tối đa 2 phút/60 lượt; FAILED/DELETED không tạo material.
- Retry PUT mở stream mới; URL hết hạn chỉ xin intent mới khi người dùng bấm retry.
  Complete mất response phải GET trước, không complete lại khi đã PROCESSING/READY.
- POST tạo nháp **không có idempotency/receipt ở backend**. Mất response/5xx/schema sai:
  retry chỉ đọc list theo fileId + creator + class + Course Unit, rồi detail. Không
  tìm thấy hoặc nhiều kết quả vẫn không POST lại. Giữ flow trong RAM để kiểm tra tiếp.
- UI tương lai phải xác nhận trước `reset(abandonUnconfirmed:true)`; đây là bỏ flow
  chưa xác nhận, không chứng minh lệnh trước chưa commit. Không tuyên bố đã xóa file
  mồ côi: backend chưa có API ấy, lifecycle cleanup thuộc server.
- Khóa bấm lặp, hủy PUT/poll, giữ flow qua đóng/mở, reset khi sessionEpoch đổi.
  Kiểm tra workspace readonly/capabilities trước intent và trước POST tạo nháp.
- 13 test controller + 5 test contract/PUT, gồm lost response sau commit, chưa rõ
  commit, complete GET lỗi, timeout, hết URL, FAILED, khóa lớp giữa processing,
  đổi phiên, đóng/mở, cancel, không rò cookie/signed URL, hidden file `.pdf`.
- Native dependency: `file_picker 11.0.3`, `flutter_widget_from_html_core 0.17.4`, lock
  bởi resolver của repo hiện tại. [File Picker](https://pub.dev/packages/file_picker/versions/11.0.3)
  dùng API `pickFiles`/PlatformFile của bản đã cài; không dùng nhầm API v13.
  [HTML core](https://pub.dev/packages/flutter_widget_from_html_core) dùng để render bài viết
  canonical từ backend, thay vì tự viết parser HTML hoặc mở script trong WebView.
- `bash tool/check.sh`: analyze sạch, **137 test pass** toàn dự án tại checkpoint tầng dữ liệu/upload.
- iOS Simulator đã build sau thêm plugin: pod install 8,1s, Xcode 27,5s.

## Quy tắc đã xác minh thêm

1. REJECTED **không** submit trực tiếp được. Backend SUBMIT chỉ nhận DRAFT (hoặc cùng
   revision đang PENDING_REVIEW là no-op). UI phải cho sửa trước → PATCH thành DRAFT
   với revision mới → người dùng bấm gửi. Bulk chỉ gửi các DRAFT hợp lệ; không tự
   PATCH nội dung không đổi để bỏ qua bước sửa tài liệu bị từ chối.
2. APPROVED không đồng nghĩa published. Trang Tài liệu xem nội dung đã duyệt và
   published; trang Upload quản lý submission của chính mentor trong lớp hiện tại.
   Tài liệu đã duyệt nhưng chưa published cần nhãn riêng, không hứa học viên đã thấy.
3. ARTICLE lấy contentHtml từ detail, không gọi preview binary khi file chính null.
   Inline `<img data-file-id>` phải resolve qua GET assets/access. Không chèn URL ký
   cố định vào HTML hay lưu SharedPreferences. Attachment dùng cùng endpoint revision.
4. GET signed URL mỗi lần người dùng mở file; giữ URL trong RAM và refresh khi lỗi/hết
   hạn. Kiểm tra scheme/host/userinfo, chặn đường dẫn local/script. File mở bằng
   trình duyệt trong app; nguồn backend canonical, không tự chạy HTML/script.

## Danh sách triển khai ở checkpoint kernel (đã thực hiện ở MF5_REVIEW)

- Picker native: chọn một file theo category, dùng cached XFile/openRead (không nạp
  video 200 MiB vào RAM), xác minh length và khai báo MIME canonical từ allowlist.
- Controller quản lý tài liệu: edit/submit/delete, serialize command, expectedRevision;
  không optimistic/retry mutation; conflict 409 đọc lại và báo để xem phiên bản mới.
  Ack rồi reload lỗi chỉ GET lại. Bulk dừng khi lỗi, không báo cả lô thành công.
- UI P6 chọn lớp + published materials theo Unit/mới nhất; sheet đọc ARTICLE bằng
  HtmlWidget, inline image/attachment có retry link ký; đóng modal khi đổi phiên.
- UI P7 hai bước: lớp chưa readonly → Unit/category/file/title/description, tiến độ,
  hủy/retry/kiểm tra kết quả; submission có chip đếm, lý do từ chối, sửa/xóa/gửi duyệt.
  Dùng Staff; vi/en, loading/rỗng/lỗi/disabled, PopScope cho upload/nháp chưa xác nhận.
- Nối route placeholders `materials`/`upload`, debug fixture/preview root, golden 320
  chữ ×1,3 vi/en. Kiểm thử API/revision/các command, native picker và upload thực tế.
- Tài khoản backend/MinIO test vẫn chưa có; không đoán credentials hay giả lập là UAT thật.
