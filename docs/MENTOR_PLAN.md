# Kế hoạch Flutter cho role Mentor

Ngày lập: **02/11/2026**. Trạng thái: **owner đã chốt 5 quyết định (mục 0), đang làm MF1**.

Nguồn đã đọc:

- 3 thiết kế Claude Design trong `MINDY-BE/`: `Mentor Mobile UI.html` (app Mentor), `Login (1).html` (Login staff), `Thiết kế Home UI.html` (Home Quản lý). Đã render và đọc cả phần logic/dữ liệu mẫu bên trong. Ảnh chụp lưu tại `docs/design/mentor/`.
- Backend `Mindy-BE` (HEAD `37a9aa7`): các controller `mentor/*`, `class-sessions/*`, `files/*`, `notifications`, `auth`, cùng `docs/CORE_BUSINESS_LOGIC.md` và `docs/api_flow/*`.
- `MindyMobile/docs/API_CONTRACT/` (mentor-teaching, attendance, materials). **Lưu ý:** bộ contract này cũ hơn backend ở vài chỗ (xem mục 4).

Mục tiêu: thêm role **MENTOR** vào app `MindyFlutter` hiện có, đúng thiết kế Mentor, dùng API backend thật. App Quản lý **không thuộc phạm vi** plan này. Những phần dùng chung (Login staff, UI kit staff, thông báo) được làm theo cách để Quản lý dùng lại sau.

## 0. Quyết định của owner (02/11/2026)

| # | Câu hỏi | Quyết định |
| --- | --- | --- |
| 1 | App chung hay app Staff riêng | **Gộp chung** một app, phân luồng theo role |
| 2 | Login mới cho ai | **Dùng chung mọi role**; Học viên **vẫn có Đăng ký** |
| 3 | Mở chương | **Bỏ** (khớp backend) |
| 4 | Google + Quên mật khẩu | **Ẩn** tới khi backend có luồng mobile |
| 5 | Điểm danh | **Làm theo backend**: 3 trạng thái `UNMARKED/PRESENT/ABSENT` + bước Bắt đầu buổi |

Hệ quả: Login staff thay luôn Login Học viên; link cuối màn đổi thành "Chưa có tài khoản? Đăng ký". Tiện ích Mở chương, trang P8 và thông báo "chương sẽ mở" bị loại khỏi phạm vi.

## 1. Thiết kế Mentor gồm những gì

Thiết kế dùng một ngôn ngữ hình ảnh **khác hẳn app Học viên**:

| | App Học viên (đã có) | App Mentor / Quản lý (thiết kế mới) |
| --- | --- | --- |
| Font | Nunito | **Be Vietnam Pro** 400/500/600 |
| Icon | Bộ SVG nét tự vẽ | **Material Symbols Rounded** (wght 300, FILL 0/1) |
| Màu chính | forest `#1D5B57`, mint `#338A85`, action `#FF9973` | teal đậm `#123236 → #1f4f55 → #2b6a71`, nền `#f6f5f2`, nhấn `#c2410c` |
| Phong cách | Thẻ phẳng, bo lớn | Header gradient bo đáy 28px, thẻ kính mờ (glass), chip trạng thái màu nhạt |
| Điều hướng | Tab bar đáy 5 ô | **Không có tab bar**: Home + lưới "tiện ích" mở các trang con |
| Mascot | Mascot Mindy | Ếch Mindy (ảnh PNG nằm trong file thiết kế) |

### 1.1. Danh sách màn hình và sheet

