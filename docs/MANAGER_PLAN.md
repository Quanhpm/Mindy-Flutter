# Kế hoạch Manager trên MindyFlutter

Lập ngày **02/11/2026**, theo yêu cầu owner: “ok lên plan làm”.
Trạng thái: **code + check/build hoàn tất; UAT deploy còn gate riêng** trên nhánh `flutter/manager-core`.
Owner yêu cầu “thực hiện toàn bộ”; scope mở gồm MG0–MG7 và MGX1–MGX4.

## 1. Mục tiêu và phạm vi

Thêm role **MANAGER trong app MindyFlutter hiện tại**, dùng chung Login, phiên,
network và hệ Staff. Manager có trang chủ và điều hướng riêng. Thực hiện các luồng
đang có trên web trước: Tổng quan → duyệt nghỉ/dạy bù → tài liệu → thu tiền mặt.
Bao gồm điều phối giảng dạy MGX1–MGX4 theo yêu cầu tiếp theo “thực hiện toàn bộ”.

- Nguồn nghiệp vụ: backend controller + DTO + service; web là nguồn luồng thao tác.
- UI mobile: Staff kit hiện có và ảnh `docs/design/mentor/manager_home.png`.
- Giữ nguyên nghiệp vụ/quyền Student và Mentor; ADMIN vẫn chưa có không gian mobile.
- Chỉ sửa Flutter trong đợt này. Thiếu API/quyền thì ghi rõ blocker, không mở rộng
  quyền backend hay dựng số liệu để hoàn thiện màn hình.
- Kế thừa chỉ đạo: tự quyết chi tiết, tự review UI, **code trước, gom test sau**;
  không hỏi duyệt từng màn. UAT thật và kết quả chưa chạy không được ghi là Done.
- Yêu cầu lập plan hiện tại không đồng nghĩa đã cho phép thực hiện lệnh duyệt đơn
  hoặc xác nhận thu tiền thật trên server trong quá trình phát triển.

**Phạm vi đầu tiên MG0–MG7:** có đầy đủ phần Manager đang dùng trên web, gồm tạo/sửa
và upload tài liệu. MG1–MG4 là mốc dùng thử đầu tiên, MG5–MG6 hoàn thiện chức năng,
MG7 kiểm thử tích hợp/UAT. Các MGX ở mục 9 đã được mở scope theo yêu cầu thực hiện toàn bộ.

## 2. Nguồn đã đối chiếu

Mốc source local khi lập plan:

| Repo | Commit | Nguồn chính |
| --- | --- | --- |
| Flutter | `860f30b` | `core/session/`, `core/router/`, `core/ui/staff/`, Mentor MF5/MF7 |
| Backend | `37a9aa7` | `src/modules/manager-operations/`, `materials/`, `teaching-operations/`, `payments/`, `catalog/` |
| Web FE2 | `e553fb3` | `src/features/manager/`, `src/components/layout/manager-shell.tsx`, `src/lib/api/manager-rules.server.ts` |

Web Manager có 4 mục điều hướng: **Tổng quan, Quản lý tài liệu, Đơn xin nghỉ,
Thu tiền**. Luồng chi tiết lấy từ `manager-overview-page.tsx`,
`manager-leave-detail-page.tsx`, `manager-material-detail.tsx`,
`manager-material-editor.tsx`, `manager-course-workspace.tsx`,
`manager-collections-page.tsx`, `manager-cash-order-dialog.tsx`.
Schema web chỉ kiểm tra chéo; khi lệch backend thì ưu tiên backend.
Đây là bằng chứng source local, chưa xác nhận bản đang deploy có đủ endpoint.

Flutter hiện có enum MANAGER nhưng `appRoles` mới cho STUDENT/MENTOR;
`redirectFor` đưa MANAGER về Welcome. Phải mở cả login allowlist và route guard,
không chỉ thêm màn Home. Baseline trước làm: analyze sạch, **275 test pass,
1 live test skip** theo `bash tool/check.sh` ở lượt tích hợp lên main.

## 3. Cấu trúc UI và điều hướng

