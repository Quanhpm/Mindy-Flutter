# Contract Mentor — MindyFlutter

Đối chiếu ngày **02/11/2026**, backend `37a9aa7e997077b5a30f72838f19129493e2fdde`.
Nguồn chính là controller, DTO và service trong `../Mindy-BE/src/modules/`;
schema web `../Mindy-FE2/src/features/mentor/schemas/{mentor-contracts,workspace-contracts}.ts`
chỉ dùng kiểm tra chéo. Không dùng contract RN cũ làm nguồn.

## 1. Quy ước

- Base URL từ `Env.apiUrl`, path tương đối dưới đây không có `/` đầu.
- Cookie HttpOnly qua `ApiClient`; role MENTOR, user ACTIVE. Không truyền userId/role tự tính.
- DTO trả trực tiếp, riêng danh sách thông báo dùng `{data, meta}`.
- ID là UUID; timestamp ISO có offset; ngày thuần `YYYY-MM-DD` không đổi timezone.
- Phân trang số: `page >= 1` mặc định 1, `pageSize = 1..100` mặc định 20.
  `Page<T> = {items: T[], page, pageSize, total}`. Đọc mọi trang nếu cần tất cả;
  kiểm tra metadata, ID trùng, total/version thay đổi giữa trang; báo lỗi hoặc đọc lại,
  không ghép hai snapshot khác nhau.
- Range `from`, `to` phải cùng có/cùng thiếu, `from < to`, tối đa 93 ngày.
  Query chọn buổi giao với `[from,to)`: `startsAt < to && endsAt > from`.
- Hiển thị bằng `timeZone` server, không dùng timezone của máy. `asOf` là mốc đọc,
  không phải version dùng để ghi. Enum/trường sai kiểu phải ném lỗi parse 502.
- Request ghi tự có `Origin = Env.appOrigin`; materials/notifications có origin guard.
  Không retry tự động mutation. Link ký chỉ lưu RAM, bỏ khi đổi phiên.

Nguồn: `common/dtos/page-options.dto.ts`, `classes/dtos/teaching-query.dto.ts`,
`classes/services/teaching-read.service.ts`, `attendance/dtos/attendance-report-query.dto.ts`.

## 2. Lịch và phòng học (MF2)

`GET mentor/schedule?from&to&classId&page&pageSize`

Trả `Page<SessionView> + {from, to, timeZone, asOf}`. Thiếu range thì backend chọn
tuần hiện tại theo timezone dạy học; app có thể dùng lần đọc này để biết timezone
trước khi tính range tuần tiếp theo. Gồm buổi được giao chính và dạy thay hiệu lực.

`SessionView` (`TeachingSessionDto`):

| Field | Kiểu |
| --- | --- |
| sessionId, classId, classUnitId | UUID |
| title | string (tên buổi, không phải tên lớp) |
| startsAt, endsAt, asOf | timestamp; `endsAt > startsAt` |
| status | SCHEDULED / IN_PROGRESS / COMPLETED / CANCELLED |
| primaryMentor | `{id: UUID, displayName: string\|null}` |
| effectiveMentor | Person hoặc null |
| assignmentType | PRIMARY / SUBSTITUTE |
| version | integer >= 1 |
| actualStartedAt, actualEndedAt, editableUntil | timestamp hoặc null |
| makeupForSessionId, makeupRootSessionId | UUID hoặc null |
| timeZone | IANA timezone hợp lệ |

**Không có tên/mã lớp, số buổi, phòng hay meetingUrl trong schedule.** Ghép tên/mã
lớp từ `GET mentor/classes?assignment=ANY` đọc hết trang; room/link từ context.
Không dùng `session.title` làm tên lớp, không tự đoán phòng.

`GET class-sessions/:sessionId/context` trả:

```text
{session: SessionView, roomName: string|null, meetingUrl: string|null,
 accessScope: 'SESSION', makeupPlacementId: UUID|null}
```

Link ưu tiên buổi rồi lớp; chỉ mở URL http/https hợp lệ, không userinfo.
403 `SESSION_ASSIGNMENT_REQUIRED`: mentor đã mất quyền, đóng sheet và tải lại lịch.
Không hiện nút Meet khi link null. Sao chép link không phải mutation backend.

