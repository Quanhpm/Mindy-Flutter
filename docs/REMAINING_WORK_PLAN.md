# Kế hoạch hoàn thiện toàn bộ MindyFlutter

Ngày lập: **02/11/2026**. Một file duy nhất để làm hết phần còn lại: sửa lỗi nền, toàn bộ chức năng **Mentor**, các phần **Học viên** chưa giống bản React Native, và chuẩn bị phát hành.

**Ủy quyền mới của owner (02/11/2026, trong chat):** “các phần sau bạn cứ tự làm
đừng hỏi j nữa ... tự quyết định đi, sai thì tôi sửa sau”. Áp dụng từ MF2:
agent tự đối chiếu UI, quyết định chi tiết còn mở và tiếp tục API/kiểm tra, không
chờ từng vòng hỏi duyệt. Giữ ảnh và nhật ký để owner xem sau; không coi UAT thật,
server dev hay phát hành có chữ ký là đã xong nếu chưa có bằng chứng thực thi.

Các lựa chọn theo ủy quyền: chip lớp IN_PROGRESS = Đang dạy, OPEN/DRAFT = Sắp mở,
COMPLETED = Đã kết thúc, CANCELLED có nhãn riêng; Cần chú ý khi rate khác null và
<80%; Đăng ký giữ hệ Học viên; dự kiến làm MF7 (nghỉ/dạy bù, ghi chú, link họp),
không mở rộng sang toàn bộ assignments/chat ngoài plan.

Tài liệu liên quan (giữ để tra cứu, plan này là nguồn chính khi làm):

- `docs/MENTOR_PLAN.md`: phân tích thiết kế Mentor, 5 quyết định của owner, chỗ lệch backend.
- `docs/MANAGER_PLAN.md`: scope Manager mới được owner yêu cầu lập plan sau khi push Mentor; MG0–MG7 và backlog MGX.
- `docs/FLUTTER_RN_PARITY_REVIEW_2026-11-02.md`: review đối chiếu Flutter/RN, có 4 lỗi đã tái hiện.
- `docs/design/mentor/*.png`: ảnh các màn thiết kế Mentor.
- `../MindyMobile/docs/FLUTTER_MIGRATION_PLAN.md`: plan clone phần Học viên.

---

## 0. Hiện trạng (02/11/2026)

| Hạng mục | Trạng thái |
| --- | --- |
| Nền app: network/cookie/refresh, session, router, i18n, theme | P0 đã sửa 2 lỗi P1, test hồi quy pass |
| Học viên: auth, home, catalog, giỏ, thanh toán, lịch, tài khoản, lớp của tôi | S1–S5 đã có code; S2–S4 tự review/test, chờ UAT dev/thiết bị |
| Mentor MF1: login chung, phân luồng role, UI kit staff, Home khung, tiện ích yêu thích | P0 đã sửa 2 lỗi P2, test hồi quy pass |
| Mentor MF2: lịch, Home, phòng, dạy thay, thông báo | UI/API; Flutter đọc lịch/context backend local pass; UAT thiết bị/thông báo/dev còn thiếu |
| Mentor MF3: điểm danh | UI/API/controller; start/save/finalize backend local pass; UAT hai thiết bị còn thiếu |
| Mentor MF4: lớp, học viên, báo cáo | UI/API; workspace HTTP và provider local pass; UAT dữ liệu lớn/thiết bị còn thiếu |
| Mentor MF5: tài liệu, tải lên | UI/API, test và UAT local PDF/MinIO/iOS picker; còn thiết bị Android/nhiều loại file/server dev |
| Mentor MF6: hoàn thiện | Đã sửa vòng đời/quyền/trợ năng, có checklist và smoke backend local; UAT thiết bị còn thiếu |
| Build | Analyze sạch, 248 test pass + 1 live skip; APK debug/iOS Simulator build pass; UAT/signing chưa đủ |

Cập nhật triển khai 02/11: P0 đã sửa B1–B4, chuyển ca chẩn đoán vào
`test/p0_regression_test.dart` và bổ sung ca response/cookie cũ, refresh đồng thời,
refresh thất bại sau đổi phiên. `bash tool/check.sh`: analyze sạch, **31 test pass**.
Chưa chạy lại UAT đăng nhập trên thiết bị thật. `check.sh` nay dừng ngay khi một bước lỗi.
MF0 đã có `docs/API_CONTRACT_MENTOR.md` và `docs/MENTOR_TEST_DATA.md`;
dataset live và kiểm tra MinIO/chat chưa hoàn tất; các lựa chọn còn mở đã quyết định theo ủy quyền ở đầu plan.

Quyết định của owner (02/11): **gộp một app** theo role; **Login dùng chung**, Học viên vẫn có Đăng ký; **bỏ Mở chương**; **ẩn Google + Quên mật khẩu**; **điểm danh theo backend** (3 trạng thái + Bắt đầu buổi).

---

## 1. Cách làm mỗi phase

Trước khi code đọc `docs/codeRule.md` (quy tắc code) và `docs/UI.md` (hệ thiết kế, component, trạng thái màn). Xong việc cập nhật trạng thái màn ở `UI.md` mục 6.

Giữ quy trình như bản RN để owner nghiệm thu được:

1. **Đặc tả ngắn** trong mục phase ở file này: màn, API, quy tắc, tiêu chí nghiệm thu (đã viết sẵn bên dưới; bổ sung nếu phát hiện thiếu).
2. **UI với fixture**: dựng màn bằng dữ liệu mẫu (chỉ bật ở bản debug), đối chiếu ảnh thiết kế ở 320×640 và chữ ×1,3.
3. Theo ủy quyền mới: agent **tự review UI**, lưu ảnh/sai khác rồi tiếp tục API; không hỏi duyệt lại.
4. **Gắn API thật**, theo đúng contract ở mục 3 (MF0 xác minh lại từ source backend).
5. **Test**: unit cho logic, widget cho màn; chạy `bash tool/check.sh` (analyze + test) phải sạch.
6. **Ghi tiến độ**: đánh dấu checklist ở mục 14 của file này, ghi ngày + ghi chú giới hạn.
7. **Owner UAT** cuối phase; owner xác nhận đạt thì phase mới Done.

Quy ước code giữ như hiện tại: mỗi feature một thư mục theo khuôn `*_models.dart` → `*_api.dart` → `*_providers.dart` → `*_screen.dart`; màu/chữ/icon staff lấy từ `core/ui/staff/`; text qua `t('key')` (thêm key vào cả `vi.json` và `en.json`); mutation điểm danh dùng `IdempotentCall`; không retry tự động mutation; không optimistic update.

