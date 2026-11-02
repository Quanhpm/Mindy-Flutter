# Code rule — quy tắc code MindyFlutter

Cập nhật: **02/11/2026**. Áp dụng cho mọi người và mọi công cụ AI sửa repo này. Có mâu thuẫn thì thứ tự ưu tiên: **contract API của backend → quyết định owner (ghi trong `REMAINING_WORK_PLAN.md`/`MENTOR_PLAN.md`) → file này → `docs/UI.md` → code hiện có**.

---

## 1. Nguyên tắc

1. **Server quyết định nghiệp vụ.** App chỉ hiển thị và gửi lệnh; không tự tính giá, quyền, trạng thái thanh toán hay điểm danh.
2. **Không đoán dữ liệu.** Response sai kiểu thì báo lỗi (`ApiError` 502), không âm thầm bỏ qua hay điền giá trị giả.
3. **Không retry tự động mutation, không optimistic update.** State chỉ đổi theo response server.
4. **Một nguồn sự thật:** endpoint ở `*_api.dart`, path ở `Routes`, màu ở theme, chữ ở file dịch.
5. **Code dễ đọc hơn code ngắn.** Mỗi file một trách nhiệm; comment bằng tiếng Việt giải thích *vì sao*, ghi nguồn RN/backend khi port.

---

## 2. Cấu trúc thư mục

```text
lib/
  main.dart            khởi tạo timezone + i18n, ProviderScope (đã tắt retry)
  app/                 app.dart (MaterialApp.router), router.dart (bảng GoRoute)
  core/                hạ tầng dùng chung
    config/            env.dart
    network/           api_client, api_error, json, cookie_storage, idempotency
    session/           session_user, session_controller
    router/            routes.dart (Routes, redirectFor, goTab)
    i18n/              i18n.dart (Translator, localeProvider, trProvider)
    theme/             app_colors, app_theme (hệ Học viên)
    ui/                component Học viên + dùng chung; ui.dart export gộp
    ui/staff/          component Staff (Login, Mentor)
    utils/             format.dart (tiền, ngày, timezone)
  features/<feature>/  mỗi tính năng một thư mục
test/                  unit + widget test
assets/                i18n, fonts, images, illustrations
env/                   dev.json, local.json, prod.json
docs/                  plan, UI, code rule, contract, ảnh thiết kế
tool/                  setup.sh, check.sh
```

**Quy tắc phụ thuộc:**

- `core/` **không** import `features/`. Ngoại lệ duy nhất: `core/session/session_controller.dart` dùng `features/auth/auth_api.dart`.
- Feature được import `core/` và feature khác khi cần dùng model/API (ví dụ `payment` dùng `my_classes_api` cho tiếp tục thanh toán). Không import màn hình của feature khác, trừ hàm mở sheet công khai (`showCourseSheet`, `showCartSheet`).
- Component dùng ở ≥ 2 feature thì chuyển vào `core/ui/` hoặc `core/ui/staff/`.

**Khuôn file của một feature:**

| File | Chứa |
| --- | --- |
| `<f>_models.dart` | Model bất biến + `factory X.fromJson(Json j)` + logic thuần (vd `Enrollment.action`) |
| `<f>_api.dart` | Class `XxxApi` gọi `ApiClient`, trả model; `xxxApiProvider` |
| `<f>_providers.dart` | Provider/Notifier Riverpod: đọc dữ liệu, cache, thao tác |
| `<f>_screen.dart` | Widget màn hình; sheet/widget riêng của feature có thể tách file cùng thư mục |

Feature lớn (Mentor) chia thư mục con theo màn (`mentor/schedule/`, `mentor/attendance/`…), mỗi thư mục con vẫn theo khuôn trên.

---

## 3. Đặt tên

