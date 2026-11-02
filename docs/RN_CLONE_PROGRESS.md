# Tiến độ clone RN → Flutter (Mentor + Quản lý)

Cập nhật: 03/11/2026. Kế hoạch: `docs/RN_UI_CLONE_PLAN.md`.

**Đã viết code và nối route cho toàn bộ module RN trong phạm vi staff.** UI/API trên thiết bị chưa nghiệm thu.

## Trạng thái code

| Phần | Thư mục | Nội dung |
|---|---|---|
| Nền | `lib/core/ui/mdy/` | Theme, token, primitive, 82 icon (thêm pause cho video native), i18n vi/en |
| Auth | `staff/auth/` | Workspace, hồ sơ, cài đặt, tile mới; chat/notification và badge leave dùng query mới |
| Teaching | `staff/teaching/` | Lớp, học viên, lịch dạy, ngữ cảnh buổi; lối vào báo cáo Quản lý đã chuyển |
| Attendance | `staff/attendance/` | Điểm danh, ghi chú, sửa/chốt buổi, lịch sử, khôi phục; router/tile đã nối |
| Operations | `staff/operations/` | Phân công, dời, hủy-thay, tiền mặt; router/tile đã nối |
| Leave | `staff/leave/` | Danh sách, plan preview/slots/recheck, detail/rút/duyệt/từ chối, conflicts và placement/cancel |
| Materials | `staff/materials/` | Danh sách theo lớp/unit, detail/review, editor file/video/article, upload + polling, xử lý uncertain/conflict, preview PDF/ảnh/video/article và attachments |
| Quiz | `staff/quiz/` | Chọn lớp/buổi, danh sách/lọc, editor metadata/câu hỏi, reorder/delete, import CSV/TXT, detail/publish/archive/delete, kiểm tra kết quả uncertain trước khi gửi lại |
| Reports | `staff/reports/` | Báo cáo điểm danh lớp 2 role, lịch sử/summary học viên, progress lớp/unit, lọc khoảng ngày, chat học viên |
| Chat | `staff/chat/` | Danh sách/phòng chat/thông báo, unread, gửi/retry cùng clientMessageId, socket + HTTP catch-up, fallback polling, mark read, file access |
| Contacts | `staff/contacts/` | Port interface/model RN; RN không có màn/API contacts riêng |

Package thêm: `pdfx`, `video_player`, `socket_io_client`. `flutter pub get` đã xong.

## Kiểm tra

- Chạy Manager widget/API suite ở 320 px, text scale 1.3, tiếng Việt + Anh: **45/45 qua**. Cập nhật 10 golden cho màn Manager đã chuyển sang bản clone và sửa route query/fixture audit để khớp schema.
- Chạy lại `bash tool/check.sh`: `flutter analyze` **No issues found**; toàn bộ test **375 qua, 1 skip**.
- Thêm lại thao tác Flutter riêng phân công Mentor chính vào chi tiết lớp Manager.
- Kết quả ở `check.log`. Chưa chạy build native/UAT backend hoặc xác nhận giao diện pixel-perfect.

## Việc còn lại

1. Smoke trên thiết bị với backend thật: upload/preview native, socket xác thực bằng cookie, quiz mutation và báo cáo.
2. So sánh giao diện với RN ở vi/en, light/dark và cỡ màn nhỏ; rà các sai khác còn lại trước khi nghiệm thu 1-1.
3. Dọn màn Flutter-only theo plan; file cũ vẫn giữ, owner tự quyết định xóa/commit.

## Giữ nguyên quyết định owner

- Không clone phần Học viên; không thêm mock mode.
- Giữ màn Flutter-only; bài code nằm trong ngữ cảnh buổi.
- Không commit/push; phần C6 vẫn chưa commit.
- Không xóa file trên máy.

---

## Rule code (bắt buộc khi làm tiếp)