Thêm package mới phải ghi lý do vào mục 15 (thay cho ADR) trước khi `flutter pub add`.

---

## 2. Phase P0: sửa lỗi nền (làm trước tiên)

Ước lượng **1–1,5 ngày công**. Nguồn: review ngày 02/11. Test chẩn đoán của reviewer nằm ở `.dart_tool/review/parity_review_test.dart`; chuyển các ca này vào `test/` để giữ hồi quy.

| # | Mức | Lỗi | Cách sửa | File |
| --- | --- | --- | --- | --- |
| B1 | P1 | Request của phiên cũ gặp 401 sau khi đổi tài khoản vẫn được gửi lại bằng cookie phiên mới | Tách **`sessionEpoch`** (đổi khi login/logout/đổi user) khỏi **`refreshGeneration`** (đổi khi refresh). Gắn `sessionEpoch` vào `extra` lúc gửi. Khi 401: chỉ refresh + retry nếu `extra.sessionEpoch == sessionEpoch` hiện tại; khác thì trả `SESSION_CHANGED`, không gửi lại. Response về muộn của phiên cũ bị bỏ ở tầng provider (đã watch `sessionEpochProvider`). | `core/network/api_client.dart` |
| B2 | P1 | Access token hết hạn, refresh thành công nhưng bootstrap kẹt ở splash | Bootstrap so `sessionEpoch` (không so refresh generation). `SessionController._accept` tăng `sessionEpoch` của `ApiClient`. | `core/session/session_controller.dart`, `api_client.dart` |
| B3 | P2 | Suy sai "mentor chỉ dạy thay" vì `GET mentor/classes` mặc định `assignment=ANY` | Gọi `GET mentor/classes?assignment=PRIMARY&page=1&pageSize=1`; `total == 0` thì là chỉ-dạy-thay | `features/mentor/mentor_providers.dart` |
| B4 | P2 | Trang Tất cả tiện ích báo assertion ListTile/Material | Bọc nội dung `GlassCard` chứa `ListTile` bằng `Material(type: MaterialType.transparency)`; tương tự cho mọi danh sách ListTile trong `StaffPage` | `features/mentor/mentor_pages.dart`, `core/ui/staff/staff_widgets.dart` |

Tiêu chí xong: 4 ca test chẩn đoán chuyển từ fail sang pass; analyze sạch; test cũ vẫn pass; đăng nhập Học viên/Mentor, thoát app, mở lại vẫn vào thẳng (khi token hết hạn nhưng refresh còn hạn).

---

## 3. Phase MF0: chốt contract Mentor và dữ liệu test

Ước lượng **1–2 ngày công**, làm song song P0.

### 3.1. Viết `docs/API_CONTRACT_MENTOR.md`

Lấy từ source `Mindy-BE` (controller + DTO) và schema web `Mindy-FE2/src/features/mentor/schemas/{mentor-contracts,workspace-contracts}.ts`. Contract trong MindyMobile đã cũ (còn route Mở chương), **không dùng làm nguồn**. Ghi đủ request/response/lỗi cho:

| Nhóm | Endpoint | Ghi chú đã biết |
| --- | --- | --- |
| Lịch | `GET mentor/schedule?from&to&classId&page&pageSize` | `{items: SessionView[], page, pageSize, total, from, to, timeZone, asOf}`; tối đa 93 ngày; gồm PRIMARY và SUBSTITUTE |
| Buổi | `GET class-sessions/:id/context` | `{session, roomName, meetingUrl, accessScope}`; `meetingUrl` của buổi, không có thì của lớp |
| Lớp | `GET mentor/classes?assignment=PRIMARY\|SUBSTITUTE\|ANY&status&page&pageSize` | `MentorClassDto` = ClassDto + `assignmentType`, `accessScope` (`CLASS`/`SESSION`), `status` |
| Không gian lớp | `GET mentor/classes/:id`, `/sessions`, `/progress`, `/students/:studentId/progress`, `GET mentor/classes/:id/units[/:unitId[/sessions]]` | Workspace có `course`, `capabilities`, `readonly`, `visibleUnitCount`, `visibleSessionCount`, `timeZone` |
| Học viên | `GET mentor/classes/:id/students?paymentType&orderStatus&page&pageSize` | `enrollmentId, enrollmentStatus, studentId, studentName, orderStatus, paymentType, paidAt…` |
| Chuyên cần | `GET mentor/classes/:id/attendance-summary`, `GET mentor/classes/:id/students/:studentId/attendance[-summary]` | Mỗi enrollment có `present/absent/unmarked/excluded/rate` |
| Điểm danh | `GET class-sessions/:id/attendance`, `POST …/start`, `PUT …/attendance`, `PUT …/attendance/bulk`, `POST …/attendance/sync-roster`, `POST …/finalize` | Mutation cần `Idempotency-Key` + `expectedVersion`; có `permissions` trong session |
| Tài liệu | `GET/POST mentor/classes/:id/units/:unitId/materials`, `GET/PATCH/DELETE mentor/classes/:id/materials/:mid`, `POST …/submit`, `GET …/preview`, `POST …/files/:fileId/access` | Mutation cần header `Origin` |
| File | `POST files/upload-intents`, `PUT uploadUrl` (MinIO), `POST files/:id/complete`, `GET files/:id` | Intent body: `courseUnitId, classId?, classUnitId?, originalFilename, declaredMimeType, declaredSizeBytes` |
| Thông báo | `GET notifications?unreadOnly`, `GET notifications/unread-count`, `PATCH notifications/:id/read`, `POST notifications/read-all` | Trả `{ data: [...] }` (khác chuẩn `items`); chỉ loại `CHAT_MESSAGE`; cần server bật `CHAT_ENABLED` |

Cần xác minh trong MF0 (chưa rõ từ lượt đọc nhanh): trường đầy đủ của `SessionView` (có tên lớp/mã lớp/phòng hay phải ghép từ `mentor/classes`); có tổng điểm danh theo từng buổi cho báo cáo không; body tạo material (`type`, `title`, `fileId`…); giới hạn dung lượng/MIME upload; trạng thái material (có `PUBLISHED` không).

### 3.2. Dữ liệu test (chuẩn bị trên server dev hoặc backend local)

- Seed sẵn có: `mentor.frontend@gmail.com`, `mentor.backend@gmail.com` (mật khẩu = `SEED_ACCOUNT_PASSWORD`), 3 lớp demo buổi thứ Ba/thứ Bảy, học viên `demo.html.01…20@example.com` đã ACTIVE.
- Cần thêm:
  - 1 mentor **chỉ dạy thay**: dùng `PATCH management/class-sessions/:id/mentor` gán dạy thay 1 buổi.
  - 1 buổi **đang diễn ra hôm nay**: dùng `PATCH management/class-sessions/:id/schedule` dời giờ.
  - Lớp có tài liệu đủ trạng thái Nháp/Chờ duyệt/Đã duyệt/Bị từ chối.
  - 1 học viên CASH chờ xác nhận (để test Đồng bộ sĩ số).