| # | Màn / sheet | Nội dung chính |
| --- | --- | --- |
| H | **Home** | Avatar chữ cái, tên, email. Chuông thông báo kèm số chưa đọc. Thẻ "buổi tiếp theo/đang dạy" (giờ, lớp, phòng, chip *Hôm nay/Dạy thay*, nút **Vào Google Meet**, "Xem lịch"). **Tiện ích yêu thích** (3 cố định + tối đa 6, chế độ Sửa). Lưới **Tính năng gần đây**, **Tính năng mới** (badge MỚI, số đếm). |
| N | Popover **Thông báo** | Danh sách, chấm chưa đọc, "Đánh dấu đã đọc". |
| P1 | **Lịch dạy** | Dải 7 ngày trong tuần (chấm có buổi). Thẻ buổi: giờ, trạng thái (*Đang diễn ra/Sắp tới/Đã kết thúc*), chip *Dạy thay*. Nút **Điểm danh** + **Vào phòng** khi buổi đang diễn ra. |
| P2 | **Lớp phụ trách** | Chip lọc *Đang dạy/Sắp mở/Đã kết thúc* (kèm số). Thẻ lớp: tiến độ Unit x/y, lịch, phòng, sĩ số, buổi tới. |
| P3 | **Chi tiết lớp** | Thẻ tổng quan + tiến độ, "N học viên ›", nút **Vào lớp học**. Danh sách buổi chia tab *Sắp tới/Đã học*. Chạm buổi hôm nay thì mở sheet điểm danh. |
| P4 | **Báo cáo điểm danh** | Chip chọn lớp. 3 số: chuyên cần TB, buổi đã học, lượt vắng. Danh sách từng buổi với % có mặt. |
| P5 | **Học viên** | Ô tìm kiếm, sheet lọc (*Tất cả/Cần chú ý/Đi học đều/Bảo lưu*), chip lớp. 3 số: sĩ số, chuyên cần TB, cần chú ý. Từng dòng có % chuyên cần và badge. |
| P6 | **Tài liệu** | Chọn lớp, rồi xem danh sách tài liệu **đã duyệt** theo Unit. |
| P7 | **Tải file lên** | Bước 1: chọn lớp (đếm tài liệu theo trạng thái). Bước 2: khu tải lên (*Tài liệu/Video/Hình ảnh*), chip lọc trạng thái (*Nháp/Chờ duyệt/Đã duyệt/Bị từ chối*), nút **Gửi duyệt** từng file, **Gửi duyệt tất cả**, ghi chú lý do bị từ chối. |
| P8 | ~~Mở chương~~ | Bật/tắt khoá từng Unit. **Backend đã gỡ tính năng này** (xem mục 4). |
| P9 | **Buổi dạy thay** | Các buổi được phân công dạy thay, kèm tên mentor chính. Ghi chú: dạy thay chỉ được vào phòng và điểm danh. |
| P10 | **Tất cả tiện ích** | Tìm tiện ích, nhóm, gắn sao yêu thích. |
| S1 | Sheet **Điểm danh** | Lưới học viên, chạm để đổi Có mặt/Vắng, đếm, **Lưu điểm danh**. |
| S2 | Sheet **Phòng học** | Phòng, link học trực tuyến, Sao chép, **Vào phòng học**. |
| S3 | Sheet **Đồng bộ sĩ số** | Học viên mới ghi danh sẽ được thêm vào điểm danh buổi đang dạy. |
| S4 | Sheet **Chốt buổi học** | Cảnh báo: chưa đánh dấu sẽ tính vắng, sau khi chốt thì bị khoá. |
| S5 | Sheet **Lọc học viên** | Lọc theo trạng thái. |
| — | Toast | Thông báo ngắn ở đáy màn. |

**Chế độ "chỉ dạy thay"** (prop `mentorType = substitute` trong thiết kế): ẩn mọi tiện ích cần lớp chính (Lớp phụ trách, Điểm danh báo cáo, Học viên, Tài liệu, Tải file, Mở chương). Chỉ còn Lịch dạy, Buổi dạy thay, Phòng học, Điểm danh buổi được giao.

### 1.2. Login staff (`Login (1).html`)