| Loại | Quy tắc | Ví dụ |
| --- | --- | --- |
| File | `snake_case.dart` | `mentor_home_screen.dart` |
| Class, enum, typedef | `PascalCase` | `MentorHomeScreen`, `ScheduleWeek` |
| Biến, hàm, getter | `camelCase` | `weekRange`, `isTerminal` |
| Provider | `<tên>Provider` | `cartProvider`, `scheduleWeekProvider` |
| API class | `<Feature>Api` + `<feature>ApiProvider` | `CoursesApi`, `coursesApiProvider` |
| Enum khớp backend | Giữ **đúng tên backend** (UPPER_CASE) để `Json.enumOf` parse; thêm `// ignore_for_file: constant_identifier_names` đầu file | `OrderStatus.PAID` |
| Key dịch | Nhóm theo feature, chấm phân cấp, camelCase | `mentor.home.favorites` |
| Route | Hằng trong `Routes`; route có tham số dùng hàm | `Routes.classDetail(id)` |
| Test | `test/<phạm vi>_test.dart`, mô tả tiếng Việt | `mentor_mf1_test.dart` |

---

## 4. State — Riverpod 3

- Service/API: `Provider((ref) => XxxApi(ref.watch(apiClientProvider)))`.
- Đọc dữ liệu: `FutureProvider.autoDispose` (thêm `.family` nếu có tham số). Rời màn tự huỷ cache, quay lại đọc mới.
- Dữ liệu có thao tác: `AsyncNotifier` / `Notifier` (vd `CartController`, `MentorFavoritesController`).
- **Dữ liệu riêng tư của user phải `ref.watch(sessionEpochProvider)`** để tự reset khi đăng xuất/đổi tài khoản.
- Không dùng `StateProvider` (đã thành legacy ở Riverpod 3).
- `ProviderScope` đã tắt retry tự động; không bật lại.
- Trong `build`: dùng `ref.watch`. Trong callback (onTap, onPressed): dùng `ref.read`. Làm mới: `ref.invalidate(provider)`.
- Sau mọi `await` trong `State`, kiểm tra `if (!mounted) return;` trước khi dùng `context`/`setState`.
- Logic phức tạp (tính trạng thái, diff, lọc) viết thành **hàm thuần** ngoài widget để test được (vd `redirectFor`, `toggleFavorite`, `Order.result`).

---

## 5. Gọi API

- Chỉ đi qua `ApiClient` (`apiClientProvider`). Không tạo `Dio` khác, trừ client upload MinIO (MF5, không cookie, không baseUrl).
- Path **tương đối, không có `/` đầu**: `'mentor/schedule'`. Base URL lấy từ `Env.apiUrl` (đã có `/api/v1/`).
- Response là DTO trực tiếp (không bọc `data`), trừ API thông báo trả `{ data: [...] }`.
- Parse bằng `Json`: `j.uuid('id')`, `j.str()`, `j.integer()`, `j.amount()`, `j.day()` (ngày thuần), `j.dateTime()` (bắt buộc có offset), `j.enumOf()`, `j.list()`, `Paged.fromJson()`. Truyền mã lỗi riêng của feature (`'INVALID_LEARNING_RESPONSE'`).
- **Phân trang:** cần "tất cả" thì đọc hết các trang và gọi `page.check(expectedPage, count, errorCode)`; lỗi trang sau không biến thành danh sách rỗng.
- **Gửi lên:** timestamp có offset; field tuỳ chọn rỗng thì **bỏ hẳn** (backend trả 422 nếu có field lạ); không gửi giá, role, studentId do app tự tính.
- **Lỗi:** mọi lỗi là `ApiError {status, code, requestId}`. Xử lý theo `status` + `code`, **không so sánh `message`**. Hiện câu qua `errorKey(e)` (hoặc bảng mã riêng của feature) + `requestIdOf(e)`.
- **Origin:** `ApiClient` tự gửi `Origin = Env.appOrigin` cho mọi request ghi. Không tự set tay.
- **Idempotency** (điểm danh, gán mentor): mỗi lần người dùng bấm tạo `IdempotentCall` mới; lỗi mạng thì gửi lại **đúng call đó**; `409 SESSION_VERSION_CONFLICT` thì tải lại rồi tạo call mới với `expectedVersion` mới.
- **Phiên:** 401 `AUTHENTICATION_REQUIRED` do `ApiClient` tự refresh một lần; feature không tự xử lý 401.
- **Thời gian:** hiển thị theo `timeZone` của response (`Dates.time/instant/localDay`), không theo múi giờ máy. Ngày `YYYY-MM-DD` giữ nguyên chuỗi.
- Chuỗi tiền: `formatVnd(int)` → `1.500.000 VND`.