- Hỏi owner: server dev đã bật `CHAT_ENABLED` chưa (ảnh hưởng chuông thông báo); MinIO dev có URL truy cập được từ máy ảo không (ảnh hưởng tải file).

### 3.3. Owner chốt thêm

1. Map chip lọc lớp: *Đang dạy* = `IN_PROGRESS` (+ `OPEN` đã có buổi?), *Sắp mở* = `OPEN`/`DRAFT`, *Đã kết thúc* = `COMPLETED`.
2. Ngưỡng **Cần chú ý** (thiết kế: chuyên cần < 80%) ghi vào business rule.
3. Có làm **MF7** (xin nghỉ/dạy bù, ghi chú giảng dạy, đổi link họp) hay không. Backend và web đã có, thiết kế mobile chưa có.

---

## 4. Mentor MF2: Home, Lịch dạy, Phòng học, Buổi dạy thay, Thông báo

Ước lượng **3–4 ngày công**. Ảnh: `mentor_home.png`, `mentor_pages_1.png` (Lịch dạy), `mentor_pages_4.png` (Buổi dạy thay).

### File mới

```text
lib/features/mentor/schedule/   schedule_models.dart (SessionView), schedule_api.dart,
                                schedule_providers.dart, schedule_screen.dart
lib/features/mentor/session/    session_context_api.dart, room_sheet.dart
lib/features/mentor/substitute/ substitute_screen.dart
lib/features/notifications/     notifications_models.dart, notifications_api.dart,
                                notifications_providers.dart, notifications_panel.dart
lib/core/ui/staff/day_strip.dart  (dải 7 ngày dùng chung)
```

### Việc cần làm