Trạng thái hiển thị là logic trình bày, không cấp quyền ghi:
COMPLETED/CANCELLED có ưu tiên; IN_PROGRESS luôn đang diễn ra; còn SCHEDULED thì
`start <= now < end` đang diễn ra, trước start sắp tới, sau end đã hết giờ.
Buổi SCHEDULED đã hết giờ **không tự chuyển thành COMPLETED**.

Nguồn: `classes/controllers/{mentor-schedule,session-context}.controller.ts`,
`classes/dtos/teaching.dto.ts`, `classes/services/teaching-read.service.ts`.

## 3. Lớp, workspace, unit và roster (MF4/MF5)

`GET mentor/classes?assignment&status&page&pageSize` trả `Page<MentorClass>`.
`assignment = PRIMARY | SUBSTITUTE | ANY` (mặc định **ANY**).
`status = DRAFT | OPEN | IN_PROGRESS | COMPLETED | CANCELLED`.

`MentorClass`:
`{id, courseId, code, name, startDate, endDate, deliveryMode, maxStudents,
availableSeats, mentor: Person, status, assignmentType, accessScope}`.
`assignmentType = PRIMARY | SUBSTITUTE | BOTH`, `accessScope = CLASS | SESSION`.
Không có meetingUrl, room, tổng học viên ACTIVE hay tiến độ trong DTO này;
`maxStudents - availableSeats` còn bao gồm chỗ được giữ, **không phải sĩ số đã học**.
Phát hiện mentor chỉ dạy thay bằng `assignment=PRIMARY&page=1&pageSize=1`, `total==0`.

`GET mentor/classes/:classId` trả workspace:

```text
{id, classId, code, name, status, course:{id,title}, accessScope,
 assignmentType, readonly, visibleUnitCount, visibleSessionCount, asOf, timeZone,
 capabilities:{readClass,readClassRoster,readClassReports,authorMaterials}}
```

Tuân thủ capabilities và readonly; dạy thay không được mở roster/report/material
của cả lớp chỉ vì truy cập được shell.

`GET mentor/classes/:classId/sessions?from&to&unitId&page&pageSize`:
`Page<SessionView + {capabilities:{readSessionContext,writeTeachingNotes}}>`.
Range là tùy chọn, không tự áp một tuần nếu muốn đọc hết lớp.

`GET mentor/classes/:classId/units?page&pageSize`: `Page<Unit>` với
`{id, classId, courseUnitId, title, position, status, unlockAt}`;
`status = LOCKED | OPEN | COMPLETED`, unlockAt nullable. Không có API mở chương.
`unitId` trên path là **Class Unit ID**, khác `courseUnitId` dùng upload.

`GET mentor/classes/:classId/units/:unitId`: `{id,courseUnitId,position,title,
status,unlockAt,sessions:[{id,sessionNumber,title,startsAt,endsAt,roomName,status,
classUnitId,meetingUrl}]}`.

`GET mentor/classes/:classId/units/:unitId/sessions?page&pageSize` trả
`Page<{id,classUnitId,title,sessionNumber,status}>`; endpoint này không có thời gian.
Muốn thời gian, dùng workspace sessions với `unitId`.

`GET mentor/classes/:classId/students?paymentType&orderStatus&page&pageSize` trả
`Page<{enrollmentId,enrollmentStatus,studentId,studentName,orderId,orderCode,
orderStatus,paymentType,classAmount,orderTotalAmount,orderClassCount,expiresAt,
paidAt,canConfirmCash}>`.

- enrollmentStatus: PENDING_PAYMENT / ACTIVE / COMPLETED / CANCELLED.
- orderStatus: PENDING / PAID / EXPIRED / CANCELLED; paymentType: CASH / PAYOS.
- paidAt nullable; tiền nguyên VND từ server. Mentor không xác nhận tiền mặt.
- Không có trạng thái Bảo lưu. Ghép chuyên cần bằng enrollmentId, không chỉ studentId.

Nguồn: `payments/{controllers/mentor-class-roster.controller,dtos/mentor-class-roster.dto}.ts`,
`classes/controllers/{mentor-workspace,mentor-content-context}.controller.ts`,
`classes/dtos/{class,mentor-workspace,mentor-content-context}.dto.ts`.

