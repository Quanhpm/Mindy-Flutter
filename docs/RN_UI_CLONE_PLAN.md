# Kế hoạch clone toàn bộ React Native → Flutter (staff app)

> Nguồn chuẩn: `MindyMobile_Admin` (commit `091a685 full flow mentor + manager`), gồm khoảng 18,6k dòng TSX và khoảng 12k dòng TS logic, 44 file test.
> Đích: `MindyFlutter`, nhánh `flutter/manager-core`.
> **Phạm vi: clone toàn bộ, không chỉ giao diện.** Bao gồm:
> - màn hình và điều hướng;
> - service/API, model và validation;
> - trạng thái loading/empty/error/offline/hết phiên;
> - nháp và idempotency;
> - realtime chat;
> - theme sáng/tối/hệ thống, animation, chữ vi/en;
> - a11y label và test.
>
> RN là source of truth. Flutter chỉ giữ lại hạ tầng (ApiClient + sessionEpoch, Json, IdempotentCall, router, i18n `t()`, font/icon).

## 0. Phạm vi và việc đang bị chặn

| Role | Nguồn RN | Trạng thái |
|---|---|---|
| Mentor | `MindyMobile_Admin` (role `MENTOR`) | Làm ngay |
| Manager | `MindyMobile_Admin` (role `MANAGER`) | Làm ngay |
| Student | — | **Không clone** (owner chốt 03/11). Giữ nguyên UI học viên của Flutter. |

## 1. Chiến lược: port theo module, không vá màn cũ

Muốn clone "y chang" mà vẫn nhanh thì cách rẻ nhất là **dựng lại từng module theo đúng cấu trúc RN**, thay vì vá dần `lib/features/mentor|manager` (code cũ khác RN cả về luồng lẫn endpoint).

```
RN  src/modules/<m>/{types,schema|model,services/*,<M>Provider,messages,screens/*,components/*,__tests__}
 →  lib/features/staff/<m>/{<m>_models.dart, <m>_api.dart, <m>_providers.dart, <m>_messages (i18n), screens/, widgets/}
    test/staff/<m>_*_test.dart
```

- Module: `auth`, `teaching`, `attendance`, `leave`, `operations`, `materials`, `quiz`, `reports`, `chat`.
- Map công nghệ:
  - `XxxProvider` + TanStack Query → Riverpod provider (family/notifier, `invalidate` thay `refetch`).
  - zod schema → `Json` parser.
  - axios service → `ApiClient`.
  - `useRemoteRead`/`isActive`/`onExpired` → `ref.mounted` + sessionEpoch + `expireSession`.
- Khi xong một module: chuyển route sang màn mới, đánh dấu file cũ là chết. **Xoá `lib/features/mentor` và `lib/features/manager` ở bước cuối** (thiết bị đang chặn xoá file, owner tự xoá bằng `git rm`).

## 2. F0 — Foundation (~2 ngày, chặn mọi việc khác)

### 2.1 Theme sáng/tối/hệ thống

- `StaffPalette` là một `ThemeExtension` sinh từ `tokens.json` (light và dark, đủ 59 màu, giữ tên RN).
- Truy cập qua `context.mdy.primary`…
- `themeChoiceProvider` (system/light/dark) lưu bằng `shared_preferences`, giống MMKV của RN.
- Thay toàn bộ `StaffColors.x` dạng const bằng `context.mdy.x`. Màn cũ cũng phải đổi để app không vỡ khi bật dark.

### 2.2 Token còn lại

- Spacing, radius, fontSize, lineHeight, motion (`base 250`, `slide 320`, `press 120`), layout (`keyboardOffset 128`, shadow card `0/8/24`, `glassBlur 18`), letterSpacing.
- Tất cả đưa vào `staff_tokens.dart`.
- Typography theo `classes.ts` (có `height`).

### 2.3 Icon

- Thêm 31 codepoint còn thiếu vào `sym.dart`: `arrow_downward, arrow_left, arrow_right, arrow_upward, article, attach_file, call, chevron_left, cloud_off, contrast, dark_mode, dashboard, delete, dns, done_all, edit_calendar, expand_more, filter_list, help, light_mode, lock_clock, lock_person, more_vert, open_in_new, person_remove, restore, settings, settings_alert, tag, translate, warning`.
- Thêm biến thể FILL 1 cho `light_mode/dark_mode/contrast`.