Header teal + ếch, slogan "Khởi đầu nhỏ. Bứt phá lớn.", Email/Mật khẩu, **Ghi nhớ đăng nhập**, **Quên mật khẩu?**, **Tiếp tục với Google**, "Chưa có tài khoản? Liên hệ trung tâm". Không có Đăng ký. Logic mẫu: tài khoản quản lý vào Home Quản lý, còn lại vào Home Mentor.

## 2. Bản đồ màn hình ↔ API backend

Mọi mutation điểm danh cần header `Idempotency-Key` (UUID v4) và `expectedVersion` (= `session.version` mới nhất). Khi lỗi mạng thì retry **cùng key + cùng body**; mỗi thao tác mới dùng key mới. Gặp 409 `SESSION_VERSION_CONFLICT` thì tải lại roster.

| Màn | API | Ghi chú |
| --- | --- | --- |
| Login | `POST /auth/login`, `GET /auth/me` | Role `MENTOR` vào shell Mentor. **Hiện `SessionController.login` chặn mọi role ≠ STUDENT, phải sửa.** |
| Home – buổi tiếp theo | `GET /mentor/schedule?from&to` (hôm nay) + `GET /class-sessions/:id/context` | `context` trả `roomName`, `meetingUrl` (buổi ưu tiên, rồi tới lớp). Thẻ "Dạy thay hôm nay" suy từ `assignmentType=SUBSTITUTE`. |
| Thông báo | `GET /notifications`, `GET /notifications/unread-count`, `PATCH /notifications/:id/read`, `POST /notifications/read-all` | Backend hiện **chỉ có loại `CHAT_MESSAGE`** (xem mục 4). |
| Tiện ích yêu thích | — | Lưu cục bộ theo user (`shared_preferences`), không có API. |
| P1 Lịch dạy | `GET /mentor/schedule?from&to&page&pageSize` | SessionView: `status`, `startsAt/endsAt`, `primaryMentor`, `effectiveMentor`, `assignmentType`. Đọc hết các trang, hiển thị theo `timeZone` của response. |
| P2 Lớp phụ trách | `GET /mentor/classes?status&page&pageSize`, `GET /mentor/classes/:id/progress` | Lớp dạy thay theo buổi **không** nằm ở đây (xem qua schedule). |
| P3 Chi tiết lớp | `GET /mentor/classes/:id`, `GET /mentor/classes/:id/sessions`, `GET /mentor/classes/:id/units` | |
| P4 Báo cáo điểm danh | `GET /mentor/classes/:id/attendance-summary` | Có `present/absent/unmarked/rate`. Lịch sử từng học viên: `GET /mentor/classes/:id/students/:studentId/attendance(-summary)`. |
| P5 Học viên | `GET /mentor/classes/:id/students` + `GET /mentor/classes/:id/attendance-summary` | Ghép `rate` theo `enrollmentId`. Ngưỡng "Cần chú ý" (thiết kế dùng < 80%) và khái niệm "Bảo lưu" **chưa có ở backend**. |
| P6 Tài liệu | `GET /mentor/classes/:id/units`, `GET /mentor/classes/:id/units/:unitId/materials`, `GET .../materials/:materialId/preview`, `POST .../materials/:id/files/:fileId/access` | Lọc trạng thái đã duyệt. Mutation tài liệu cần header **`Origin`** hợp lệ (đã có trong `ApiClient`). |
| P7 Tải file lên | `POST /files/upload-intents` → **PUT `uploadUrl`** (MinIO, gửi đúng `requiredHeaders`) → `POST /files/:id/complete` → `GET /files/:id` (chờ READY) → `POST /mentor/classes/:id/units/:unitId/materials` → `POST .../materials/:id/submit` (`expectedRevision`) | Sửa/xoá nháp: `PATCH`/`DELETE .../materials/:id`. URL PUT hết hạn sau 600s, intent sau 1800s. PUT dùng Dio riêng (không cookie, không baseUrl). |
| P9 Buổi dạy thay | `GET /mentor/schedule` lọc `assignmentType=SUBSTITUTE` | |
| S1 Điểm danh | `GET /class-sessions/:id/attendance`, `POST .../start`, `PUT .../attendance` (chỉ các dòng đổi), `PUT .../attendance/bulk` (`checked: true/false` cho cả roster) | Có `permissions.canStart/canEditAttendance/canFinalize/canSyncRoster`. |
| S2 Phòng học | `GET /class-sessions/:id/context` | Mentor đang dạy có thể đổi link: `PATCH /mentor/class-sessions/:id/meeting-url` (thiết kế chưa có). |
| S3 Đồng bộ sĩ số | `POST /class-sessions/:id/attendance/sync-roster` | Chỉ khi buổi IN_PROGRESS và còn hạn sửa. |
| S4 Chốt buổi | `POST /class-sessions/:id/finalize` | Server đổi mọi `UNMARKED` thành `ABSENT`, buổi chuyển `COMPLETED`. |