### Quy trình
- **Nguồn sự thật là RN** (`MindyMobile_Admin/src/modules/<module>`). Mỗi màn: đọc hết `types.ts`, `service`/`provider`, `hooks`, `screens/*.tsx`, `components/shared` rồi clone 1-1 logic, state, điều kiện hiển thị, testID và key i18n. Không tự thêm hay bớt tính năng.
- **Không có Flutter SDK ở cloud/VM.** Code phải tự review kỹ: kiểm tra chữ ký hàm của helper có sẵn bằng `grep` trước khi gọi, không đoán tên field/param.
- Chỉ chạy `bash tool/check.sh` **một lần sau khi port xong một đợt lớn**. Sau đó đọc `check.log` và sửa hết trong một lượt.
- Không commit/push git khi chưa được yêu cầu. Không xóa file trên máy (chỉ ghi/đè).
- Mỗi module đặt ở `lib/features/staff/<module>/`, gồm: `<m>_models.dart`, `<m>_service.dart`, `<m>_query.dart`, `<m>_widgets.dart`, `*_screen(s).dart`.

### Dart / Flutter (3.44, Dart 3.13)
- `flutter analyze` **fail cả khi chỉ có info**. Các lint hay dính:
  - `prefer_const_constructors`: thêm `const` khi được.
  - `unused_import`: gỡ import cũ khi đổi route.
  - `library_private_types_in_public_api`: class dùng trong API public phải public (vd. `RenderMdyOverlap`).
  - `use_null_aware_elements`: viết `'k': ?v`, `?x` trong collection thay cho `if (v != null)`.
  - `unused_result`: future của refresh viết `.then((_) {})` hoặc `await`.
  - `prefer_final_fields`.
  - `unnecessary_non_null_assertion`: `x!` đã promote biến local thì không `!` lần nữa.
- Không dùng API deprecated: thay `withOpacity` bằng `withValues(alpha:)`; thay `Matrix4.translate/scale` bằng `Matrix4.translationValues`/`diagonal3Values`.
- Được dùng: dot-shorthands, `Flex.spacing`, wildcard `_`, if-case trong collection, record, pattern `for (final (i, x) in list.indexed)`.
- Biến trùng tên giữa các `case` của `switch`: bọc mỗi case bằng `{}`.
- Trường bool lưu trong state không promote được, nên dùng biến local hoặc `!` một lần.

### Riverpod 3
- Query: `NotifierProvider.autoDispose.family<Q, S, Request>(Q.new)`, với Request có `==`/`hashCode` (dùng `listEquals` trên list field).
- Kiểm tra `ref.mounted` sau `await` trong Notifier; trong State thì kiểm tra `mounted`.
- `ref.listen` đặt trong `build`. Cần làm gì sau frame thì dùng `addPostFrameCallback`.
- Mutation (ghi) dùng class Mutator giữ `busy` / `result` / `uncertain`, có Idempotency-Key (uuid v4) và giữ nguyên key khi retry. Ghi thành công thì `bump()` revision provider để các query refresh.
- Toast: `ref.read(mdyToastProvider.notifier).show(text)`. Nếu gọi sau `await` mà widget có thể unmount, lấy container trước khi await.

### Gọi API
- `ApiClient`: path **không có `/` đầu**; header `Origin` tự thêm theo regex `_originRequired`. Endpoint mới mà BE đòi Origin thì thêm vào regex đó.
- Parse bằng `Json` (`str`, `strOrNull`, `uuid`, `integer`, `amount`, `dateTime`, `enumOf`, `obj`, `list`…) và `Paged.fromJson`. Response sai shape thì `fail(...)`, tạo ra `ApiError.invalidResponse` (status 502).
- Map lỗi về kind RN bằng `RemoteError.from` (`staff/shared/remote.dart`): offline / error / denied / notFound / unavailable / conflict / invalid.
- Lỗi mạng hoặc 5xx khi **ghi** thì coi là `uncertain`, hiện `IntentBanner` để gửi lại hoặc kiểm tra lại. Không tự retry ngầm.
- Giờ VN: `parseVietnamTime(DD/MM/YYYY, HH:mm)` trả về ISO `+07:00`. Hiển thị bằng `isoDate` / `isoTime` (`attendance_logic.dart`).

### i18n
- Chuỗi RN nằm ở `assets/i18n/{vi,en}.json` dưới `mdy.<namespace>.*`, sinh bằng `node --experimental-strip-types tool/rn_i18n_sync.mjs <RN path>` (idempotent). **Không sửa tay** phần `mdy.*`.
- Gọi bằng `t('mdy.<ns>.<key>', {'param': v})`; mỗi module có helper ngắn kiểu `o(key)` = `'mdy.operations.$key'`.
- Test i18n quét key literal `t('a.b')`, nên key phải tồn tại ở cả vi và en. Key ghép động thì không cần thêm gì.