### 2.4 Primitive (`lib/core/ui/staff/`), clone 1-1 từ `src/components/ui`

| RN | Flutter |
|---|---|
| `Gradient` (header chéo 0→.55→1; nền glow teal/warm, `app` dịch cy) | `MdyGradient` |
| `Screen` (scroll, safe area, refresh, keyboard aware, `flushBottom`) | `MdyScreen` |
| `BrandHeader` (auth có tagline và mascot / workspace / subpage / flush) | `MdyBrandHeader` |
| `SubpageHeader`, `ListPage<T>` (phân trang, empty, error) | `MdySubpageHeader`, `MdyListPage<T>` |
| `Card` (overlap -64, frosted blur, FadeIn 250, skeleton) | `MdyCard` |
| `Row`, `Chip`, `Alert`, `CircleIcon`, `Avatar`, `FocusHeading` | cùng tên, tiền tố `Mdy` |
| `Button` (CVA variants, busy, icon, asChild) | `MdyButton` |
| `TextField` (label, error, autofill, ref focus) | `MdyTextField` |
| `Sheet` (gorhom: handle, snap) | `showMdySheet` (DraggableScrollableSheet) |
| `ConfirmationDialog` (scrim, danger, khoá khi busy) | `showMdyConfirm` |
| `Toast` | `MdyToast` (overlay, gọi qua `useAuth().toast` → `toastProvider`) |
| `Skeleton`, `ThemeCard` | `MdySkeleton`, `MdyThemeCard` |

- Reduced motion: `MediaQuery.disableAnimations` thay cho `useReducedMotion`.
- Blur: `BackdropFilter(sigma 18)`.

### 2.5 Hạ tầng dùng chung

- Clone các hook trong `shared/hooks`:
  - `useNetInfo` → banner offline (`connectivity_plus` đã có);
  - `useRemoteRead`;
  - `useIntersectionObserver` → `VisibilityDetector` hoặc `ScrollController` (load more).
- Chữ: copy `src/translations/{vi,en}.ts` và toàn bộ `messages.ts` của các module (khoảng 3k dòng) vào i18n Flutter. **Giữ nguyên key RN** để dễ diff.
- Nếu cần thì có script `tool/rn_i18n_import.dart`.

**Done khi:** có màn gallery (chỉ debug) render đủ primitive ở cả light và dark, `check.sh` xanh.

## 3. Thứ tự module, phạm vi và ước lượng

| # | Module RN | Màn RN | Logic phải port | Package mới | Ngày |
|---|---|---|---|---|---|
| 1 | **auth** | Bootstrap, Login, Denied, Workspace (Home 2 role: TodayCard, HomeTile, ManagerIncompleteSummary, mascot, pull-refresh gom refresher), Profile, Settings (ngôn ngữ, ThemeCard, logout confirm), ReviewPanel/Controls, AccountPage | restore phiên, kiểm tra identity (email + role đổi → hết phiên), notice `sessionExpired`, route theo role | — | 1,5 |
| 2 | **teaching** | MentorClasses, ManagerClasses, MentorClassDetail (tab Sắp tới/Đã xong), ManagerClassDetail, MentorStudents, SessionContext (873 dòng), TeachingSchedule (lịch tuần/tháng) | teachingService (4 file), query keys, model `sessionDisplayStatus` | lịch: tự dựng theo `DayStrip` hoặc `table_calendar` | 2,5 |
| 3 | **attendance** | AttendanceEditor, TeachingNoteEditor, IncompleteSessions, AttendanceManagement / ManagerUtilities, StudentAttendanceForm, ManagerFinalizeSessions, ManagerFinalize, AttendanceCorrection, AttendanceRecovery, AttendanceAudits, AttendanceReviewHost | attendanceService, attendance key/clock/model, idempotency, review host (lazy) | — | 3,5 |
| 4 | **leave** | MentorLeaveList, LeavePlanEditor (846), MentorLeaveDetail, LeaveReviewQueue, LeaveReviewDetail, MakeupConflicts, MakeupPlacement | leaveService, `getRole`, leave model | — | 2,5 |
| 5 | **operations** | CashOrders, CashOrderDetail (1044), SubstituteAssignment, RescheduleSession, ReplacementSession | operationsService (chỉ MANAGER) | — | 2 |
| 6 | **materials** | MentorMaterials, MaterialEditor (690), MentorMaterialDetail, MaterialReviewQueue, MaterialReviewDetail, MaterialPreview | material service và model, upload | `pdfx` hoặc `syncfusion_flutter_pdfviewer`, `webview_flutter` | 2 |
| 7 | **quiz** | QuizList, QuizEditor (1265), QuizDetail | quiz service, import, live, model | — | 3 |
| 8 | **reports** | MentorReportClasses, MentorAttendanceReport, MentorStudentReport, ManagerAttendanceReport | reports service và schema | — | 1,5 |
| 9 | **chat** | ChatConversations, ChatConversation, ChatNotifications, entry badge ở header | socket.io (`/socket.io`), danh sách, tin nhắn, đã đọc | `socket_io_client` | 2,5 |
| 10 | Dọn dẹp | Chuyển màn Flutter-only (mục 5) sang primitive/theme mới; xoá các màn cũ đã có bản port; cập nhật `UI.md`, `REMAINING_WORK_PLAN.md` | — | — | 1,5 |