- [ ] **SessionView + API lịch**: đọc hết các trang trong khoảng; kiểm tra metadata trang như phần Học viên; hiển thị theo `timeZone` của response; tuần = thứ Hai 0h → thứ Hai tuần sau 0h theo `timeZone` (đã có `Dates.weekRange`).
- [ ] **Trạng thái buổi** (hàm thuần, có test): *Đang diễn ra* nếu `status=IN_PROGRESS` hoặc bây giờ nằm trong [start, end) và chưa COMPLETED/CANCELLED; *Sắp tới*; *Đã kết thúc*; *Đã huỷ*. Chip *Dạy thay* khi `assignmentType=SUBSTITUTE`.
- [ ] **Trang Lịch dạy (P1)**: header có dải 7 ngày (chấm ngày có buổi, ô hôm nay), nút tuần trước/sau (thiết kế chỉ có tuần hiện tại, thêm để dùng được), danh sách buổi của ngày chọn; nút **Điểm danh** (mở sheet MF3; ở MF2 tạm thông báo) và **Vào phòng** chỉ hiện khi buổi đang diễn ra; kéo để làm mới.
- [ ] **Thẻ buổi dạy trên Home**: buổi đang diễn ra, không có thì buổi tiếp theo trong hôm nay; giờ lớn "18:30 / đến 20:00", chip *Hôm nay*/*Dạy thay*, tên lớp, phòng, nút **Vào Google Meet** (chỉ khi `context.meetingUrl` có giá trị, mở ngoài app bằng `url_launcher`), "Xem lịch". Không có buổi: "Hôm nay bạn không có buổi dạy".
- [ ] **Thẻ thông báo dạy thay** trên Home (ảnh `mentor_home.png`): khi hôm nay có buổi SUBSTITUTE; nút đóng nhớ theo `sessionId`. Nguồn là `/mentor/schedule`, không phải thông báo backend.
- [ ] **Sheet Phòng học (S2)**: phòng, link học trực tuyến, **Sao chép** (Clipboard + toast), **Vào phòng học**. Lấy từ `class-sessions/:id/context`; 403 (đã bị thay mentor) thì báo và đóng sheet.
- [ ] **Trang Buổi dạy thay (P9)**: buổi `SUBSTITUTE` trong 30 ngày trước → 60 ngày tới, nhóm theo ngày, tên mentor chính, trạng thái *Sắp tới/Đã dạy*, nút khi đang diễn ra; ghi chú "chỉ vào phòng và điểm danh".
- [ ] **Thông báo (N)**: chuông có badge từ `unread-count` (gọi khi mở Home, khi app trở lại foreground, và 60 giây/lần lúc Home đang hiện); panel danh sách, chấm chưa đọc, chạm để đánh dấu đã đọc, "Đánh dấu đã đọc" tất cả. Server tắt chat (404/503) thì ẩn badge và hiện "Chưa có thông báo".
- [ ] Gỡ `MentorPlaceholderPage` cho `schedule`, `substitute`; tiện ích `room` mở sheet của buổi đang diễn ra (không có thì toast).

### Test

Unit: tuần theo timezone (kể cả `timeZone` khác máy), trạng thái buổi, lọc dạy thay, chọn buổi cho thẻ Home, parse `{data}` thông báo. Widget: Lịch dạy ngày có/không buổi, thẻ Home 3 trạng thái, sheet Phòng học có/không link.

### Xong khi

Lịch đúng giờ server với nhiều trang; nút Meet chỉ hiện khi có link; mentor chỉ-dạy-thay thấy đúng buổi được giao; badge chuông khớp server; UI khớp ảnh ở 320 px và chữ ×1,3.

---

## 5. Mentor MF3: Điểm danh

Ước lượng **3–4 ngày công**. Rủi ro cao nhất (ghi dữ liệu thật, đồng thời nhiều thiết bị). Ảnh: sheet điểm danh trong `mentor_pages_1.png`, Đồng bộ sĩ số trong `mentor_pages_4.png`.

### File mới

```text
lib/features/mentor/attendance/ attendance_models.dart, attendance_api.dart,
                                attendance_controller.dart, attendance_sheet.dart,
                                sync_roster_sheet.dart, finalize_sheet.dart
```

### Quy tắc backend phải giữ

- 3 trạng thái `UNMARKED / PRESENT / ABSENT`. Roster **rỗng tới khi `start`**; rỗng không có nghĩa là vắng.
- Mentor chỉ **bắt đầu được trong ngày học** (`ATTENDANCE_START_DAY_CLOSED` nếu quá ngày); sửa được tới `editableUntil` = 00:00 ngày học + 2 (`ATTENDANCE_EDIT_WINDOW_EXPIRED`).
- Mọi mutation: `IdempotentCall` mới cho mỗi lần bấm; lỗi mạng/timeout thì **gửi lại đúng call đó**; `SESSION_VERSION_CONFLICT` thì tải lại roster và báo người dùng; `IDEMPOTENCY_KEY_REUSED` coi là lỗi lập trình.
- `PUT attendance`: chỉ gửi dòng thay đổi, tối đa 100 dòng/lần; nhiều batch thì nối tiếp, mỗi batch dùng `session.version` mới nhất từ response trước.
- `finalize`: hiện tổng toàn roster để xác nhận; server đổi UNMARKED → ABSENT.
  Đối chiếu source MF0: mentor vẫn sửa PRESENT/ABSENT ở buổi COMPLETED trong hạn nếu
  `canEditAttendance=true`; không cho trở lại UNMARKED. Không tự khoá chỉ vì đã chốt.
- Dùng `session.permissions` (`canStart`, `canEditAttendance`, `canFinalize`, `canSyncRoster`) để bật/tắt nút; server vẫn là nơi quyết định.

### Việc cần làm

- [ ] Model roster (đọc hết các trang), `totals`, `pendingPaymentCount`, `permissions`, `editableUntil`.
- [ ] Controller giữ **bản nháp** thay đổi cục bộ; tính diff so với server; khoá nút khi đang gửi.
- [ ] **Sheet Điểm danh (S1)**: tiêu đề lớp · buổi; buổi chưa bắt đầu và `canStart` thì nút **Bắt đầu buổi**; lưới học viên (avatar chữ cái + tên + trạng thái), chạm để đổi Có mặt ↔ Vắng (UNMARKED hiện "Chưa điểm danh"); đếm có mặt/vắng/chưa; **Có mặt tất cả** (`bulk checked=true`); **Lưu điểm danh**; hiện hạn sửa; đóng sheet khi còn thay đổi chưa lưu thì hỏi lại.
- [ ] **Sheet Đồng bộ sĩ số (S3)**: hiện khi `pendingPaymentCount > 0` hoặc `canSyncRoster`; gọi `sync-roster`; hiện số người được thêm (`changedEnrollmentIds`).
- [ ] **Sheet Chốt buổi (S4)**: tổng có mặt/vắng/chưa; cảnh báo chưa đánh dấu sẽ tính vắng;
  gọi `finalize`; chỉ đọc khi không còn `canEditAttendance`, hiện hạn sửa nếu vẫn được sửa.
- [ ] Nối nút Điểm danh ở Lịch dạy, Buổi dạy thay, Chi tiết lớp (buổi hôm nay); tiện ích `sync` mở sheet của buổi đang diễn ra.
- [ ] Bảng map mã lỗi → câu tiếng Việt (mục 19.8 contract điểm danh).

### Test

Unit: diff + chia batch 100; version nối tiếp giữa các batch; retry giữ key + body; key mới cho lần bấm mới; xung đột version → tải lại; gating theo permissions; hết hạn sửa. Widget: sheet ở các trạng thái chưa bắt đầu / đang điểm danh / đã chốt / hết hạn.

### Xong khi

Không mất hay ghi đè điểm danh khi mất mạng giữa chừng hoặc 2 thiết bị cùng sửa (người sau nhận xung đột và tải lại); đủ các ca lỗi; mentor dạy thay điểm danh được buổi được giao.

---

## 6. Mentor MF4: Lớp phụ trách, Chi tiết lớp, Báo cáo điểm danh, Học viên

Ước lượng **3–4 ngày công**. Ảnh: `mentor_pages_1.png`, `mentor_pages_2.png`, `mentor_pages_4.png` (lọc học viên).

### File mới

```text
lib/features/mentor/classes/  classes_models.dart, classes_api.dart, classes_providers.dart,
                              classes_screen.dart, class_detail_screen.dart
lib/features/mentor/reports/  attendance_report_screen.dart
lib/features/mentor/students/ students_screen.dart, student_filter_sheet.dart, student_detail_sheet.dart
```

### Việc cần làm

- [ ] **Lớp phụ trách (P2)**: `GET mentor/classes?assignment=PRIMARY&status=…`; chip *Đang dạy (n) / Sắp mở (n) / Đã kết thúc (n)* theo map ở MF0; thẻ lớp: tên, mã, chip trạng thái, thanh tiến độ "Unit x/y" (từ `progress` hoặc workspace), lịch học trong tuần, phòng, sĩ số, buổi tới.
- [ ] **Chi tiết lớp (P3)**: workspace + `sessions`; thẻ tổng quan, "N học viên ›" mở trang Học viên, nút **Vào lớp học** (sheet Phòng học của buổi hôm nay; không có buổi hôm nay thì ẩn); tab *Sắp tới / Đã học* với hàng buổi (ô ngày, "Buổi n · Unit", giờ · phòng hoặc "x/y có mặt", trạng thái); chạm buổi hôm nay mở sheet Điểm danh.
- [ ] **Báo cáo điểm danh (P4)**: chip chọn lớp; 3 số *Chuyên cần TB / Buổi đã học / Lượt vắng* từ `attendance-summary`; danh sách từng buổi đã học với % có mặt. Nếu backend không có tổng theo buổi (MF0 xác minh) thì gọi `class-sessions/:id/attendance` cho các buổi đã chốt, tối đa 3 request song song, có cache.
- [ ] **Học viên (P5)**: ghép `students` với `rate` của `attendance-summary` theo `enrollmentId`; ô tìm kiếm; sheet lọc *Tất cả / Cần chú ý / Đi học đều* (bỏ *Bảo lưu*, backend không có); 3 số *Sĩ số / Chuyên cần TB / Cần chú ý*; hàng học viên có %, badge *Cần chú ý*; chạm mở sheet chi tiết (lịch sử điểm danh `students/:studentId/attendance` + tiến độ) thay cho toast của thiết kế.
- [ ] Mentor chỉ-dạy-thay: các trang này ẩn (đã có) và chặn nếu vào bằng đường dẫn.

### Xong khi

Số liệu khớp backend cho lớp có nhiều buổi/học viên; tìm/lọc đúng; lớp `readonly` (đã kết thúc) không cho thao tác ghi.

---

## 7. Mentor MF5: Tài liệu và Tải file lên

Ước lượng **4–5 ngày công**. Ảnh: `mentor_pages_2.png` (Tài liệu, Tải file bước 1), `mentor_pages_3.png` (bước 2).

### File mới

```text
lib/core/network/upload_client.dart        Dio riêng: PUT lên MinIO, không cookie/baseUrl, có % tiến độ
lib/features/mentor/materials/  materials_models.dart, materials_api.dart, materials_providers.dart,
                                materials_screen.dart, upload_screen.dart, upload_controller.dart
```

Package mới: `file_picker` (chọn PDF/DOCX/PPTX/MP4/JPG/PNG).

### Việc cần làm

- [ ] **Tài liệu (P6)**: chọn lớp (đếm tài liệu đã duyệt) → danh sách tài liệu đã duyệt nhóm theo Unit (mới nhất trước); chạm để xem: `preview` cho bài viết, `files/:fileId/access` lấy link ký 60 giây rồi mở bằng trình duyệt trong app; link hết hạn thì xin lại.
- [ ] **Tải file lên bước 1 (P7)**: chọn lớp chưa kết thúc, mỗi lớp có chip đếm theo trạng thái.
- [ ] **Bước 2**: khu tải lên 3 loại (*Tài liệu / Video / Hình ảnh*); chip lọc *Tất cả / Nháp / Chờ duyệt / Đã duyệt / Bị từ chối* có số; hàng file có loại, tên, Unit, dung lượng, trạng thái; file bị từ chối hiện lý do; **Gửi duyệt** từng file; **Gửi duyệt tất cả** khi có hơn 1 file Nháp/Bị từ chối; sửa mô tả (`PATCH`) và xoá nháp (`DELETE ?expectedRevision`).
- [ ] **Luồng tải lên** (controller có trạng thái, test kỹ):
  1. Chọn file, kiểm tra MIME + dung lượng phía app theo giới hạn backend.
  2. `POST files/upload-intents`.
  3. `PUT uploadUrl` với đúng `requiredHeaders`, hiện %; URL hết hạn (600 s) thì xin intent mới.
  4. `POST files/:id/complete`; mất response thì `GET files/:id` trước khi gọi lại.
  5. Đợi `READY` (`GET files/:id` theo chu kỳ 2 s, tối đa 2 phút; `FAILED` thì báo lỗi).
  6. `POST …/units/:unitId/materials` tạo bản Nháp.
  7. Người dùng bấm Gửi duyệt mới gọi `submit` với `expectedRevision`.
- [ ] Xung đột `expectedRevision` (409) thì tải lại tài liệu đó.

### Xong khi

Tải lên lỗi/hết hạn URL không để lại bản ghi rác; không gửi duyệt khi file chưa READY; mọi mutation có `Origin`; danh sách cập nhật đúng sau mỗi thao tác.

---

## 8. Mentor MF6: hoàn thiện và nghiệm thu

Ước lượng **2–3 ngày công**.

- [ ] Mọi màn có trạng thái loading / rỗng / lỗi + Thử lại, theo kiểu staff.
- [ ] Rà 320×640, chữ ×1,3, TalkBack/VoiceOver (nhãn nút icon, thứ tự đọc), giảm chuyển động.
- [ ] Bản tiếng Anh đủ key.
- [ ] Golden test cho các màn chính; test tích hợp 1 luồng: đăng nhập Mentor → lịch hôm nay → bắt đầu → điểm danh → chốt.
- [ ] Gỡ toàn bộ `MentorPlaceholderPage` và fixture khỏi bản release.
- [ ] Viết checklist UAT cho owner (dựa trên tiêu chí "Xong khi" của MF2–MF5) và chạy cùng owner trên máy ảo + máy thật.

---

## 9. Học viên: phần còn thiếu so với bản RN

Ước lượng **6–9 ngày công**. Có thể làm xen kẽ giữa các phase Mentor (độc lập với Mentor). Mỗi mục đối chiếu file RN ghi kèm trong code (`TODO(UI)`).

| Phase | Việc | Nguồn RN |
| --- | --- | --- |
| **S1 Home** (1,5–2 ngày) | Carousel giới thiệu (tự chạy, dừng khi app chạy nền/rời màn), khối Compiler (minh hoạ, chưa chạy code thật), "Về chúng tôi", footer; lớp khai giảng sớm nhất đọc **hết các trang** thay vì 100 lớp đầu | `home/components/HomeCarousel.tsx`, `HomeCompiler.tsx`, `StudentHome.tsx`, `home.service.ts` |
| **S2 Khoá học + giỏ** (2–2,5 ngày) | Carousel Gợi ý, phân trang số trang có "…", sheet khoá học (ảnh hero, mô tả Xem thêm/Thu gọn, tóm tắt lịch lớp từ `classes/:id`), giỏ có ảnh lớp và thanh tổng tiền cố định đáy, giới hạn 6 request song song khi tải lớp sớm nhất | `courses/*`, `cart/components/CartSheet.tsx` |
| **S3 Thanh toán** (1–1,5 ngày) | Sheet "Rời trang thanh toán?", thông tin chuyển khoản (chỉ bản không phải production), ticket mép xé bằng `CustomClipper` theo ảnh owner | `payment/PaymentScreen.tsx`, `PaymentResultTicket.tsx` |
| **S4 Học tập** (1,5–2 ngày) | Lớp của tôi: folder thu gọn/mở rộng + ảnh khoá; chi tiết buổi dùng `sessionDisplayStatus` + `useSessionTime` (buổi đã qua theo `endsAt`); sheet Người tham gia; Lịch học dạng timeline + header tháng; dùng `timeZone` từ response thay cho giờ VN cố định | `my-classes/*`, `schedule/ScheduleScreen.tsx` |
| **S5 Đăng ký** (0,5 ngày, cần owner) | Đổi màn Đăng ký sang giao diện staff cho đồng bộ với Login mới, hay giữ kiểu Học viên? | `auth/RegisterScreen.tsx` |

---

## 10. MF7 (đã làm theo ủy quyền owner)

Ước lượng **4–6 ngày công**. Backend và web Mindy-FE2 đã có; thiết kế mobile chưa có, cần thiết kế bổ sung.

- Xin nghỉ / dạy bù: `mentor/leave-requests` (`preview`, `makeup-slots`, tạo, danh sách, chi tiết, rút đơn). Tham chiếu `Mindy-FE2/src/features/mentor/components/mentor-leave-*.tsx`.
- Ghi chú giảng dạy: `GET/PUT class-sessions/:id/teaching-notes`.
- Đổi link họp của buổi: `PATCH mentor/class-sessions/:id/meeting-url`.
- Bài tập (assignments) và chat: lớn, nên tách plan riêng.

---

## 10b. Bài tập code — Học viên + Mentor (Phase 7, slice C6)

Kế hoạch tổng: `../../Mindy-BE/docs/implement_phase/phase 7/PHASE_7_CODE_ASSIGNMENTS.md` (slice C6).

Owner chốt 02/11/2026: ngôn ngữ JavaScript + Java; đề kiểu viết hàm (LeetCode); **có editor trên app**; điểm của bài = lần cao nhất;
lỗi biên dịch không tính lượt; không nhận nộp trễ; test ẩn chỉ hiện trạng thái + thời gian.

- [x] Model/API/provider (`lib/features/code_assignments/code_{models,api,providers}.dart`): kiểm id khớp request, điểm giữ chuỗi
      server, từ chối response lộ dữ liệu test ẩn; danh sách đọc hết trang; mentor đọc trang đầu bảng tổng hợp.
- [x] Học viên: danh sách bài trong Chi tiết lớp; màn đề; editor toàn màn hình (số dòng, thanh phím phụ, chọn ngôn ngữ, autosave nháp
      theo version, 409 thì cho tải bản mới, không ghi đè); Chạy thử / Nộp bài (Idempotency-Key, lỗi mạng gửi lại đúng yêu cầu);
      sheet kết quả; lịch sử nộp. Kết quả qua polling theo `retryAfterMs` (kẹp 1–5 s), dừng sau 60 s và cho làm mới tay.
- [x] Mentor: tổng hợp nộp bài của buổi (chỉ đọc) trong "Công cụ buổi dạy". Soạn đề, chấm lại, huỷ bài chỉ trên web.
- [x] Test `test/code_assignments_test.dart` (model, soạn code, API/idempotency, 3 widget test 320×640 chữ ×1,3).
- [ ] (02/11) Code C6 từng mất khỏi thư mục khi repo chuyển sang nhánh `flutter/manager-core`; đã ghép lại lên nhánh này, chưa commit.
- [ ] Owner chạy `bash tool/check.sh` (môi trường Claude không có Flutter SDK, code **chưa được analyze/test**); duyệt UI; UAT với BE thật.
- [x] Chạy thử với input tự nhập (02/11, giống web): sheet nhập từng tham số, chuỗi gõ thẳng, kiểm tra kiểu trước khi gửi `customArgs`.
- [ ] Tuỳ chọn sau: tô màu cú pháp (`re_editor` + `re_highlight`), render markdown đề bài, socket `code_submission.updated`.

## 11. Phát hành

Ước lượng **2–3 ngày công**.

- [x] Icon app + màn khởi động theo nhận diện Mindy; tên hiển thị (đang là "Mindy Flutter").
- [x] Chốt `applicationId` / bundle id: giữ `vn.mindy.mindy_flutter` để cài song song bản RN, hay thay bản RN (`com.mindymobile`, cần cùng id + chữ ký).
- [ ] `env/prod.json` có `API_URL`, `APP_ORIGIN` production (owner cung cấp; backend phải có origin này trong `CORS_ORIGINS`).
- [x] CI GitHub Actions (đã thêm workflow, chưa chạy remote): `flutter analyze`, `flutter test`, build APK; giống điều kiện merge của bản RN.
- [ ] Ký Android (keystore) và iOS (team, provisioning); bản thử nội bộ (APK / TestFlight).

---

## 12. Lộ trình và ước lượng tổng

| Thứ tự | Phase | Ngày công |
| --- | --- | --- |
| 1 | P0 sửa lỗi nền | 1–1,5 |
| 1 (song song) | MF0 contract + dữ liệu test | 1–2 |
| 2 | MF2 Home, Lịch dạy, Phòng học, Dạy thay, Thông báo | 3–4 |
| 3 | MF3 Điểm danh | 3–4 |
| 4 | MF4 Lớp, Báo cáo, Học viên | 3–4 |
| 4 (song song nếu 2 người) | MF5 Tài liệu, Tải lên | 4–5 |
| 5 | MF6 Hoàn thiện Mentor + UAT | 2–3 |
| xen kẽ | S1–S5 Học viên | 6–9 |
| 6 | Phát hành | 2–3 |
| tuỳ chọn | MF7 | 4–6 |

Tổng phần bắt buộc: **25–35,5 ngày công**, cộng dự phòng 20% thành **khoảng 30–43 ngày công (6–9 tuần, 1 dev)**. Có 2 dev thì một người làm Mentor, một người làm Học viên + phát hành: khoảng 4–5 tuần.

---

## 13. Rủi ro

| Rủi ro | Cách xử lý |
| --- | --- |
| Contract Mentor trong MindyMobile đã cũ | MF0 viết lại từ source backend + schema web; mọi model parse chặt bằng `Json` |
| Server dev tắt chat → không có thông báo | MF0 hỏi owner; app tự ẩn badge khi endpoint không khả dụng |
| MinIO dev không truy cập được từ máy ảo/điện thoại | MF0 thử sớm 1 lần tải file; nếu không được, test tải lên trên backend local |
| Ghi đè điểm danh khi nhiều thiết bị | `expectedVersion` + `Idempotency-Key`, test xung đột trong MF3 |
| Thiếu dữ liệu buổi "đang diễn ra" để test | MF0 dời giờ 1 buổi bằng API management |
| Nhiều công cụ AI cùng sửa repo | Mỗi phase làm trên nhánh git riêng; chỉ một công cụ sửa một lúc |

---

## 14. Checklist tổng (đánh dấu khi xong, ghi ngày)

- [ ] P0 — B1 B2 B3 B4 sửa xong, test hồi quy pass

  02/11: phần code + kiểm tra tự động đã đạt (31 test); chờ UAT thiết bị trước Done toàn phase.
- [ ] MF0 — `docs/API_CONTRACT_MENTOR.md`, dữ liệu test, owner chốt 3 điểm ở 3.3
- [ ] MF2 — UI duyệt · API gắn · test · UAT
- [ ] MF3 — UI duyệt · API gắn · test · UAT
- [ ] MF4 — UI duyệt · API gắn · test · UAT
- [ ] MF5 — UI duyệt · API gắn · test · UAT
- [ ] MF6 — hoàn thiện · UAT tổng Mentor
- [ ] S1 · S2 · S3 · S4 · S5 Học viên
- [ ] Phát hành — icon, id, env prod, CI, ký, bản thử nội bộ
- [ ] MF7 (nếu owner đồng ý)

---

## 15. Package đã thêm / dự kiến

| Package | Phase | Lý do |
| --- | --- | --- |
| `uuid` | MF1 (đã thêm) | Sinh `Idempotency-Key` cho điểm danh |
| Font Be Vietnam Pro, Material Symbols Rounded (asset) | MF1 (đã thêm) | Đúng thiết kế staff; xem `assets/fonts/FONTS-LICENSES.md` |
| `file_picker` | MF5 | Chọn file tài liệu/video/ảnh để tải lên |
| `re_editor`, `re_highlight` | C6 (hoãn) | Tô màu cú pháp JS/Java cho editor bài code. v1 dùng editor tự viết, chưa thêm package |

## Nhật ký triển khai tiếp — 02/11/2026

- P0: thêm ca queued request trước interceptor; `sessionEpoch` chụp đồng bộ lúc tạo lệnh.
- MF2: đã có UI, API/provider và router thật cho Home/Lịch/Dạy thay/Phòng/Thông báo;
  helper đọc hết trang kiểm tra tổng/ID, timezone từ server, context tối đa 3 đồng thời;
  cursor thông báo, lệnh đọc không optimistic/retry, timer dừng khi Home bị che hoặc app nền.
- Đã tự review ảnh tại `test/goldens/mf2_*.png`, preview debug `tool/mentor_preview.dart`;
  có ảnh iPhone Simulator, nguồn và sai khác trong `MF2_UI_REVIEW.md`.
- `bash tool/check.sh`: **No issues found, 67 test pass** (gồm 27 MF2 UI/model,
  7 API/provider và 1 vòng đời polling). Không coi đây là UAT server.
- Smoke dev chưa thực hiện: môi trường cục bộ không có `SEED_ACCOUNT_PASSWORD`.
  Không đoán mật khẩu, không lưu thông tin đăng nhập trong repo.
- Việc kế tiếp: MF3 điểm danh, rồi MF4/MF5; giữ các mục UAT live chưa đánh dấu Done.

### MF3 — bản triển khai 02/11

- Đã nối Start/mark/bulk/sync/finalize; roster hết trang, 3 trạng thái và khách MAKEUP.
- Bản nháp diff, batch 100, version từ response trước; snapshot sâu key/body, retry thủ công;
  ack rồi GET lỗi thì chỉ đọc lại. Giữ call trong RAM qua đóng/mở sheet, reset khi đổi phiên.
- 409 đọc lại + yêu cầu xem bản nháp; hạn sửa tính theo asOf server; 403/404 đóng sheet về lịch.
- UI đủ loading/rỗng/lỗi/disabled, cảnh báo rời nháp, xác nhận bulk/sync/chốt; vi/en và chữ ×1,3.
- Source/ảnh/bằng chứng: `MF3_REVIEW.md`, `test/goldens/mf3_attendance_320_vi.png`.
- Bổ sung tối ưu MF2: đổi ngày trong cùng tuần dùng chung cache tuần; trang Dạy thay chỉ lấy
  context cho các buổi SUBSTITUTE sau khi đọc lịch đầy đủ, không đọc phòng của hàng trăm buổi chính.
- Check toàn dự án: **94 test pass, analyze sạch**; build iOS Simulator ở nhánh MF3.
  Chưa coi các test này là UAT hai thiết bị/backend thật.
- Việc kế tiếp: MF4 lớp/chi tiết/báo cáo/học viên, MF5 tài liệu-upload, MF6, S1–S5,
  MF7 theo ủy quyền và phát hành. Tài khoản backend live/MinIO/signing vẫn cần bằng chứng riêng.

### MF4 — bản triển khai 02/11

- Đã có Lớp phụ trách, Chi tiết lớp, Báo cáo và Học viên, kèm tìm/lọc/chi tiết học viên.
- Số ghi danh từ server; Unit/buổi không suy diễn completion. Guard CLASS/PRIMARY
  trước dữ liệu riêng tư, skip context của buổi do mentor khác phụ trách.
- Tổng chuyên cần từ counts server, phân biệt lịch sử toàn lớp, ghi danh hiện tại
  và roster vật lý; null/mất quyền không hiện thành 0%. Roster tối đa 3 đồng thời.
- Chi tiết lớp dùng sheet điểm danh MF3; readonly khóa nút ghi; lịch sử dùng cache báo cáo.
- 9 test model/API/provider + 16 widget test; 9 golden đã tự review vi/en 320 chữ ×1,3.
- `bash tool/check.sh`: **119 test pass**, analyze sạch; iOS Simulator build **10 giây**.
- Chi tiết và các giới hạn UAT: `MF4_REVIEW.md`. Chưa đánh dấu Done server thật.
- Tiếp theo: MF5 Tài liệu/Tải lên, MF6, Học viên S1–S5, MF7 và phát hành.

### MF5 — tầng dữ liệu/upload 02/11 (đang làm)

- Đã có model/API/provider tài liệu, file intent/status/complete, PUT stream riêng.
- Upload READY mới tạo nháp; lost response của create chỉ reconcile theo fileId,
  không gửi lại POST không có idempotency. Retry/hủy/timeout/đổi phiên đã có test.
- Backend REJECTED phải sửa thành DRAFT trước submit; bulk sẽ chỉ gửi DRAFT, giữ bước
  sửa rõ ràng thay vì tự PATCH nội dung không đổi. APPROVED khác published.
- 18 test upload riêng đã pass; iOS build sau thêm file_picker/HTML core thành công.
- Chưa nối UI/material actions. Trạng thái và việc tiếp theo: `MF5_STATUS.md`.

### MF5 — UI và quản lý tài liệu 02/11

- Đã nối hai bước chọn lớp/tải file, Unit/category, native picker stream, metadata,
  progress/hủy/kiểm tra kết quả, viewer ARTICLE/file/ảnh inline/attachment.
- Gửi/sửa/xóa với expectedRevision, chặn readonly/owner/scope; bulk DRAFT tuần tự,
  REJECTED sửa trước. Unknown result chỉ GET, ack rồi reload lỗi không ghi lại.
- Đã có 10 golden vi/en 320 chữ ×1,3, bridge picker, API và luồng UI; native preview
  iPhone 17 build 22s. `MF5_REVIEW.md` ghi hành vi, bằng chứng và giới hạn.
- UAT backend/MinIO chưa có tài khoản; UI automation không thao tác picker thật vì
  Mac đang khóa. Không giả lập các gate này thành Done.
- Tiếp theo: MF6 rà hoàn thiện/UAT checklist, S1–S5, MF7 và chuẩn bị phát hành.

MF5 chốt code: **175 test pass**, analyze sạch. Editor conflict giữ input và yêu cầu
xem snapshot mới trước khi dùng revision mới; xem `MF5_REVIEW.md`.

### MF6 — hoàn thiện và kiểm thử local 02/11

- Gỡ MentorPlaceholderPage/chuông giả; route sai có lối về Home. Quyền đang tải,
  refresh hoặc lỗi không làm hiện tiện ích lớp chính, có thử lại.
- Sửa autoDispose khi mở tiện ích trực tiếp; nút Staff/Student có tap semantics;
  Skeleton có nhãn dịch, dừng ticker giảm chuyển động; yêu thích chụp user trước await.
- 14 test mới (12 regression/polish + 2 i18n), 2 golden mới và cập nhật Home dùng
  chuông thật; đã mở xem. Check thường **189 test pass**, analyze sạch.
- Main iOS Simulator build **8,3 giây**. Backend sibling build 32 migration artifact,
  7 test HTTP attendance/workspace pass trên PostgreSQL riêng.
- Luồng Flutter **state/API thật** → Nest/PostgreSQL riêng: login → lịch hôm nay →
  start → PRESENT → save → finalize → logout **pass**; chưa coi là native UI E2E.
- Bằng chứng/runner: `MF6_REVIEW.md`, `tool/live/run_mentor_smoke.mjs`.
  `MENTOR_UAT.md` ghi riêng gate thiết bị, nhiều loại file/picker Android, hai thiết bị,
  VoiceOver/TalkBack và server dev chưa hoàn tất. Không hỏi owner duyệt lại theo ủy quyền.

- Bổ sung UAT local MF5/MF6: **39 test HTTP file/material với MinIO thật pass**;
  Flutter UploadController → MinIO/worker → READY → DRAFT → signed download →
  submit PENDING_REVIEW cũng pass. iOS picker mở/hủy/chọn PDF tổng hợp đọc đúng
  880 B; ảnh `docs/design/mentor/review/mf6_ios_picker_selected.png`.
  Gate còn lại gồm Android/nhiều loại file, app nền, nhiều thiết bị và server dev.


### S1 — Home Học viên 02/11

- Đã có intro carousel, Compiler minh họa, About notes và footer; đọc đủ trang
  lớp để chọn khai giảng sớm nhất. Không tải metadata lần hai khi Home đã nhận null.
- Carousel dừng khi nền/route bị che/đang vuốt; có pause, giữ qua scroll, reduced
  motion/screen reader không tự chuyển. Dùng font monospace bundle và SVG check.
- 25 test S1 (5 data, 6 carousel, 14 widget), 9 golden đã tự review vi/en chữ lớn;
  preview iPhone 17 build 18,6 giây, đã thao tác pause/chọn note trên Simulator.
- Nguồn/sai khác/giới hạn trong `S1_REVIEW.md`. Intro/Compiler CTA disabled như RN
  production vì chưa có module đích; không biến mô phỏng thành chạy code thật.
- Tiếp theo: S2 catalog/course sheet/cart; S3–S5, MF7 và phát hành vẫn trong scope.

- S1 bổ sung refresh theo focus/foreground như RN, không tải khi Home bị che hoặc
  tải lặp lần đầu; có test đỏ→xanh.

S1 chốt code: **214 test pass**, 1 live test mặc định skip; analyze sạch; main
iOS Simulator build **12,0 giây**. Chưa đánh dấu nghiệm thu toàn bộ Học viên.


### Chỉ đạo mới của owner — code trước, test sau

Owner yêu cầu hoàn thiện toàn bộ phần thiếu, ưu tiên code S2–S5/MF7/phát hành,
gom test/ảnh/UAT ở cuối để tối ưu token. Tạm hoãn test đỏ→xanh và check toàn bộ
mỗi phase theo yêu cầu này; chỉ kiểm tra biên dịch cần thiết, không ghi code chưa
test thành đã nghiệm thu. Các gate production/signing vẫn phải có giá trị thật.


### S2–S5, MF7 và phát hành — chốt code 02/11

- Hoàn thiện toàn bộ mục code S2–S5/MF7 trong scope. `REMAINING_CODE_REVIEW.md`
  ghi thay đổi, nguồn backend, bảo vệ unknown/version/epoch và giới hạn dữ liệu.
- Gom kiểm tra sau code đúng yêu cầu: **248 test pass**, 1 live test skip;
  analyze sạch, 8 golden mới đã mở xem; sửa overflow thumbnail/sheet giỏ và nạp
  locale tháng được phát hiện trong lượt kiểm tra. APK debug/iOS Simulator pass.
- Phát hành: tên Mindy, mascot icon/splash, giữ ID cài song song RN, CI workflow,
  validate production và cấu hình signing. Hướng dẫn tại `RELEASE.md`.
- Chưa có URL/Origin production, keystore, Apple team/profile. Chưa chạy CI remote,
  TestFlight hay UAT MF7 backend/hai actor; các gate UAT cũ vẫn ghi ở `MENTOR_UAT.md`.
- Assignments và chat trực tiếp ngoài scope đã chốt; cần đợt chức năng riêng.
  Checklist tổng bao gồm UAT/phát hành vì vậy không tick toàn phase thành Done.


Lưu ý cuối lượt: workspace đang có thay đổi UI Học viên đồng thời theo
`STUDENT_UI_PARITY_PLAN.md`. Kết quả 248 test/analyze sạch là mốc trước lượt UI mới;
không commit/restore file của luồng đó. Build main cuối APK/iOS pass 17,0/19,9 giây;
3 lint cuối nằm ở `learning_layout.dart` mới. Xem ghi chú cuối review.


### Kiểm tra trước đưa lên main — 02/11

Owner yêu cầu push lên main. Nhánh tích hợp Mentor MF2–MF7 và UI Học viên đã chạy
`bash tool/check.sh`: analyze sạch, **275 test pass**, 1 live test skip. Không coi
push source là phát hành store; các gate UAT thực tế/signing nêu trên giữ nguyên.
Bỏ qua `test/failures/` và env/keystore local khi commit.


### Mở đợt Manager — lập kế hoạch 02/11

Owner yêu cầu lập plan sau khi đối chiếu web. Đã viết `MANAGER_PLAN.md`: cùng app,
Login/role/shell, Home → duyệt nghỉ/dạy bù → tài liệu/review/upload → CASH → kiểm tra
và UAT. Điều phối Mentor/chuyên cần/xếp học bù học viên nằm backlog MGX riêng.
Đã cập nhật `UI.md` mục 6.4; chưa code, chưa bật quyền MANAGER và chưa chạy UAT.
Kế thừa chỉ đạo tự quyết và code trước/test gom sau; không push main tự động.


### Thực hiện toàn bộ Manager — 02/11

Owner mở scope MG0–MG7 **và MGX1–MGX4**. Đã triển khai trong cùng app: login/guard
Manager, Home/tiện ích/tài khoản, duyệt nghỉ/dạy bù, tài liệu review/publish và
soạn/upload, CASH, tra cứu người/lớp/lịch, phân công primary/substitute, chuyên cần
chỉ đọc/audit và xếp/hủy học bù học viên. Contract và dữ liệu tại
`API_CONTRACT_MANAGER.md`, `MANAGER_TEST_DATA.md`; bằng chứng cuối và gate tại
`MANAGER_REVIEW.md`. Không đổi backend/web, không tự push main.