## 3. Kiến trúc trong MindyFlutter

App vẫn là **một codebase**, phân nhánh theo role ở router:

```text
STUDENT → /home/...        (đã có)
MENTOR  → /mentor/...      (plan này)
MANAGER → /manager/...     (sau này, dùng lại Login + UI kit staff)
khác    → /welcome
```

```text
lib/
  core/
    session/                 # bỏ chặn role ≠ STUDENT; lưu role; "Ghi nhớ đăng nhập"
    network/idempotency.dart # Idempotency-Key: giữ key+body khi retry, key mới mỗi thao tác
    network/upload_client.dart # Dio riêng PUT lên MinIO, có tiến độ %
    ui/staff/                # UI kit staff: StaffTheme, StaffHeader (gradient), GlassCard,
                             # StatusChip, FilterChips, UtilityTile, StaffSheet, Toast, DayStrip
  features/
    auth/staff_login_screen.dart
    notifications/           # dùng chung Mentor/Học viên
    mentor/
      home/  schedule/  classes/  attendance/  students/
      materials/  upload/  substitute/  utilities/   # mỗi thư mục theo khuôn models/api/providers/screen
```

Package cần thêm (mỗi package cần ADR theo quy trình dự án):

| Package | Dùng cho |
| --- | --- |
| `material_symbols_icons` | Bộ icon Material Symbols Rounded đúng thiết kế |
| `file_picker` | Chọn file PDF/DOCX/PPTX/MP4/JPG/PNG để tải lên |
| `uuid` | Sinh `Idempotency-Key` |
| Font **Be Vietnam Pro** (TTF, OFL) | Bundle vào `assets/fonts/`. Flutter không dùng được woff2 trong file thiết kế, phải tải TTF từ Google Fonts. |

Ảnh ếch mascot: trích từ file thiết kế vào `assets/illustrations/`.

## 4. Chỗ thiết kế lệch với backend (các mục 1, 2, 4, 5, 7 đã chốt ở mục 0)