**Tổng:** khoảng 22 ngày-người tính cả F0.

**Chạy song song 3 luồng sau F0 + auth** (≈ 8–9 ngày lịch):

- **Luồng A:** teaching → attendance → reports.
- **Luồng B:** leave → operations → materials.
- **Luồng C:** quiz → chat.

## 4. Quy trình port một màn (checklist cho dev/agent)

1. Đọc trọn cụm của màn RN: screen, components, service, model, messages, test.
2. Liệt kê: params route, query/mutation, các trạng thái, sheet/dialog, toast, a11y label, `testID` (map sang `Key('testID')`).
3. Port model/parse trước, kèm unit test chuyển từ `*-model.test.ts` / `*-api.test.ts`.
4. Port provider và service theo đúng endpoint, body, header RN. Đặc biệt `Idempotency-Key` và hành vi khi hết phiên.
5. Dựng UI chỉ bằng primitive F0 + `context.mdy`. Không viết màu hay số đo literal.
6. Port test UI quan trọng từ `*-ui.test.tsx` thành widget test, tìm phần tử bằng cùng `Key`.
7. Đặt ảnh emulator cạnh ảnh RN, kiểm tra cả light và dark, cỡ chữ ×1 và ×1,3. Đối chiếu thêm `docs/design/<phase>/<slice>/design.md`.
8. `bash tool/check.sh` xanh thì chuyển route sang màn mới.

## 5. Điều hướng cuối cùng (theo `AuthApp.tsx`)

- Một stack cho mỗi role, không có bottom tab.
- Home = Workspace. Header có avatar (mở Profile), Thông báo (chỉ Mentor) và Settings.
- Tile Mentor: Lớp của tôi, Học liệu, Quiz, Lịch dạy, Báo cáo, Nghỉ phép (Nghỉ phép hiện khi module bật).
- Tile Manager: Lớp học, Thu tiền mặt, Duyệt học liệu, Quản lý điểm danh, Chốt điểm danh, Duyệt nghỉ, Xung đột học bù.
- Màn nào cũng gắn guard role đúng như điều kiện `state.user?.role` trong RN.

**Màn Flutter mà RN không có → GIỮ của Flutter** (owner chốt 03/11). Chỉ đổi sang primitive/theme mới cho đồng bộ, không gỡ:

- Mentor: Tất cả tiện ích + favorites, Dạy thay (`substitute`), Meeting screen.
- Manager: People/Person, tạo/sửa học liệu (`material_editor`).
- **Code assignment** (mentor `MentorSessionCodeScreen`; học viên C6): giữ, gắn entry trong `SessionContext`.
- Tile của các màn giữ lại: thêm vào cuối lưới Home của role tương ứng (sau tile RN).

## 6. Kiểm tra

- Mỗi module: unit test model/api (port từ RN), widget test cho các màn chính, `check.sh` xanh.
- Smoke điều hướng: đăng nhập từng role, mỗi tile mở đúng màn, không vào được màn của role khác.
- Đối chiếu trực quan RN với Flutter trên cùng simulator, light và dark.
- Chạy với BE thật bằng dữ liệu `MENTOR_TEST_DATA.md` / `MANAGER_TEST_DATA.md`.

## 7. Quyết định của owner (03/11/2026)