## 4. Báo cáo chuyên cần và tiến độ (MF4)

`GET mentor/classes/:classId/attendance-summary?from&to&page&pageSize` trả
`Page<{enrollmentId,student:Person,...Counts}> + {classId,readonly,asOf,timeZone}`.

`Counts = {present,absent,unmarked,excluded,makeupPending,finalizedEligibleCount,
rate:number|null}`. Các count không âm; rate 0..100 hoặc null (chưa có buổi được tính).
**Không có ba số tổng toàn lớp hoặc bảng tổng theo buổi ở endpoint này.**
Không hiển thị null thành 0% hoặc tự tạo % hoàn thành học tập.
Nếu cần % theo buổi, đọc roster của buổi đã chốt (tối đa 3 request đồng thời, cache
theo phiên); phân biệt số điểm danh vật lý với tín chỉ học bù của báo cáo.
Các số tổng trình bày trên UI cần đặc tả rõ cách gộp trước khi triển khai MF4.

`GET mentor/classes/:classId/students/:studentId/attendance?from&to&page&pageSize`:
`Page<History> + {classId,readonly,asOf,timeZone}`.
History chứa `sessionId,enrollmentId,rootSessionId,title,startsAt,endsAt,
sessionStatus,attendanceStatus,attendanceApplicability,excluded,effectiveMentor,
assignmentType,makeupForSessionId,makeupRootSessionId,makeupPlacementId,
creditSessionId,creditedAttendanceStatus`.
attendanceStatus nullable; creditedAttendanceStatus PRESENT/ABSENT/null;
applicability = ELIGIBLE / NOT_STARTED / NOT_ELIGIBLE / PAYMENT_PENDING /
LEGACY_NO_DATA / MAKEUP_PENDING / MAKEUP_CREDITED.

`GET .../students/:studentId/attendance-summary?from&to`:
`Counts + {classId,readonly,asOf,timeZone,aggregationScope:'STUDENT_CLASS_HISTORY'}`.
Không có phân trang ở summary cá nhân. 404 `CLASS_STUDENT_NOT_FOUND` nếu không có lịch sử.

`GET mentor/classes/:classId/progress?unitId&page&pageSize`:
`Page<{enrollmentId,studentId,displayName,storedUnitCount,untrackedUnitCount,
invalidStoredUnitCount}> + ProgressMetadata`.

`GET .../students/:studentId/progress?page&pageSize`:
`Page<{enrollmentId,classUnitId,trackingStatus,status,progressPercent,completedAt,
dataQuality}> + ProgressMetadata`. trackingStatus STORED/UNTRACKED;
progressPercent là chuỗi decimal hoặc null; dataQuality VALID/INVALID_PERCENT/UNTRACKED.

`ProgressMetadata = {completionPolicy:'UNDEFINED',policyVersion:null,
assignmentSummary:{availability:'NOT_IMPLEMENTED',counts:null},readonly,asOf,timeZone}`.
**storedUnitCount không phải số unit hoàn thành**. Hiện số unit/buổi hiển thị và
trạng thái server; không tự tạo thanh % hoàn thành từ API progress.

Nguồn: `attendance/dtos/{attendance-report,mentor-attendance-report}.dto.ts`,
`attendance/services/mentor-attendance-reports.service.ts`,
`enrollments/dtos/stored-progress.dto.ts`, `attendance/domain/attendance-credit.ts`.

## 5. Điểm danh (MF3)

`GET class-sessions/:id/attendance?page&pageSize`:

```text
{session: SessionView + {permissions}, totals:{present,absent,unmarked,eligible},
 items:[{attendanceId,enrollmentId,entryType,makeupPlacementId,student:Person,
         status,checkedInAt,admittedAt}], page,pageSize,total,pendingPaymentCount}
```

- status = UNMARKED / PRESENT / ABSENT; entryType REGULAR / MAKEUP.
- MAKEUP định danh bằng makeupPlacementId, **không ghi vào records theo enrollmentId**.
  checkedInAt nullable, admittedAt timestamp; totals là toàn roster, gồm khách học bù.
- permissions có canStart, canEditAttendance, canFinalize, canSyncRoster,
  canRecover, canViewAttendanceAudits. Mentor không có quyền recovery/audit staff.
