# MindyFlutter

Bản Flutter clone **MindyMobile** (React Native), dùng cùng backend Mindy (`/api/v1`, cookie HttpOnly).
Kế hoạch tổng: `../MindyMobile/docs/FLUTTER_MIGRATION_PLAN.md`.

## Chạy lần đầu (macOS)

```bash
cd MindyFlutter
bash tool/setup.sh          # sinh android/ ios/, pub get, analyze, test
flutter run --dart-define-from-file=env/dev.json
```

- `env/dev.json` lấy từ `.env` của RN (API_URL, APP_ORIGIN). Android emulator tự đổi `localhost` thành `10.0.2.2`.
- Build release: `flutter build apk --dart-define-from-file=env/prod.json`. Bản prod thiếu `API_URL` thì app dừng ngay khi mở.

## Chạy bằng Xcode (iOS 15.0 trở lên)

Project dùng CocoaPods cho các plugin iOS, gồm `flutter_secure_storage`.

```bash
flutter pub get
flutter build ios --simulator --debug --config-only --dart-define-from-file=env/dev.json
cd ios
pod install
open Runner.xcworkspace
```

Trong Xcode, chọn scheme **Runner**, chọn một **iPhone Simulator**, rồi bấm **Run** (`⌘R`).
Mở `Runner.xcworkspace` để Xcode nạp cả các plugin trong Pods.
Nếu chạy trên iPhone thật, chọn Apple Development Team trong **Signing & Capabilities**.

Nếu `xcode-select -p` trả về `/Library/Developer/CommandLineTools`, chọn Xcode đầy đủ một lần:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Lệnh này cần mật khẩu quản trị của máy. Sau khi đổi `env/dev.json`, chạy lại bước `--config-only`
trước khi Run trong Xcode để cập nhật cấu hình Dart.

Đã kiểm chứng ngày 02/11/2026: build iOS Simulator Debug thành công bằng Xcode 27.0,
cài và mở tới màn Đăng nhập trên iPhone 17 Simulator (iOS 27.0). Analyzer sạch,
17/17 test hiện có pass. Chưa kiểm chứng ký ứng dụng và chạy trên iPhone thật.

## Cấu trúc: mỗi feature là 1 thư mục, các file theo cùng một khuôn

```text
lib/
  main.dart                 # init timezone + i18n, ProviderScope (đã tắt auto-retry)
  app/
    app.dart                # MaterialApp.router, chỉ light theme
    router.dart             # bảng route + guard theo session/role
  core/                     # KHÔNG import features (trừ session -> auth_api)
    config/env.dart         # biến môi trường (--dart-define)
    network/
      api_client.dart       # Dio + cookie + refresh single-flight + Origin header
      api_error.dart        # lỗi chuẩn {status, code, requestId}
      json.dart             # Json: đọc JSON có kiểm tra kiểu (thay Zod) + Paged<T>
      cookie_storage.dart   # cookie lưu trong Keychain/Keystore
    session/                # SessionController: bootstrap, login, logout, epoch
    router/routes.dart      # hằng path + goTab()
    i18n/i18n.dart          # dùng NGUYÊN file dịch RN, cùng key: t('auth.login.title')
    theme/                  # AppColors, RegionColors, AppText, Motion
    ui/                     # MindyButton, MindyInput, MindyIcon, ScreenState, Skeleton,
                            # AsyncView, AppTabBar, CoverImage, showAppSheet...
    utils/format.dart       # formatVnd, Dates (luôn theo timeZone của server)
  features/
    <feature>/
      <feature>_models.dart     # DTO + fromJson(Json) + logic thuần (vd Enrollment.action)
      <feature>_api.dart        # gọi API, trả model (giống *.service.ts)
      <feature>_providers.dart  # Riverpod: dữ liệu + cache (thay React Query hooks)
      <feature>_screen.dart     # UI
```