---

## 6. Model

- Field `final`, constructor `const` khi được; không để `dynamic`/`Map` thô lọt ra khỏi `*_api.dart`.
- Kiểm tra nghiệp vụ khi parse: `endsAt > startsAt`, số tiền nguyên ≥ 0, id khớp request, enum lạ thì lỗi (không suy thành quyền cao nhất).
- Bản xem trước (CASH_PREVIEW) **không bao giờ** giữ `meetingUrl`.
- Logic quyền/trạng thái đặt trong model dưới dạng getter (vd `Enrollment.action`, `Order.canPay`) để dùng chung và test.

---

## 7. Widget

- Màn hình: `ConsumerWidget` / `ConsumerStatefulWidget`. Không gọi API trực tiếp trong widget; gọi qua provider/notifier.
- **Không viết màu literal** trong `features/`; dùng `AppColors`/`StaffColors`/`StatusTone`. Màu literal (bóng, độ trong suốt) chỉ nằm trong `core/theme/` và `core/ui/`.
- **Không viết chữ hiển thị cứng**; mọi chữ qua `t('key')`.
- Dùng component có sẵn (`docs/UI.md` mục 3); thêm component mới vào `core/ui[/staff]` thay vì vẽ lại trong màn.
- Hệ Học viên và hệ Staff không trộn trong một màn.
- `const` constructor ở mọi chỗ có thể.
- Vùng bấm ≥ 44; icon-only có `tooltip`/`semanticLabel`; ảnh trang trí `ExcludeSemantics`.
- Danh sách `ListTile` phải có `Material` gần nhất phía trên, nằm **bên trong** nền màu/thẻ (tránh lỗi ink/assertion).
- Điều hướng: đổi tab bằng `goTab()`/`context.go(Routes.x)`; mở màn chi tiết bằng `context.push(...)`; sheet bằng `showAppSheet`/`showStaffSheet`.

---

## 8. Đa ngôn ngữ

- File: `assets/i18n/vi.json` (mặc định) và `en.json`; **thêm key vào cả hai**.
- Tham số dạng `{{name}}`: `t('cart.title', {'count': 3})`. Mảng: `t.list('schedule.days')`.
- Key thiếu sẽ hiện nguyên key trên màn: coi là lỗi, sửa trước khi bàn giao.
- Dùng lại key RN khi màn tương đương; key mới của staff đặt dưới `staff.*`, `mentor.*`.

---

## 9. Bảo mật và dữ liệu nhạy cảm

- Cookie phiên chỉ nằm trong `SecureCookieStorage` (Keychain/Keystore). Không lưu token/mật khẩu vào `SharedPreferences`.
- `SharedPreferences` chỉ cho cài đặt không nhạy cảm (ngôn ngữ, ghi nhớ đăng nhập, tiện ích yêu thích).
- Không log body request/response, email, số điện thoại.
- Không đưa thông tin ngân hàng mẫu vào bản production.
- `.env`, `env/*.local.json`, `check.log`, `run.log` không commit. Không đưa mật khẩu tài khoản test vào repo.
- Link ký (file, Meet) chỉ giữ trong RAM, không cache chéo user.

---

## 10. Môi trường

- Đọc biến qua `Env` (`lib/core/config/env.dart`), không gọi `String.fromEnvironment` ở chỗ khác.
- Bản development không truyền gì sẽ dùng mặc định của `.env` dự án (server dev). Đổi backend: `--dart-define-from-file=env/local.json`.
- Bản production bắt buộc có `API_URL` (thiếu thì app dừng ngay khi mở).

---

## 11. Test