- Roster thật rỗng trước start. `GET .../attendance-candidates?page&pageSize`
  trả `Page<{enrollmentId,student,entryType,makeupPlacementId}> + {provisional:true,asOf}`,
  chỉ xem trước; start kiểm tra lại điều kiện.

Mọi lệnh dưới cần `Idempotency-Key: UUID v4`, body có `expectedVersion >= 1`.
Mentor không gửi actualStartedAt/actualEndedAt (chỉ staff được cung cấp mốc hồi phục).

| Method/path sau `class-sessions/:id` | Body thêm |
| --- | --- |
| POST start | không |
| PUT attendance | `records:[{enrollmentId,status}]`, `guestRecords?:[{makeupPlacementId,status}]` |
| PUT attendance/bulk | `checked: boolean` (toàn roster, mọi trang, cả khách) |
| POST attendance/sync-roster | không |
| POST finalize | không |

`records` bắt buộc có, tối đa 100; guestRecords tối đa 100; tổng ít nhất một dòng.
Chia batch bảo thủ tối đa 100 dòng cả hai nhóm, gửi tuần tự với version response trước.
Chỉ gửi diff đã thay đổi. Response ghi:
`{session,totals,changedEnrollmentIds:UUID[],changedMakeupPlacementIds:UUID[]}`.
Không trả items; tải lại roster sau lệnh thành công để đồng bộ trạng thái.

Retry mất mạng giữ nguyên key + body; thao tác mới key mới. Không tạo version bằng
cách cộng 1: một lệnh no-op có thể không tăng version. Receipt cùng key/body trả lại
kết quả cũ, do đó phải đọc roster hiện tại sau khi retry thành công.

Start chỉ trong ngày dạy theo timezone server, lớp OPEN/IN_PROGRESS. Sửa trước
editableUntil (đúng bằng hạn là hết hạn). Finalize đổi UNMARKED thành ABSENT.
**Backend cho mentor sửa PRESENT/ABSENT của buổi COMPLETED trong hạn khi
canEditAttendance=true. Chốt không đồng nghĩa khoá vĩnh viễn.** Buổi đã chốt không
được đưa về UNMARKED; canFinalize/canSyncRoster có thể false dù vẫn được sửa.

| Status/code | Xử lý |
| --- | --- |
| 409 SESSION_VERSION_CONFLICT | Giữ cảnh báo bản nháp, tải roster mới; người dùng xem lại trước lệnh mới |
| 409 IDEMPOTENCY_KEY_REUSED | Báo lỗi thao tác; không tự tạo key để gửi lại |
| 409 SESSION_STATE_CONFLICT | Tải lại buổi và permissions |
| 409 ATTENDANCE_START_DAY_CLOSED | Không bắt đầu; liên hệ quản lý |
| 409 ATTENDANCE_EDIT_WINDOW_EXPIRED | Hết hạn; tải lại quyền, chỉ xem |
| 403 SESSION_ASSIGNMENT_REQUIRED | Mất quyền; đóng sheet, làm mới lịch |
| 422 ATTENDANCE_ENROLLMENT_NOT_ELIGIBLE | Roster thay đổi; tải lại trước khi ghi |
| 0 lỗi mạng/timeout | Cho retry cùng IdempotentCall; không báo thành công |

Các lỗi khác giữ status/code/requestId và dùng lỗi chung; không so message.
Nguồn: `attendance/controllers/attendance.controller.ts`,
`attendance/dtos/{attendance,attendance-input}.dto.ts`,
`attendance/services/attendance.service.ts` (authorize/permissions/assertWritable),
`attendance/domain/attendance-window.ts`.

## 6. Tài liệu (MF5)

| Endpoint sau `mentor/classes/:classId/` | Input/response |
| --- | --- |
| GET units/:unitId/materials | query page,pageSize,reviewStatus?,contentType? → Page<Material> |
| POST units/:unitId/materials | CreateMaterial → MaterialDetail (201) |
| GET materials/:mid | MaterialDetail |
| PATCH materials/:mid | expectedRevision + trường thay đổi → MaterialDetail |
| DELETE materials/:mid | query expectedRevision → 204 |
| POST materials/:mid/submit | `{expectedRevision}` → MaterialDetail |
| GET materials/:mid/preview | query expectedRevision → FileAccess (binary chính) |
| GET materials/:mid/assets/:fileId/access | query expectedRevision → FileAccess |
| POST materials/:mid/files/:fileId/access | không body → FileAccess |