Dùng `StaffPage`, `GlassCard`, `StaffButton`, `StaffInput`, font Be Vietnam Pro,
mascot và token Staff. Màn danh sách dùng thẻ/bộ lọc phù hợp thao tác chạm, chi tiết
mở bằng push; xác nhận mở sheet. Có loading/rỗng/lỗi/disabled theo từng vùng.

Điều hướng chính: **Home Manager + Tất cả tiện ích**, tái sử dụng cách tổ chức
của Mentor và ảnh Home Manager. Home có tài khoản, thẻ việc cần xử lý, yêu thích,
nhóm Phê duyệt & thanh toán. Danh sách yêu thích lưu theo user và namespace Manager.

| Màn dự kiến | Route đề xuất, khai báo tập trung ở `Routes` | Phase |
| --- | --- | --- |
| Home Manager | `/manager` | MG1–MG2 |
| Tất cả tiện ích | `/manager/utilities` | MG1–MG2 |
| Đơn nghỉ | `/manager/leave-requests` | MG3 |
| Chi tiết/xác nhận duyệt hoặc từ chối | `/manager/leave-requests/:requestId` + sheet | MG3 |
| Tài liệu theo khóa/chương và kho tổng | `/manager/materials` | MG4 |
| Chi tiết tài liệu/xem file | `/manager/materials/:materialId` | MG4 |
| Tạo/sửa/upload | `/manager/materials/new`, `/manager/materials/:materialId/edit` | MG5 |
| Thu tiền | `/manager/collections` | MG6 |
| Chi tiết đơn/xác nhận tiền mặt | `/manager/orders/:orderId` + sheet | MG6 |
| Tài khoản/đăng xuất | sheet dùng chung Staff | MG1 |

Các route tĩnh `/new` đặt trước route `/:materialId`. Route gõ trực tiếp cũng phải
kiểm tra role; role trong URL hay dữ liệu cache không cấp quyền truy cập.

**Sai khác có chủ đích so với ảnh Home:**

- Số badge lấy `total` của API có cùng bộ lọc, không lấy độ dài trang đầu.
- Không hiển thị nhãn ưu tiên “tối mai”, biểu đồ doanh thu hay thống kê chưa có
  API/quy tắc tương ứng. Home hiển thị tổng PENDING đúng bộ lọc và mở danh sách tương ứng.
- Chuông hiện tại chỉ có contract CHAT_MESSAGE; không biến thành thông báo duyệt
  đơn/thu tiền. Chỉ hiện chuông khi endpoint, loại thông báo và quyền đã xác minh.
- Tiện ích điều phối/báo cáo/học bù trong ảnh chỉ xuất hiện khi MGX tương ứng có
  triển khai, không tạo nút chết hoặc số liệu mẫu trong app thật.

## 4. Thứ tự triển khai và tiêu chí đạt

| Phase | Công việc | Tiêu chí đạt |
| --- | --- | --- |
| **MG0 — Contract và dữ liệu** | Viết `API_CONTRACT_MANAGER.md`, kiểm DTO/service và quyền, snapshot web; chuẩn bị fixture, danh sách ca UAT | Chốt rõ paging, money, version/revision, mutation nào có receipt; xác minh API môi trường dùng để chạy |
| **MG1 — Phiên và shell** | Cho MANAGER ACTIVE đăng nhập; guard 3 role; Home/shell/tiện ích/tài khoản; reset cache/nháp theo epoch | Mỗi role vào đúng khu vực; không thấy dữ liệu chéo user; ADMIN không được suy thành MANAGER |
| **MG2 — Tổng quan** | Thẻ việc, đếm tài liệu nháp/chờ duyệt/đã duyệt, đơn nghỉ PENDING, link tới danh sách cùng filter | Lỗi một vùng không chặn Home; không có số/priority giả; refresh theo focus/foreground, dừng khi nền |
| **MG3 — Nghỉ/dạy bù** | Danh sách/lọc Mentor, trạng thái; chi tiết đủ trang, xung đột, nguồn lịch; duyệt/từ chối có lý do và receipt | Mentor gửi → Manager đọc/duyệt → lịch bù/đơn được đọc lại từ server; unknown/409/hai actor không tạo lệnh sai |
| **MG4 — Xem và duyệt tài liệu** | Khóa/chương, kho tổng/lọc; chi tiết, nội dung và file; approve/reject/publish/unpublish | Đúng expectedRevision/quyền; Student chỉ thấy theo trạng thái server; phân biệt approval và publication |
| **MG5 — Tạo/sửa/upload tài liệu** | Tài liệu phạm vi Course Unit, form theo type, upload stream, attachments; sửa/xóa có xác nhận | File READY mới gắn; nháp không mất khi lỗi; create unknown không POST lại; không làm mất nội dung rich text đang có |
| **MG6 — Thu tiền CASH** | Danh sách/lọc theo lớp/mã đơn/trạng thái; chi tiết; nhập số đã nhận, xác nhận và đọc lại | Chỉ đơn CASH hợp lệ, số tiền bằng tổng server; mất mạng đối soát trước khi xác nhận lại; PAYOS chỉ đọc |
| **MG7 — Kiểm thử và bàn giao** | Gom unit/widget/golden, regression 3 role, build Android/iOS; UAT liên role và đồng thời | Check sạch, có bằng chứng build/UAT; phục hồi app chính sau preview; ghi riêng gate chưa đạt |