1. Student: không clone.
2. Màn RN không có: giữ của Flutter.
3. Mock mode RN: không đưa vào app (chỉ dùng fake trong test).

## 8. Tiến độ

- 03/11 — **F0 đã viết, chưa chạy `check.sh`:**
  - `lib/core/ui/mdy/` gồm theme sáng/tối/hệ thống (`context.mdy`, lưu key `theme`), token và 81 icon SVG sinh từ RN (`tool/gen_mdy_from_rn.py`).
  - Đủ primitive RN (Screen, BrandHeader, Card, Row, Chip, Alert, Avatar, Button, TextField, ListPage, Sheet, ConfirmationDialog, Toast, Skeleton, ThemeCard, HomeTile).
  - 1.489 chuỗi RN vi/en ở `mdy.<namespace>` (`tool/rn_i18n_sync.mjs`), mascot RN.
  - `app.dart` có builder `MdyTheme` + `MdyToastHost`; test `test/mdy_foundation_test.dart`.
- 03/11 — F0 qua analyzer (4 lỗi đã sửa). **auth + tầng dữ liệu teaching đã viết, chưa chạy `check.sh`:**
  - `lib/features/staff/shared/remote.dart`: map lỗi về kind RN.
  - `staff/teaching/`: models, format, service (clone `teachingService.ts`), query (clone `useTeachingQuery`).
  - `staff/auth/`: Workspace 2 role + TodayCard + tóm tắt buổi cần xử lý + badge đơn nghỉ + bubble chat; Hồ sơ; Cài đặt (ngôn ngữ, giao diện, đăng xuất 1 / mọi phiên).
  - Route `/mentor`, `/manager` dùng Workspace mới; thêm `/mentor|manager/profile|settings`.
  - Tile trỏ tạm vào màn Flutter cũ tới khi port xong từng module.
  - Login (dùng chung với học viên) giữ nguyên, chỉ thêm toast "Đăng nhập thành công" cho staff.
  - i18n: tách key phẳng có dấu chấm của RN thành cây.
- 03/11 (tiếp) — **teaching xong phần màn** (`staff/teaching/*_screen(s).dart`, `teaching_widgets.dart`): danh sách lớp 2 role, chi tiết lớp Mentor/Quản lý (3 tab), học viên, lịch dạy, chi tiết buổi (`/mentor/session/:id`, `/manager/session/:id?tab=`). Router đã trỏ sang màn mới. **attendance**: models/logic/service/query/mutator xong; đang làm màn (EntryPoints, ManagerAttendancePanel, Editor, Note, Incomplete, Utilities, StudentForm, Finalize, Correction, Recovery, Audits). Chưa chạy check.sh (owner chỉ chạy 1 lần cuối).

- 03/11 (đợt tiếp theo) — **attendance/operations đã nối router và tile; leave xong code, chưa chạy check:**
  - Route điểm danh Mentor, ghi chú, tiện ích/sửa/lịch sử/chốt buổi Quản lý; phân công/dời/hủy-thay và tiền mặt đều tới màn `staff/` mới. Route lịch sử cũ chuyển sang màn audit mới. Kiểm tra UUID trước khi dựng các màn này.
  - `staff/leave/`: hoàn thành plan editor (preview/slots/recheck/confirm), detail/rút đơn/duyệt/từ chối, conflicts/placement/cancel; nối route 2 role, badge pending dùng query mới.
  - Giữ version, điều kiện chặn duyệt, kiểm tra nội dung học bù, khóa tài nguyên, payload + Idempotency-Key khi retry uncertain. Thêm theo dõi kết nối và chặn phản hồi phiên cũ.
  - Thêm `test/staff_leave_test.dart`; chỉ format và kiểm tra tĩnh import/key i18n, chưa chạy analyzer/test/check.sh. Chi tiết và bước tiếp theo: `docs/RN_CLONE_PROGRESS.md`.

- 03/11 (kiểm tra sâu) — cập nhật Manager widget/API fixtures, luồng thao tác theo màn clone và 10 golden. `bash tool/check.sh`: analyzer sạch, **375 test qua, 1 skip**. Manager suite: 45/45 qua. Chưa làm UAT native/backend hoặc nghiệm thu pixel-perfect. Chi tiết: `docs/RN_CLONE_PROGRESS.md` và `check.log`.