Material = `{id,courseUnitId,contentType,title,description,sortOrder,availableAt,
sessionId,createdBy,createdInClassId,revision,reviewStatus,approvedRevision,
reviewedBy,reviewedAt,firstApprovedAt,rejectionReason,publishedAt,createdAt,
updatedAt,canEdit,file}`. Các trường mô tả/mốc duyệt/session/nguồn lớp nullable;
file nullable cho ARTICLE. FileSummary = `{id,originalFilename,mimeType,sizeBytes,kind}`.
MaterialDetail thêm `{contentHtml,contentSchemaVersion,inlineImages,attachments}`.

- contentType ARTICLE / FILE / VIDEO (ảnh dùng FILE + file.kind=IMAGE).
- reviewStatus DRAFT / PENDING_REVIEW / APPROVED / REJECTED. **Không có PUBLISHED enum**;
  xuất bản thể hiện bằng publishedAt. Endpoint list chỉ trả nội dung published và
  các submission của chính mentor theo quyền backend; APPROVED không đồng nghĩa published.
- CreateMaterial: contentType, title 1..250; tùy chọn description (nullable, <=5000),
  sortOrder 0..2147483647, availableAt nullable timestamp, sessionId nullable UUID,
  attachmentFileIds (<=50 UUID khác nhau), contentSchemaVersion=1.
- FILE/VIDEO phải có fileId READY, không contentHtml/contentText.
  ARTICLE không fileId, đúng một trong contentHtml hoặc contentText, tối đa 48 KiB UTF-8;
  detail trả canonical sanitized HTML, ảnh inline qua data-file-id, không URL cố định.
- PATCH không đổi contentType/contentSchemaVersion; dùng canEdit và quyền backend.
  Mentor chỉ sửa/xoá nháp hoặc bị từ chối của mình, chưa từng được duyệt.
- FileAccess = `{materialId,fileId,role:'PRIMARY'|'INLINE_IMAGE'|'ATTACHMENT',revision,
  url,expiresAt}`. TTL tối đa 60 giây; preview **không trả nội dung bài viết**.
  Bài viết lấy contentHtml từ detail. Không yêu cầu preview khi ARTICLE không file chính.
- 409 MATERIAL_REVIEW_CONFLICT: đọc lại revision; 403 MATERIAL_ACCESS_DENIED;
  404 MATERIAL_NOT_FOUND; 422 MATERIAL_CONTENT_INVALID/MATERIAL_SCOPE_MISMATCH;
  413 MATERIAL_CONTENT_TOO_LARGE. File chưa sẵn sàng dùng FILE_NOT_READY.

Nguồn: `materials/controllers/mentor-materials.controller.ts`,
`materials/dtos/{manager-material-input,manager-material,material-file-access}.dto.ts`,
`materials/domain/material-contract.ts`.

## 7. Upload file (MF5)

1. `POST files/upload-intents` body `{courseUnitId,classId,classUnitId,
   originalFilename,declaredMimeType,declaredSizeBytes}`. Mentor cần cặp classId/classUnitId
   khớp courseUnitId. Filename 1..250, không slash/control, không khoảng trắng hai đầu;
   MIME 1..150; size nguyên >0. Trả 201 `{fileId,uploadUrl,requiredHeaders,
   uploadUrlExpiresAt,intentExpiresAt}`.
2. PUT bytes thẳng uploadUrl, đúng requiredHeaders (hiện content-type), dùng Dio riêng
   không cookie/Origin/baseUrl/auth interceptor. Hiện tiến độ, cho hủy.
3. `POST files/:fileId/complete` body `{}` (không checksum/key tự chọn).
   202 đang xử lý, 200 nếu READY. Mất response: GET trước khi complete lại.