Thứ tự: **MG0 → MG1 → MG2 → MG3 → MG4 → MG5 → MG6 → MG7**.
Trong MG0–MG6 ưu tiên code và kiểm tra biên dịch cần thiết; ghi ca kiểm tra để gom
ở MG7. Nếu phát hiện lỗi có thể làm sai dữ liệu/quyền thì xử lý ngay trước khi
chuyển phase. Khi check đã pass, chỉ chạy lại rộng nếu còn thay đổi hoặc lỗi mới.

## 5. Bản đồ API cho đợt đầu

Path tương đối sau `Env.apiUrl`; cùng ApiClient/cookie/Origin hiện tại.

| Nhóm | Endpoint đã có trong backend local | Cách dùng |
| --- | --- | --- |
| Phiên | `POST auth/login`, `GET auth/me`, `POST auth/refresh`, `POST auth/logout` | MANAGER ACTIVE; không có đăng ký Manager trên mobile |
| Khóa/chương | `GET manager/courses`, `GET manager/courses/:courseId` | Xem cả dữ liệu Manager được cấp; web cũ dùng public catalog ở một số luồng, xác minh lại schema Manager |
| Tài liệu | `GET manager/materials`, `GET manager/course-units/:courseUnitId/materials`, `GET manager/materials/:materialId` | Các bộ lọc theo DTO; đủ trang, không ghép snapshot thay đổi |
| Soạn tài liệu | `POST manager/course-units/:courseUnitId/materials`, `PATCH/DELETE manager/materials/:materialId` | PATCH body/DELETE query có expectedRevision; tạo không có receipt như leave |
| Review | `POST manager/materials/:materialId/{approve,reject,publish,unpublish}` | expectedRevision; reject có reason 1–2000 ký tự |
| Đọc file | `POST manager/materials/:materialId/files/:fileId/access` | Link ký mới theo quyền hiện tại, chỉ giữ RAM |
| Upload | `POST files/upload-intents`, `PUT uploadUrl`, `POST files/:fileId/complete`, `GET files/:fileId` | Manager có thể gắn Course Unit không bắt buộc lớp; policy/MIME/size từ contract |
| Đơn nghỉ | `GET management/mentor-leave-requests`, `GET .../:requestId` | Filter status/mentorId; detail có items, sourcesCurrent, studentConflicts |
| Xử lý đơn | `POST .../:requestId/approve`, `POST .../:requestId/reject` | Idempotency-Key + expectedVersion + reason; approve thêm acknowledgeStudentConflicts |
| Nhãn Mentor/lớp/học viên | `GET manager/mentors[/:mentorId]`, `GET manager/classes[/:classId]`, `GET manager/students/:studentId` | Chỉ tải nhãn cần dùng, cache theo epoch; không tải toàn danh bạ mỗi thẻ |
| Đơn thu tiền | `GET manager/orders`, `GET manager/orders/:orderId` | Filter paymentType=CASH, status, classId, orderCode theo DTO |
| Xác nhận CASH | `POST manager/cash-orders/:orderId/confirm` | `{receivedAmount: integer}` bằng toàn bộ tổng đơn; API không yêu cầu Idempotency-Key |