| # | Vấn đề | Đề xuất |
| --- | --- | --- |
| 1 | **Mở chương (P8)**: backend đã **gỡ** API release unit ngày 22/10 theo quyết định của owner. Không còn khoá/mở chương thủ công hay hẹn giờ mở (`CORE_BUSINESS_LOGIC.md`, migration `1792627200001`). Contract trong MindyMobile vẫn ghi route này nên đã cũ. | **Bỏ** tiện ích Mở chương, trang P8 và thông báo "chương sẽ mở". Cập nhật lại contract. |
| 2 | **Điểm danh**: thiết kế ghi "mặc định là vắng, chạm để có mặt". Backend có 3 trạng thái `UNMARKED/PRESENT/ABSENT`. Roster **rỗng cho tới khi gọi `start`**. Chỉ được bắt đầu trong ngày học; sửa được tới 00:00 ngày học + 2; `finalize` mới đổi UNMARKED thành ABSENT. | Hiện "Chưa điểm danh" cho UNMARKED. Thêm bước **Bắt đầu buổi** khi `canStart`. Thêm nút "Có mặt tất cả" (bulk). Hiện hạn sửa và khoá khi hết hạn. |
| 3 | **Thông báo**: backend chỉ có `CHAT_MESSAGE`. Thiết kế có "được phân công dạy thay", "tài liệu đã duyệt", "chương sẽ mở". | Giai đoạn đầu chỉ hiện thông báo backend có. Thẻ "Dạy thay hôm nay" trên Home lấy từ `/mentor/schedule`. Thông báo nghiệp vụ chờ backend bổ sung. |
| 4 | **Quên mật khẩu**: backend chưa có API. | Ẩn link, hoặc đổi thành "Liên hệ trung tâm", tới khi backend có. |
| 5 | **Đăng nhập Google**: backend có luồng web (`/auth/google` → callback đặt cookie trên trình duyệt). Mobile cần deep link + chuyển cookie (ADR-0013 đã hoãn). | Ẩn nút ở giai đoạn đầu. |
| 6 | **"Bảo lưu", "Cần chú ý"**: backend không có trạng thái bảo lưu; ngưỡng chuyên cần chưa có business rule. | Bỏ lọc "Bảo lưu". Chốt ngưỡng "Cần chú ý" (thiết kế: < 80%) vào BUSINESS_RULES. |
| 7 | **Login staff vs Học viên**: Login mới không có Đăng ký, khác Login Học viên hiện tại. | Xem câu hỏi ở mục 7. |
| 8 | **Backend có nhưng thiết kế chưa có**: đơn xin nghỉ của mentor (`/mentor/leave-requests`), ghi chú giảng dạy (`/class-sessions/:id/teaching-notes`), bài tập (`/mentor/.../assignments`), chat, đổi link họp. | Ngoài phạm vi đợt này; đưa vào backlog khi có thiết kế. |

## 5. Lộ trình

Ước lượng cho 1 dev Flutter, đã có nền MindyFlutter (core network/session/i18n). Mỗi phase theo vòng **UI với fixture → owner duyệt UI → gắn API → UAT** như quy trình RN.

| Phase | Nội dung | Xong khi | Ngày công |
| --- | --- | --- | --- |
| **MF0: Chốt phạm vi & contract** | Owner trả lời mục 4 và mục 7. Viết lại contract Mentor từ source backend (bỏ release, thêm bulk/notifications/files). Chuẩn bị tài khoản test: mentor chỉ dạy chính, chỉ dạy thay, cả hai; buổi đang diễn ra hôm nay; lớp có tài liệu đủ 4 trạng thái. | Có contract và dataset; mọi lệch thiết kế đã có quyết định | 1–2 |
| **MF1: Nền staff** | Router theo role, bỏ chặn MENTOR, Login staff (nếu chọn), StaffTheme + font + icon + UI kit staff, toast/sheet, helper Idempotency-Key, fixture Mentor. | Mentor đăng nhập vào được Home trống; UI kit khớp thiết kế ở 320px và chữ lớn | 2–3 |
| **MF2: Home + Lịch dạy + Phòng học + Thông báo** | H, P1, S2, N, P9 (dạy thay). Thẻ buổi tiếp theo, vào Meet (`url_launcher`), sao chép link. | Lịch đúng múi giờ server, nhiều trang; chỉ hiện Meet khi có `meetingUrl` | 3–4 |
| **MF3: Điểm danh** | S1, S3, S4: start, đánh dấu từng người, bulk, đồng bộ sĩ số, chốt buổi; xử lý 409 version/idempotency, hết hạn sửa, mất mạng giữa chừng. | Không mất/ghi đè điểm danh khi retry hay khi 2 thiết bị cùng sửa; đủ các ca lỗi trong `attendance.md §19.8` | 3–4 |
| **MF4: Lớp + Báo cáo + Học viên** | P2, P3, P4, P5, S5. | Số liệu khớp backend; tìm/lọc đúng; chế độ chỉ-dạy-thay ẩn đúng tiện ích | 3–4 |
| **MF5: Tài liệu + Tải file lên** | P6, P7: chọn file, upload intent, PUT MinIO có %, complete, chờ READY, tạo material, gửi duyệt từng file/tất cả, sửa/xoá nháp, lý do từ chối, xem trước file. | Upload lỗi/hết hạn URL không tạo rác; không gửi duyệt khi file chưa READY | 4–5 |
| **MF6: Tiện ích + hoàn thiện** | P10, yêu thích/Sửa (lưu theo user), regression toàn luồng Mentor, a11y, hiệu năng, UAT. | Owner UAT đạt | 2–3 |