### Router
- Route mới khai báo trong `lib/core/router/routes.dart` (hoặc class `Staff<Module>Routes` trong module), rồi đăng ký ở `lib/app/router.dart`.
- Màn có query (`?title=`, `?tab=`) đọc từ `state.uri.queryParameters`. Id phải kiểm tra `isUuid`, sai thì hiện trang unavailable.
- Quay lại: dùng `staffBack(context, manager: ...)`, không gọi `pop` trực tiếp.

## Rule UI

- **Chỉ dùng design system `lib/core/ui/mdy/`** (import `mdy.dart`). Không dùng `Theme.of`, `Colors.*`, Material `ElevatedButton`/`AlertDialog`/`showModalBottomSheet` ở màn staff.
- Màu: `context.mdy.<token>` (ink, secondary, tertiary, link, primary, onBrand, surface, border, divider, tint2, danger, muted2…), đúng tên class NativeWind `text-mdy-*` / `bg-mdy-*`.
- Khoảng cách và bo góc map 1-1 từ class RN:
  - `gap-space-12` → `MdySpace.s12`
  - `rounded-radius-14` → `MdyRadius.r14`
  - `rounded-radius-99` → `MdyRadius.r99`
  - Chỉ dùng giá trị đã sinh sẵn: space `s0…s280`, radius `r2…r99`.
- Chữ: `MdyType.size(px, weight, lineHeight)` cho `text-size-N font-bvp-*` (`w400`…`w700`); dùng các style có sẵn `MdyType.text/title/caption…`. Text có thể dài thì dùng `MdyText` (giới hạn scale).
- Icon: `MdyIcon(MdyIcons.<camelCase>, size:, color:)`, tên lấy từ tên icon RN (`expand_more` → `expandMore`). Nếu thiếu icon thì thêm vào generator, không dùng `Icons.*`.
- Map component RN sang Flutter:

  | RN | Flutter |
  |---|---|
  | `Page` | `AttendancePage` (alias `OpsPage`) |
  | `Card` | `MdyCard(margin: EdgeInsets.zero, padding:, gap:)` |
  | `Button` | `MdyButton(variant:, size:, busy:, disabled:)` |
  | `Chip` | `MdyChip` |
  | `Alert` | `MdyAlert` hoặc `OpsAlert` |
  | `Avatar` | `MdyAvatar` |
  | `CircleIcon` | `MdyCircleIcon` |
  | `Row` | `MdyRow` |
  | `Field` | `AttendanceField` |
  | `Sheet` | `MdyInlineSheet` (đặt trong `overlays:` của Page) |
  | `ConfirmationDialog` | `MdyInlineDialog` |
  | `Pressable` | `MdyPressed(builder: (ctx, pressed) …)` |
  | `QueryState` | `*QueryBlock` |
  | `More` | `*More` |
  | `Skeleton` | `MdySkeleton` |

- Footer RN (`footer=`) → `footer: [..]` của Page. Overlay sheet/dialog điều khiển bằng state (bool), không push route.
- **testID → `Key('...')` giữ nguyên chuỗi** để test và QA tra cứu được. `accessibilityRole` / `State` / `Label` → `Semantics` (button, header, checked, inMutuallyExclusiveGroup, liveRegion, label + `excludeSemantics`).
- `active:opacity-80` → `Opacity(pressed ? 0.8 : 1)`. Trạng thái disabled → `opacity 0.5` + `enabled: false`.
- Layout:
  - `flex-1` → `Expanded`; `shrink` → `Flexible`.
  - Không đặt `Positioned` thiếu `left`/`width` quanh `FractionallySizedBox`; dùng `Positioned.fill` + `Align`.
  - Viền không đều + `borderRadius` thì tách `DecoratedBox` + `Container`.
  - Skeleton cần chiều cao cố định, hoặc dùng `LayoutBuilder` khi không có ràng buộc.
- Trạng thái chuẩn mỗi màn: loading (skeleton), lỗi + nút thử lại, offline (cảnh báo, khóa thao tác ghi), denied/notFound (card), rỗng, phân trang "xem thêm", cảnh báo rời trang khi `dirty`.
- Màn Flutter mà RN không có: giữ nguyên, chỉ thêm tile ở cuối lưới Home. Học viên không đụng tới.