MG0 phải ghi đầy đủ schema, query và mã lỗi vào contract riêng; bảng này là bản đồ
phạm vi, không thay hợp đồng API. `/manager/payments` có API đọc nhưng màn chi tiết
thanh toán độc lập không thuộc MG6; ưu tiên dữ liệu payment lồng trong order.
Không mang kho “phiếu thu local” cũ của web vào mobile như giao dịch đã lên server.

## 6. Quy tắc nghiệp vụ cần giữ

### Đơn nghỉ và lịch bù

- Chỉ PENDING mới mở quyết định mới; mọi điều kiện cuối cùng do server kiểm tra.
- Detail phải đọc đủ item và kiểm tra tổng/ID/version giữa trang. Không suy
  `studentConflicts.length` là tổng nếu API trả giới hạn; luôn dùng count server.
- `sourcesCurrent=false` chặn duyệt; Mentor cần rút/gửi lại theo thông báo backend.
- Nghỉ theo buổi có xung đột học viên bị backend chặn. FULL_DAY có xung đột cần
  xác nhận rõ danh sách/tổng và gửi `acknowledgeStudentConflicts=true`; không tự tick.
- Khi duyệt, server tạo buổi bù/gia hạn lớp. App chỉ hiển thị kết quả trả về, không
  tự hủy/tạo buổi hoặc gia hạn dựa trên tính toán client.
- Reason trim 1–1000 ký tự. `expiresAt/asOf/timeZone` dùng đúng server; đồng hồ chỉ
  hỗ trợ trình bày, không thay quyền từ server.
- Timeout/unknown giữ sâu cùng key/body qua đóng/mở; không tạo quyết định khác khi
  lệnh trước chưa rõ. 409 phải đọc và xem snapshot mới trước ý định mới.

### Tài liệu và upload

- Theo `canEdit`/scope/owner và state machine backend; không suy Manager có thể
  sửa/xóa tất cả tài liệu vì cùng role. Xác minh quyền từng action ở MG0.
- Backend hiện mô tả approve **duyệt và xuất bản** revision; publish/unpublish là
  action riêng khi đủ điều kiện. UI xác nhận phải nói đúng tác động thực tế.
- PATCH làm trở lại DRAFT và thu hồi approval/publication theo backend; hiển thị
  rõ trước khi lưu. Khi 409 giữ input, đọc revision mới, không tự ghi đè.
- Review/PATCH/DELETE không mặc định có Idempotency-Key. Unknown thì GET đối soát
  revision/trạng thái; đã ACK mà refresh lỗi thì chỉ đọc lại, không ghi lần nữa.
- Create bị mất response không tự POST lại. Chỉ xác nhận tạo thành công khi nhận
  được ID/response đủ tin cậy; trường hợp không đối soát được phải giữ trạng thái
  chưa rõ kết quả, không ghép tài liệu chỉ vì trùng tiêu đề.
- Tái sử dụng picker, stream PUT và viewer; adapter Manager dùng courseUnitId,
  không ép classId/classUnitId như luồng Mentor. PUT storage không kèm cookie API.
- Upload qua complete/processing/READY mới tạo/gắn nháp; lỗi/cancel/actor đổi dừng
  tác vụ liên quan. Link ký không lưu preferences; mở lại xin quyền/link mới.
- Kiểu ARTICLE/FILE/VIDEO và attachments bám schema. Không chuyển rich text thành
  plain text làm mất nội dung. Giới hạn editor mobile phải ghi rõ trước triển khai.

### Thu tiền mặt

- Đọc chi tiết đơn mới trước xác nhận; show mã đơn, học viên, lớp, tổng tiền và
  số đã nhận. Không tự cộng tiền từ giá khóa hoặc sửa giá trị server.
- Chỉ CASH/PENDING và điều kiện server cho phép; PAID/EXPIRED/CANCELLED/review
  hiển thị đúng trạng thái, không tiếp tục xác nhận dựa trên cache cũ.