- Logic thuần (parse, trạng thái, quyền, diff, timezone, idempotency): **unit test bắt buộc**.
- Màn có trạng thái phức tạp: widget test cho loading / rỗng / lỗi / dữ liệu.
- Test không gọi backend thật; dữ liệu mẫu không chứa thông tin người thật.
- Lỗi đã tái hiện phải có test hồi quy trước khi sửa (đỏ → xanh).
- Trước khi bàn giao: `bash tool/check.sh` phải **No issues found** + **All tests passed**.

---

## 12. Lint và format

- Lint theo `analysis_options.yaml` (`flutter_lints` + `strict-casts`, `strict-raw-types`, `prefer_single_quotes`, `avoid_print`, `prefer_const_constructors`).
- Không tắt lint bằng `// ignore` trừ `constant_identifier_names` cho enum khớp backend; ignore nào khác phải kèm lý do.
- Format: `dart format` với độ dài dòng 120 (code hiện viết theo mức này).
- Không để import thừa, biến thừa, `print`.

---

## 13. Package

- Thêm package phải ghi lý do vào `REMAINING_WORK_PLAN.md` mục 15 trước khi `flutter pub add`.
- Ưu tiên package chính thức/phổ biến; không thêm package chỉ để bọc một hàm nhỏ.
- Không tải font/ảnh lúc chạy (không dùng `google_fonts` runtime); asset bundle sẵn trong app.

---

## 14. Git và quy trình

Owner đã ủy quyền trong chat ngày 02/11/2026: tự quyết các phần sau, không hỏi thêm.
Từ MF2 agent tự review UI và tiếp tục API; lưu ảnh/bằng chứng để owner xem lại.
Yêu cầu kiểm thử và bằng chứng hoàn thành vẫn giữ nguyên.

- Mỗi phase một nhánh: `flutter/p0-fixes`, `flutter/mf2-schedule`, `flutter/s1-home`…
- Commit nhỏ, message tiếng Việt hoặc tiếng Anh rõ ý: `mf3: điểm danh chia batch 100 dòng`.
- **Chỉ một người/công cụ sửa repo tại một thời điểm**; công cụ khác chỉ review hoặc làm nhánh khác.
- Merge khi `check.sh` sạch và owner đã duyệt UI/UAT theo phase.
- Cập nhật `docs/UI.md` (trạng thái màn, sai khác) và checklist trong `REMAINING_WORK_PLAN.md` cùng commit với code.

---

## 15. Definition of Done của một việc

- [ ] Đúng đặc tả phase và contract backend; sai khác đã ghi ở `docs/UI.md` mục 9.
- [ ] Đủ trạng thái loading / rỗng / lỗi / disabled.
- [ ] Chữ qua `t()`, có đủ `vi` + `en`; màu/chữ/icon từ theme.
- [ ] Đạt 320×640 chữ ×1,3; trợ năng cơ bản.
- [ ] Unit/widget test cho phần logic mới; `check.sh` sạch.
- [ ] Không có dữ liệu nhạy cảm trong log/repo.
- [ ] Đã cập nhật tài liệu liên quan.

---

## 16. Nên / Không nên (tóm tắt)

| Nên | Không nên |
| --- | --- |
| Parse bằng `Json`, ném `ApiError` khi sai | Ép kiểu `as` trực tiếp từ JSON, nuốt lỗi |
| `ref.watch(sessionEpochProvider)` cho dữ liệu riêng tư | Cache dữ liệu user ở biến global |
| `IdempotentCall` cho điểm danh, gửi lại đúng call khi lỗi mạng | Tạo key mới khi retry, hoặc tự retry mutation |
| Chỉ hiện thành công khi server xác nhận | Đổi UI trước rồi "sửa lại" khi lỗi |
| Hàm thuần + test cho logic | Viết logic nghiệp vụ trong `build()` |
| Component trong `core/ui[/staff]` | Copy-paste style giữa các màn |
| `Routes.x` + `goTab`/`push` | Gõ chuỗi path tay trong màn |
| Hiển thị theo `timeZone` server | Dùng `DateTime.now().toLocal()` để hiển thị lịch |
