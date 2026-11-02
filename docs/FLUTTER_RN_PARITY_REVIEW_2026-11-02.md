# Đối chiếu MindyFlutter với MindyMobile — 02/11/2026

## Kết luận

Chưa đủ điều kiện coi Flutter tương đương bản React Native hoặc hoàn tất nghiệp vụ Mentor.
Flutter đã có nền tảng Student và thêm đăng nhập/phân luồng MENTOR, nhưng vẫn còn lỗi phiên,
nhận diện quyền và nhiều phần giao diện chưa port xong. Mentor hiện là khung MF1 theo MENTOR_PLAN.md.

Nguồn đối chiếu: source MindyFlutter, MindyMobile, mentor workspace backend Mindy-BE và UI web Mindy-FE2.
React Native hiện chỉ cho STUDENT đăng nhập vào app; phần Mentor của Flutter được đối chiếu với
backend/web, không có bản Mentor React Native hoàn chỉnh để so trực tiếp.

## Kết quả chạy thực tế

| Kiểm tra | Kết quả |
| --- | --- |
| `flutter pub get` | Thành công; lockfile ghi nhận uuid là dependency trực tiếp theo pubspec mới |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub` | 17/17 test hiện có pass |
| 4 suite RN liên quan auth, session navigation, payment watcher, session display status | 37/37 test pass |
| 3 test chẩn đoán phiên/quyền bổ sung | Cả 3 fail, tái hiện lỗi bên dưới |
| Login, Home Mentor, Tài khoản Student ở 320×640, chữ ×1 và ×1,3 | 6/6 ca render pass, dùng font thật được bundle trong app |
| Tất cả tiện ích Mentor ở hai mức chữ trên | 2/2 ca fail với assertion ListTile/Material |
| Build iOS simulator debug | Chưa thành công: build hook của objective_c 9.5.0 không lấy được SDK path |

Test chẩn đoán không gọi backend thật và không thực hiện giao dịch thật. File chạy và log nằm ở
`.dart_tool/review/parity_review_test.dart` và `.dart_tool/review/parity_review.log`.

## Các lỗi đã tái hiện

### 1. P1 — Request phiên cũ được gửi lại bằng cookie phiên mới

Vị trí: `lib/core/network/api_client.dart:165–174`.

Nếu request cũ trả 401 sau khi `generation` đã tăng vì đăng xuất/đổi tài khoản,
nhánh xử lý bỏ qua refresh nhưng vẫn gán generation mới rồi gọi `dio.fetch`.
CookieManager gắn cookie hiện tại vào request cũ.

Test mô phỏng POST `me/cart/items`: lần đầu dùng cookie giả `old-user`; sau khi đổi phiên,
lần retry dùng cookie giả `new-user` với cùng nội dung chọn lớp cũ. Đây có thể trở thành
thao tác ngoài ý muốn trên tài khoản mới, không chỉ là dữ liệu hiển thị cũ.

Đề xuất: dùng mốc nhận diện phiên riêng với mốc refresh; hủy/từ chối request đã thuộc phiên khác.
Chỉ retry 401 nếu vẫn cùng phiên người dùng, giữ nguyên quy tắc idempotency của thao tác.

### 2. P1 — Refresh thành công nhưng bootstrap không thoát splash

Vị trí: `lib/core/session/session_controller.dart:59–62`,
đối chiếu `lib/core/network/api_client.dart:182–186`.

Bootstrap giữ `gen` trước GET auth/me. Khi access token hết hạn nhưng refresh token còn hiệu lực,
client refresh thành công và tăng generation. GET auth/me retry thành công nhưng điều kiện
`_api.generation == gen` không còn đúng; `_accept` không chạy, state.ready vẫn false.

Test đã xác nhận auth/me chạy hai lần và trả user MENTOR hợp lệ ở lần thứ hai, nhưng ready vẫn false.
RN tách generation của HTTP refresh với generation của auth store nên không có chính xung đột này.

Đề xuất: tách session epoch khỏi refresh generation và bảo đảm bootstrap luôn hoàn tất nếu response
vẫn thuộc đúng phiên khởi tạo, kể cả có refresh hợp lệ ở giữa.

### 3. P2 — Suy sai mentor chỉ dạy thay

Vị trí: `lib/features/mentor/mentor_providers.dart:9–16`.

Provider suy không có lớp chính từ total của GET mentor/classes, nhưng không gửi assignment=PRIMARY.
Backend hiện mặc định assignment=ANY và trả cả lớp dạy thay
(`Mindy-BE/src/modules/classes/services/class-read.service.ts:118–125`).
Do đó tài khoản chỉ có một lớp SUBSTITUTE vẫn bị trả substituteOnly=false và thấy tiện ích lớp chính.
Backend vẫn kiểm quyền từng request; lỗi đã xác nhận ở cách suy quyền/hiển thị của client.

Đề xuất: truy vấn assignment=PRIMARY hoặc dùng assignmentType/accessScope/capabilities phù hợp;
không suy toàn bộ quyền từ tổng số lớp ANY.

### 4. P2 — Trang Tất cả tiện ích báo assertion ListTile/Material

Vị trí: `lib/features/mentor/mentor_pages.dart:76–89`, kết hợp StaffPage/StaffBackground.

ListTile nằm dưới nền DecoratedBox có màu, trong khi Material gần nhất nằm ở ngoài nền này.
Trên Flutter 3.47.4, render trang báo:
`ListTile background color or ink splashes may be invisible`.
Đã tái hiện độc lập ở 320×640 với font thật, cả chữ ×1 và ×1,3.

Đề xuất: đặt Material thích hợp sát nhóm ListTile, bên trong phần nền/thẻ, để ink và nền của tile
được vẽ trên đúng bề mặt.

## Parity chức năng và giao diện

| Nhóm | Tình trạng Flutter so với RN/backend |
| --- | --- |
| Auth Student | Có login/register/resend/bootstrap/logout; bootstrap còn lỗi refresh ở trên |
| Role Mentor | Đã cho phép login, phân route /mentor và chặn đi vào khu Student |
| Home Mentor | Có UI staff, avatar/tài khoản, yêu thích lưu theo user, trang tiện ích |
| Nghiệp vụ Mentor | Route tiện ích vẫn dùng MentorPlaceholderPage; chưa có lịch, điểm danh, lớp/học viên, báo cáo, tài liệu/upload thực tế |
| Thẻ buổi tiếp theo và chuông Mentor | Mới là mô tả/toast sắp có, chưa nối lịch/thông báo |
| Home Student | Có buổi tiếp theo và khóa học; chưa có các phần carousel giới thiệu/compiler/về chúng tôi/footer như RN |
| Ngày khai giảng sớm nhất trên Home | Flutter chỉ đọc tối đa trang đầu 100 lớp; RN Home đọc hết các trang trước khi chọn ngày sớm nhất |
| Catalog/chi tiết khóa/giỏ | Có luồng dữ liệu và chọn lớp cơ bản; ảnh, bố cục giỏ, chi tiết và phân trang chưa tương đương hoàn toàn |
| Thanh toán | Có watcher/QR/kết quả và xử lý unknown checkout; UI còn thiếu phần xác nhận rời trang và một số chi tiết so với RN |
| Lớp của tôi | Có current/history và các nhánh FULL/CASH_PREVIEW/PAYMENT; folder thu gọn và ảnh khóa chưa port xong |
| Chi tiết buổi Student | Flutter đang hiển thị status gốc; RN dùng sessionDisplayStatus để trình bày buổi đã qua theo endsAt |
| Xin nghỉ/dạy bù Mentor | Web/backend có, Flutter chưa triển khai trong các màn hiện tại |

Những phần Mentor MF2–MF5 chưa làm là phạm vi còn lại được ghi trong kế hoạch, không phải
khẳng định một feature được đánh dấu hoàn tất đã hỏng. Với trạng thái hiện tại chỉ có thể xác nhận
đã thêm nền tảng role Mentor, chưa thể xác nhận đã có app Mentor dùng cho nghiệp vụ.

## Giới hạn kiểm chứng

Chưa đăng nhập bằng tài khoản backend thật; chưa kiểm chứng end-to-end các giao dịch, thu hồi quyền,
lịch/phân công thực tế hoặc hình ảnh trên thiết bị thật. Build iOS bị dừng ở native dependency hook,
không phải lỗi Dart compile được analyzer phát hiện. Xcode chạy được khi chỉ định DEVELOPER_DIR,
nhưng hook chạy với môi trường lọc biến; chưa thay cấu hình Xcode toàn máy hay dependency để sửa build.

Đây là lượt review. Chưa sửa code nghiệp vụ; đã thêm test chẩn đoán và báo cáo để có bằng chứng trước khi sửa.

## Cập nhật kiểm chứng iOS sau lượt review

Ngày 02/11/2026: đã bổ sung CocoaPods, cấu hình riêng Debug/Profile/Release và gỡ tham chiếu
Swift Package Manager cũ. Người dùng đã chọn Xcode đầy đủ thay Command Line Tools.
Build iOS Simulator Debug hiện thành công bằng Xcode 27.0; đã cài và mở tới màn Đăng nhập
trên iPhone 17 Simulator, iOS 27.0. Analyzer sạch và 17/17 test hiện có pass.
Kết quả này thay thế giới hạn build iOS ở lượt review ban đầu; các lỗi nghiệp vụ đã ghi ở trên
chưa được sửa trong lần cấu hình iOS này.