- receivedAmount là số nguyên VND dương bằng totalAmount; không hỗ trợ thu một
  phần, hoàn tiền hay xác nhận PAYOS. Parser Manager theo đúng miền giá trị tiền
  của backend, không áp trần tiền từ model Student nếu không cùng contract.
- Chống bấm lặp; chỉ báo thành công khi server xác nhận PAID. Timeout/unknown đọc
  lại order, kiểm tra payment/confirmedBy; trạng thái chưa rõ không được coi đã thu.
- Backend có xử lý xác nhận lặp cùng đơn/số tiền; không tự phát minh receipt key.
  Mọi thao tác xác nhận lại sau đối soát là ý định rõ ràng, không retry tự động.

## 7. Cấu trúc code và tái sử dụng

```text
lib/features/manager/
  manager_home_screen.dart
  manager_utilities.dart
  manager_providers.dart
  leave/         # models, api, providers/controller, list/detail/confirm
  materials/     # models/adapter, api, providers/controller, inventory/review/editor
  collections/   # models, api, providers/controller, list/detail/confirm
```

- Mọi provider riêng tư watch sessionEpoch, read dài có CancelToken; mutation
  chụp epoch trước await và bỏ response cũ. Dùng SessionBoundView/SheetGuard cho
  form/sheet để đổi actor không giữ nội dung người trước.
- Tái sử dụng `ApiClient`, Json/Paged/readAllPages, IdempotentCall, file APIs,
  UploadClient, picker và Staff kit. Reuse model thuần khi đúng DTO; không gọi
  endpoint Mentor bằng phiên Manager hoặc tái dùng provider cache của Mentor.
- ReceiptController hiện nằm trong Mentor operations. Nếu cần dùng chung, tách
  phần cơ chế không có nghiệp vụ vào core với regression; không import cả cụm
  controller Mentor sang Manager. Không chuyển quyền/scope thành lớp generic.
- Manager đọc nhãn liên quan có giới hạn đồng thời, tránh gọi endpoint theo từng
  dòng hàng trăm lần. Home chỉ cần count thì query pageSize=1, dùng `total`.
- Không thêm dependency theo mặc định. Text mới có vi/en, API error theo code và
  requestId; không hiện raw server message hoặc log hồ sơ học viên/phiếu thu.

## 8. Kiểm tra và dữ liệu nghiệm thu

Viết `MANAGER_TEST_DATA.md` khi MG0, không lưu mật khẩu/cookie vào repo. Fixture
synthetic chỉ trong test/tool debug, không bootstrap vào app thật. Không dùng đơn
thật để thử mutation khi chỉ được giao phát triển app.

| Phạm vi | Ca bắt buộc |
| --- | --- |
| Login/route | Student/Mentor/Manager; ADMIN; inactive; deep link sai role; logout/login người khác khi sheet đang mở |
| Đơn nghỉ | PENDING/APPROVED/REJECTED/WITHDRAWN/EXPIRED; nhiều trang; source stale; FULL_DAY có conflict; partial-day conflict; hai Manager xử lý cùng đơn |
| Receipt | Mất response sau commit, retry đúng key/body; giữ qua đóng/mở; 409 không replay; ACK rồi GET lỗi không ghi lại |
| Tài liệu | Nháp/chờ duyệt/đã duyệt/bị từ chối, published/unpublished; quyền owner/scope; expectedRevision xung đột; sửa nội dung đang xuất bản |
| Upload/viewer | PDF, ảnh, ARTICLE có attachments; file lớn hợp lệ, MIME/size sai, cancel, xử lý FAILED; nền/foreground; native picker iOS/Android |
| CASH | Đúng/sai tiền, PAYOS, hết hạn, mất giữ chỗ, PAID; mất mạng trước/sau ghi; hai Manager xác nhận; chỉ ghi nhận một lần |
| UI | 320×640 chữ ×1,3 vi/en; loading/rỗng/lỗi; cuộn/bàn phím/confirm; tap target/semantics và VoiceOver/TalkBack |
| Regression | Student và Mentor vẫn login/refresh/đăng xuất; học viên chỉ thấy tài liệu hợp lệ; Mentor thấy quyết định/lịch bù mới từ server |