| Feature | Màn / thành phần | Nguồn RN để đối chiếu |
| --- | --- | --- |
| `auth` | Splash, Welcome (+tài khoản nhân sự), Login, Register | `modules/auth/*` |
| `home` | Trang chủ: buổi tiếp theo, khoá nổi bật | `modules/home/*` |
| `courses` | Danh mục, bộ lọc, gợi ý, phân trang, sheet khoá học/chọn lớp | `modules/courses/*` |
| `cart` | Sheet giỏ, checkout + "Kiểm tra lại" khi mất response | `modules/cart/*` |
| `payment` | QR, đếm ngược, runner theo dõi đơn, ticket kết quả | `modules/payment/*` |
| `schedule` | Lịch tuần | `modules/schedule/*` |
| `account` | Hồ sơ, ngôn ngữ, đăng xuất | `modules/account/*` |
| `my_classes` | Lớp của tôi, chi tiết lớp/buổi, quyền FULL/CASH_PREVIEW/NONE | `modules/my-classes/*` |

## Role Mentor (đang làm theo `docs/MENTOR_PLAN.md`)

- Một app cho mọi role: router (`redirectFor` trong `core/router/routes.dart`) đưa STUDENT về `/home`, MENTOR về `/mentor`.
- Login dùng chung, giao diện staff (`features/auth/login_screen.dart`); học viên vẫn có Đăng ký. Google + Quên mật khẩu ẩn tới khi backend có luồng mobile.
- Giao diện staff có bộ widget riêng trong `core/ui/staff/`: `StaffColors`, `StaffText` (Be Vietnam Pro), `Sym` (icon Material Symbols Rounded), `StaffHeader`, `GlassCard`, `StatusChip`, `FilterChipsBar`, `UtilityTile`, `StaffPage`, `StaffButton`, `StaffInput`, `showStaffSheet`, `showStaffToast`.
- Tiện ích Mentor khai báo một chỗ ở `features/mentor/mentor_utilities.dart`. Tiện ích chưa làm mở trang tạm có ghi phase.
- API cần `Idempotency-Key` (điểm danh): dùng `IdempotentCall` (`core/network/idempotency.dart`).
- Mọi request ghi tự gửi header `Origin` = `APP_ORIGIN` (backend chặn thiếu Origin ở tài liệu, thông báo, chat, bài tập).

## Viết code nhanh: 4 mẫu cần nhớ

**1. Gọi API + parse an toàn**

```dart
Future<Course> course(String id) async =>
    Course.fromJson(Json(await _api.get('courses/$id'), 'INVALID_CATALOG_RESPONSE'));
```

**2. Provider dữ liệu riêng tư** (tự reset khi logout/đổi user nhờ `sessionEpochProvider`)

```dart
final courseDetailProvider = FutureProvider.autoDispose.family<Course, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(coursesApiProvider).course(id);
});
```

**3. Hiển thị loading / lỗi / dữ liệu**

```dart
AsyncView(
  value: ref.watch(courseDetailProvider(id)),
  onRetry: () => ref.invalidate(courseDetailProvider(id)),
  data: (c) => Text(c.title),
)
```

**4. Text dịch + điều hướng**

```dart
final t = ref.watch(trProvider);
Text(t('cart.title', {'count': 3}));
context.go(Routes.courses);                 // đổi tab (stack: Home, Courses)
context.push(Routes.classDetail(classId));  // mở màn chi tiết
```

## Thêm một màn mới

1. Thêm path vào `core/router/routes.dart`.
2. Thêm `GoRoute` vào `app/router.dart`.
3. Tạo `features/<x>/` theo khuôn 4 file ở trên.

## Quy tắc giữ parity với bản RN

- Không retry mutation (giỏ, checkout, tạo link). `ProviderScope(retry: ...)` đã tắt retry tự động.
- Không optimistic update: state giỏ chỉ đổi theo response server.
- Chỉ `order.status == PAID` từ backend mới mở ticket thành công.
- Bản preview (CASH_PREVIEW) không bao giờ giữ meeting URL.
- Thời gian luôn hiển thị theo `timeZone` của response. Ngày `YYYY-MM-DD` giữ nguyên chuỗi.
- Màu chỉ lấy từ `AppColors`. Vùng Home/Cart/Course detail/Catalog bọc `RegionColors.*`.
- Chỗ nào còn `TODO(UI)` thì UI đang ở dạng khung, cần port chi tiết từ file RN được ghi kèm.