4. `GET files/:fileId`: `{id,status,originalFilename,courseUnitId,declaredSizeBytes,
   sizeBytes,mimeType,kind,intentExpiresAt,readyAt,metadataStatus,errorCode}`.
   status PENDING_UPLOAD / PROCESSING / READY / FAILED / DELETED. sizeBytes/mimeType/kind
   có thể null trước READY. Poll 2 giây, tối đa 2 phút là lựa chọn UI, không quy tắc backend.
5. Chỉ READY mới tạo material nháp, gửi duyệt là một thao tác riêng.

Allowlist source `files/domain/file-upload-policy.ts`:

| Extension | MIME | Tối đa |
| --- | --- | --- |
| pdf | application/pdf | 25 MiB |
| png, jpg/jpeg | image/png, image/jpeg | 25 MiB |
| docx, pptx, xlsx | MIME OpenXML tương ứng | 25 MiB |
| mp3 | audio/mpeg | 25 MiB |
| mp4 | video/mp4 | 200 MiB |
| txt/md/csv/json/js/ts/py/java/c/cpp/h/css/sql | text/plain, text/markdown, text/csv, application/json, text/javascript, application/javascript, text/css (nhóm source allowlist) | 25 MiB |

PUT TTL mặc định 600s (config 30..600), intent 1800s (config 600..3600), GET tối đa 60s.
**Luôn dùng expiresAt response**, không hardcode thời điểm hết hạn.
Lỗi: 409 UPLOAD_EXPIRED/FILE_NOT_READY; 404 FILE_NOT_FOUND; 422 MATERIAL_CONTENT_INVALID;
429 FILE_UPLOAD_QUOTA_EXCEEDED; 503 FILE_STORAGE_DISABLED/FILE_STORAGE_UNAVAILABLE.
Không có API xóa file mồ côi dành mobile; không tạo material khi upload chưa thành công,
không tuyên bố app có thể dọn mọi intent lỗi. Backend chịu lifecycle cleanup.

Nguồn: `files/controllers/files.controller.ts`, `files/dtos/*.ts`,
`files/services/{files,file-upload-policy}.service.ts`, `config/environment.schema.ts`.

## 8. Thông báo (MF2)

`GET notifications?limit&cursor&unreadOnly` dùng **cursor**, không page/pageSize.
limit 1..100 mặc định 20; cursor opaque <=2048; unreadOnly boolean.
Trả `{data:Notification[],meta:{hasMore:boolean,nextCursor:string|null}}`.
Chỉ tải tiếp nếu hasMore; kiểm tra cursor không lặp, không đổi unreadOnly giữa chuỗi trang.

Notification = `{id,type:'CHAT_MESSAGE',actorId,conversationId,messageId,title,body,
data:{conversationId,messageId},readAt:string|null,createdAt}`.
Không có thông báo phân công dạy thay/tài liệu được duyệt; thẻ dạy thay lấy từ lịch.

- `GET notifications/unread-count` → `{unreadCount:integer>=0}`.
- `PATCH notifications/:id/read` không body → Notification mới từ server.
- `POST notifications/read-all` không body → `{readAt,resyncRequired:true}`;
  tải lại count/list vì thông báo đến sau snapshot vẫn có thể chưa đọc.
- Chat tắt: 503 theo ChatAccessService (hoặc 404 deployment không có module), ẩn badge
  và giải thích chưa có thông báo. Các lỗi khác không được nuốt thành danh sách rỗng.
- Refresh badge khi Home mở/foreground và 60s/lần khi Home đang hiện;
  hủy timer khi rời màn/background/dispose; không poll lúc màn con đang mở.

Nguồn: `chat/controllers/notifications.controller.ts`, `chat/dtos/chat.dto.ts`,
`chat/services/chat-notifications.service.ts`.

## 9. Điểm còn cần owner/UAT

Contract source đã đọc, **chưa kiểm chứng server dev**. Dataset và phép kiểm tra thực tế
theo `MENTOR_TEST_DATA.md`; không đưa mật khẩu/link ký vào tài liệu.
Owner đã ủy quyền tự quyết các phần sau trong chat 02/11. Lựa chọn đã ghi trong
REMAINING_WORK_PLAN.md: map chip đúng lifecycle, Cần chú ý khi rate khác null và <80%,
Đăng ký giữ hệ Học viên, làm MF7. Đây là lựa chọn theo ủy quyền, chưa phải UAT live.