Chạy gom ở MG7: `bash tool/check.sh`, build APK debug và iOS Simulator main.
Preview dùng HTTP adapter chặn network; ghi rõ fixture khác UAT API. Sau review
phải build/cài lại **lib/main.dart**, xác minh màn thật đang chạy; không để preview
MF7/Manager thay app chính trên Simulator như lần trước.

Mỗi mốc báo riêng: code xong / check pass / backend local / server dev / thiết bị /
signed distribution. Thiếu account/config/data để UAT ghi gate cụ thể, không tự
đánh dấu đã nghiệm thu. Không tự push main sau từng phase khi chưa có yêu cầu mới.

## 9. Mở rộng MGX — đã mở scope trong lượt triển khai

| Phần mở rộng | Khả năng backend đã có | Giới hạn |
| --- | --- | --- |
| **MGX1 — Tra cứu vận hành** | Manager đọc lớp/unit, Mentor/học viên, lớp liên quan và lịch Mentor | Mở màn riêng và bộ lọc; chưa có CRUD tài khoản hay tạo lớp cho Manager |
| **MGX2 — Phân công giảng dạy** | `GET management/.../available-mentors`, `PATCH management/classes/:classId/mentor`, `PATCH management/class-sessions/:sessionId/mentor` | Candidates/version/Idempotency-Key, xác nhận tác động và giữ override |
| **MGX3 — Chuyên cần** | `GET management/class-sessions/incomplete`, `GET management/classes/:classId/attendance-summary`, attendance-audits | Phần chuyên cần chỉ đọc; phục hồi attendance là nghiệp vụ riêng cần evidence, không biến thành sửa tự do |
| **MGX4 — Xếp học bù học viên** | student-schedule-conflicts, makeup-candidates, makeup-placement/cancel | Học bù học viên khác lịch bù của đơn nghỉ Mentor; kiểm tương đương nội dung, sĩ số, trùng lịch và xác nhận |

Tạo/mở/kết thúc/hủy lớp hiện là ADMIN ở `admin-classes.controller.ts`.
Không đưa các action này vào Manager bằng cách đổi guard trên client. CRUD user,
phân quyền, lương/chấm công nhân sự, dashboard doanh thu mới, bài tập/chấm bài,
chat trực tiếp, push notification vận hành, export PDF/CSV hệ thống cũng ngoài
đợt đầu. Web có nút xuất dữ liệu không đồng nghĩa app phải có ở mốc đầu.

## 10. Checklist tiến độ

- [x] Đọc web Manager, backend local và ảnh Home Manager; viết plan.
- [x] MG0 — Contract source + fixture/test data; xác minh deploy/UAT ghi gate riêng.
- [x] MG1 — Login/phân role/shell/tiện ích/tài khoản Manager.
- [x] MG2 — Home và dữ liệu tổng quan thật.
- [x] MG3 — Duyệt/từ chối nghỉ và lịch bù.
- [x] MG4 — Xem/review/publish/unpublish tài liệu.
- [x] MG5 — Tạo/sửa/xóa và upload tài liệu.
- [x] MG6 — Thu tiền CASH theo order server.
- [x] MG7 phần tự động — analyze,341 test pass,16 golden,APK/iOS main, review Simulator.
- [ ] MG7 UAT deploy/liên role/hai actor/native upload và signed distribution — xem MANAGER_TEST_DATA.md.
- [x] MGX1–MGX4 — Đã code tra cứu/phân công/chuyên cần chỉ đọc/xếp và hủy học bù.

Đã tạo nhánh `flutter/manager-core` từ main mới nhất, một luồng sửa
workspace tại một thời điểm. Ghi tiến độ tại đây, cập nhật `UI.md` cùng thay đổi.
Kết quả cuối dự kiến: một app với **Student / Mentor / Manager**, mỗi role có đúng
khu vực và quyền backend, luồng Mentor gửi → Manager xử lý được kiểm chứng.

Tiến độ triển khai và bằng chứng cuối: xem `MANAGER_REVIEW.md`. Các checkbox code
không thay cho nghiệm thu deploy/UAT và signed distribution.
