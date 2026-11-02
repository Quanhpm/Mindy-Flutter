# Contract Manager — Flutter

Đối chiếu source local ngày 02/11/2026: backend `37a9aa7`, web FE2 `e553fb3`.
Phạm vi owner yêu cầu thực hiện: MG0–MG7 và MGX1–MGX4. Endpoint dưới đây tương đối
với `Env.apiUrl`. Đây là contract source, không phải bằng chứng UAT bản deploy.

## Quyền, phiên và đọc dữ liệu

- Login/me/refresh/logout dùng ApiClient và cookie hiện có; MANAGER ACTIVE mới vào
  `/manager`. STUDENT/MENTOR/ADMIN không được suy thành Manager.
- Tất cả màn/sheet gắn session epoch; đổi tài khoản bỏ nháp, request và phản hồi cũ.
  Request đang xếp hàng cũng kiểm epoch trước khi gửi. Không lưu receipt/signed URL
  vào preferences. Yêu thích lưu riêng `manager_favorites_<actorId>`.
- Danh sách là `{items,page,pageSize,total}`; dùng total server, đọc hết trang với
  giới hạn concurrency 3 cho API đọc Manager. Phát hiện trùng ID, total/pageSize
  đổi, phiên bản snapshot lệch thì báo lỗi và cho đọc lại.
- UUID, enum, offset thời gian và IANA timezone được kiểm trước khi hiển thị.
  Tiền VND là integer 0..9007199254740991 theo backend, không parse tiền từ chuỗi.
  Lỗi hiển thị mã dịch + requestId, không hiện raw server message.

## Tra cứu và shell

| API | Flutter dùng |
| --- | --- |
| `GET manager/courses`, `manager/courses/:id` | Khóa học + Unit; isActive từ server |
| `GET manager/mentors`, `manager/students` | q gửi khi xác nhận tìm; ACTIVE/SUSPENDED đọc được |
| `GET manager/mentors/:id`, `manager/students/:id` | Thông tin liên hệ, kiểm role và ID |
| `GET manager/classes`, `manager/classes/:id`, `manager/classes/:id/units` | Lớp, phòng, Unit, enrollment count |
| `GET manager/mentors/:id/classes`, `manager/students/:id/classes` | Lớp liên quan và enrollment/payment |
| `GET manager/mentors/:id/schedule?from&to` | Lịch tuần theo timezone server, kiểm range metadata |

Home dùng pageSize=1/total của đơn nghỉ PENDING, tài liệu DRAFT/PENDING_REVIEW/
APPROVED và order CASH/PENDING. Mỗi vùng lỗi độc lập. Refresh khi quay lại,
foreground và mỗi 60 giây khi Home hiện; không HTTP polling khi nền. Không dựng
priority, số doanh thu hoặc thông báo vận hành chưa có API.

## Đơn nghỉ Mentor

Source: `teaching-operations/controllers/management-leave.controller.ts`, DTO leave,
service/domain của đơn nghỉ và web Manager leave detail.

- `GET management/mentor-leave-requests?status&mentorId&page&pageSize`.
- `GET management/mentor-leave-requests/:id?page&pageSize`: items có phân trang;
  đọc đủ itemCount. Giữ id/version/count/pageSize/sourcesCurrent nhất quán.
  `studentConflictCount` là tổng, danh sách chi tiết có thể chỉ là một phần.
- `POST .../:id/approve`: `{expectedVersion,reason,acknowledgeStudentConflicts}`.
- `POST .../:id/reject`: `{expectedVersion,reason}`. Reason trim, 1..1000 ký tự.
- Hai POST có `Idempotency-Key`. Mất phản hồi giữ nguyên key + body + action trong
  RAM qua đóng/mở màn. 409 không replay; đọc trạng thái mới trước ý định mới.
- Duyệt trả request + replacements/extensions; reject có thể trả request trực tiếp.
  Kiểm ID, status và version+1. ACK rồi invalidate đọc server, không ghi lại.
- FULL_DAY có xung đột cần checkbox xác nhận; partial-day có conflict và nguồn stale
  không cho duyệt. Backend vẫn quyết định cuối về hạn/quyền/đụng lịch.

## Tài liệu và Files

Source: `materials/controllers/`, `dtos/manager-material-input.dto.ts`,
`material-management.dto.ts`, `services/material-authoring.service.ts` và policy.

| API | Ý nghĩa |
| --- | --- |
| `GET manager/materials?courseUnitId&reviewStatus&contentType` | Kho tổng và theo Unit, đủ trang |
| `GET manager/materials/:id` | Nội dung canonical HTML, quyền canEdit, files, revision |
| `POST manager/course-units/:id/materials` | Tạo DRAFT phạm vi Course Unit |
| `PATCH manager/materials/:id` | expectedRevision trong body; sửa về DRAFT |
| `DELETE manager/materials/:id?expectedRevision` | Xóa khi server cho canEdit |
| `POST manager/materials/:id/{approve,reject,publish,unpublish}` | expectedRevision; reject reason 1..2000 |
| `POST manager/materials/:id/files/:fileId/access` | Không body; kiểm material/file/revision và HTTP(S) URL |