Tổng: **18–25 ngày công**, cộng dự phòng 20% thành **22–30 ngày công (khoảng 4,5–6 tuần)**. Chưa tính thời gian chờ backend bổ sung thông báo nghiệp vụ, quên mật khẩu, Google mobile.

Tiến độ:

- **MF1 (02/11/2026)**: đã code (chưa build). Gồm: phân luồng theo role (`redirectFor`); cho phép MENTOR đăng nhập; Ghi nhớ đăng nhập; Login chung giao diện staff (giữ Đăng ký, ẩn Google/Quên mật khẩu); font Be Vietnam Pro + icon Material Symbols trích từ file thiết kế; UI kit staff (`core/ui/staff/`); Home Mentor khung (tiện ích yêu thích lưu theo user, chế độ chỉ-dạy-thay qua `/mentor/classes`, sheet Tài khoản + Đăng xuất); trang Tất cả tiện ích; trang tạm cho MF2–MF5; `IdempotentCall`; `ApiClient` có PUT/PATCH + header, tự gửi `Origin` cho mọi request ghi. Chờ owner chạy `flutter analyze/test` và duyệt UI.
- MF0 (viết lại contract Mentor, dataset test) vẫn cần làm song song trước khi gắn API ở MF2.

Thứ tự: `MF0 → MF1 → MF2 → MF3 → (MF4 ∥ MF5) → MF6`. MF3 có rủi ro cao nhất nên làm sớm ngay sau khi có lịch dạy.

## 6. Kiểm thử chính

- **Unit**: state machine điểm danh (UNMARKED/PRESENT/ABSENT, chỉ gửi dòng đổi, batch ≤100, version nối tiếp); idempotency (retry giữ key+body, key mới mỗi thao tác); suy chế độ chỉ-dạy-thay; tính % chuyên cần, ngưỡng cần chú ý; luồng upload (intent hết hạn, complete mất response thì GET status trước).
- **Widget/golden**: mọi màn H, P1–P7, P9–P10 và sheet S1–S5; trạng thái loading/rỗng/lỗi; 320×640 với chữ ×1.3.
- **Integration với backend test**: đăng nhập mentor → lịch hôm nay → bắt đầu → điểm danh → đồng bộ → chốt; tải file → gửi duyệt → (Quản lý duyệt) → thấy ở Tài liệu; tài khoản chỉ dạy thay.

## 7. Câu hỏi đã gửi owner (đã trả lời, xem mục 0)

1. **Một app chung** (Học viên + Mentor, sau thêm Quản lý, phân theo role) hay **app Staff riêng**? Đề xuất: app chung, vì dùng chung core/session/i18n và chỉ cần một bản build.
2. **Login mới** dùng cho mọi role hay chỉ staff? Nếu dùng chung thì Học viên có giữ link "Đăng ký" không?
3. Đồng ý **bỏ Mở chương** theo backend hiện tại?
4. Đồng ý **ẩn Google + Quên mật khẩu** tới khi backend có luồng mobile?
5. Đồng ý điểm danh **3 trạng thái + bước Bắt đầu buổi** theo backend (thay cho "mặc định vắng")?