- Type chỉ ARTICLE/FILE/VIDEO. Title 1..250; description nullable <=5000;
  sortOrder integer 0..2147483647; availableAt nullable có offset;
  attachmentFileIds duy nhất <=50. ARTICLE có đúng một contentText/contentHtml,
  tối đa 48 KiB UTF-8; giữ canonical HTML của bản cũ khi sửa.
- FILE/VIDEO chỉ gắn primary file READY, đúng Course Unit; attachment/inline cũng
  READY. Inline HTML dùng `img data-file-id`, không chèn signed URL vào content.
- Approve **đồng thời xuất bản** theo service. Publish/unpublish yêu cầu
  approvedRevision==revision. canEdit do server trả, không suy từ role/owner riêng.
- Các mutation tài liệu **không có receipt contract**. Unknown khóa ghi, GET lại
  và xác nhận phiên bản; create unknown chọn bản đã tạo thuộc owner/Unit để tiếp
  tục, không POST lại tự động. HTTP 409 cũng cần đọc lại. Không thêm header receipt.
- `POST files/upload-intents` với courseUnitId/originalFilename/declaredMimeType/declaredSizeBytes (Manager không có
  classId/unitId); PUT stream qua UploadClient riêng không cookie; POST complete;
  GET files/:id đến READY/FAILED/DELETED. Poll 2s tối đa60, dừng khi nền/cancel.
  Complete mất phản hồi chỉ kiểm status, không complete/PUT lại. Dùng file cần thao
  tác xác nhận riêng. File picker/policy dùng chung dịch vụ Mentor.
- Access URL chỉ trong RAM, không prefetch tất cả; kiểm expiry/revision trước mở.
  Viewer không render URL ảnh tùy ý từ HTML, dùng file reference được cấp quyền.

## CASH

Source: manager-operations controller/response DTO, payments confirm-cash service.

- `GET manager/orders?paymentType=CASH&status&classId&orderCode&page&pageSize`.
- `GET manager/orders/:id`: student + details + payment.confirmedBy/review.
- `POST manager/cash-orders/:id/confirm` body `{receivedAmount}` integer dương,
  đúng toàn bộ totalAmount server. Trả bare OrderDto; sau ACK đọc lại detail.
- Không có receipt header. Trước ghi GET mới, chỉ CASH/PENDING không review; nhập
  số tiền và checkbox đã nhận. PAYOS chỉ đọc. Hạn, hold, transaction do server quyết.
- Unknown/ACK rồi GET lỗi: chỉ GET đối soát, không tự POST. PAID hiển thị người thu
  và trạng thái; backend business idempotency bảo vệ hai actor xác nhận đồng thời.

## MGX điều phối, chuyên cần và học bù

| API | Điều kiện |
| --- | --- |
| `GET management/classes/:id` | Nested class + paged sessions; assignmentVersion và total ổn định |
| `GET management/{classes,class-sessions}/:id/available-mentors` | Đủ trang, kiểm target/version/timeZone; basis TEACHING_SCHEDULE_AND_APPROVED_LEAVE |
| `PATCH management/{classes,class-sessions}/:id/mentor` | Receipt, expectedVersion, mentorId, reason 1..1000; session mentorId=null xóa override |
| `GET management/class-sessions/incomplete` | classId/issue; issue OVERDUE_NOT_STARTED/STARTED_NOT_FINALIZED; deadlineExpired có thể null |
| `GET management/classes/:id/attendance-summary` | Counts/rate từ server; rate null không thay thành0 |
| `GET management/class-sessions/:id/attendance-audits` | Actor/action/reason/status/time/version; chỉ đọc |
| `GET management/student-schedule-conflicts?status` | All đọc OPEN,MAKEUP_ASSIGNED,RESOLVED riêng; mặc định backend bỏ RESOLVED |
| `GET management/student-schedule-conflicts/:id/makeup-candidates` | Lịch và remainingCapacity từ server |
| `POST management/student-schedule-conflicts/:id/makeup-placement` | Receipt, expectedVersion, targetSessionId, expectedTargetVersion, contentMatchConfirmed=true, reason |
| `POST management/makeup-placements/:id/cancel` | Receipt, expectedVersion của placement, reason |

Phân công dựa trên candidates server, xác nhận số buổi tác động; đổi primary giữ
các substitute override theo service. Học bù cần người dùng xác nhận tương đương
nội dung; backend kiểm lịch/sĩ số/enrollment lần cuối. Không có Manager placement
GET để lấy chi tiết đích sau reload nên không gọi endpoint Student hoặc dựng dữ
liệu đích từ UUID. Attendance recovery write ngoài scope; không có nút sửa tự do.

## Giới hạn release

Không sửa quyền backend, không CRUD user/tạo mở hủy lớp ADMIN, không thêm chat,
lương, push hay dashboard tài chính. Source/fixture không chứng minh deploy có đủ
API. UAT account thật, đồng thời hai actor và native upload môi trường deploy
phải được ghi riêng trong MANAGER_TEST_DATA.md và MANAGER_REVIEW.md.
