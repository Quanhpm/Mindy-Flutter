# Plan: Đưa UI Học viên (Flutter) khớp 100% với React Native

> Tạo: 02/11/2026. Dành cho AI/dev thực hiện. Đọc hết mục 0–2 trước khi sửa code.

## 0. Mục tiêu và nguyên tắc bắt buộc

**Mục tiêu:** mọi màn role STUDENT trong `MindyFlutter` phải **y chang** bản React Native `MindyMobile` về bố cục, màu, cỡ chữ, khoảng cách, bo góc, bóng đổ, icon, thứ tự các khối, trạng thái (loading / empty / error / disabled) và hành vi cuộn. Hai app chạy trên cùng một máy thì chụp màn hình phải gần như trùng nhau.

**Nguồn sự thật duy nhất là code RN** trong `MindyMobile/src`, không phải file thiết kế HTML và không phải `MindyFlutter/docs/UI.md`. Nếu RN khác thiết kế HTML thì vẫn làm theo RN.

Nguyên tắc:

1. **Port từng dòng, đừng "phỏng theo".** Với mỗi màn, mở file RN tương ứng và đi lần lượt từng `<View>` / `<Text>`, dịch từng class Tailwind sang Flutter theo bảng ở mục 2. Không tự thêm, bỏ hay sắp xếp lại khối nào.
2. **Không đổi logic, API, provider hay router**, trừ khi RN có hành vi UI mà Flutter thiếu (ví dụ ẩn tab bar khi cuộn). Data layer của Flutter (`*_api.dart`, `*_providers.dart`, `*_models.dart`) đã chạy đúng, giữ nguyên.
3. **Text lấy qua i18n key giống hệt RN** (`t('home.title')`…). Key thiếu trong `assets/i18n/vi.json` / `en.json` thì copy từ i18n của RN (`MindyMobile/src/**/i18n` hoặc `locales`), đừng tự viết câu mới.
4. **Mọi `testID` bên RN thành `Key('<testID>')` bên Flutter** (ví dụ `Key('home-join-class-button')`), để test và so sánh dễ dàng.
5. **Chỉ dùng token màu `AppColors`.** Bảng màu đã copy đúng từ `src/theme/colors.ts`, không viết màu literal (trừ khi cần alpha: `AppColors.canvas.withValues(alpha: .6)`).
6. **Không đụng phần Mentor/Staff** (`features/mentor/**`, `core/ui/staff/**`, `login_screen.dart`).
7. Sau mỗi phase: chạy `flutter analyze`, `flutter test`, tạo golden mới (mục 12) rồi mới sang phase sau.

## 1. Bản đồ file

Thư mục gốc: `/Users/FPTU/Ki 8/WDP/MINDY-BE/` (`RN = MindyMobile/src`, `FL = MindyFlutter/lib`).

| Khu vực | RN (nguồn) | Flutter (đích) |
| --- | --- | --- |
| Token màu | `RN/theme/colors.ts`, `MindyMobile/global.css`, `tailwind.config.js` | `FL/core/theme/app_colors.dart` (đã khớp) |
| Kiểu chữ | `global.css` `@layer components` | `FL/core/theme/app_theme.dart` (`AppText`) |
| Motion | `RN/theme/motion.ts` | `FL/core/theme/app_theme.dart` (`Motion`) |
| Header brand | `RN/components/common/BrandBar.tsx` | **chưa có**, tạo `FL/core/ui/brand_bar.dart` |
| Tab bar | `RN/components/common/AppTabBar.tsx` | `FL/core/ui/tab_bar.dart` |
| Khung màn học tập | `RN/modules/my-classes/components/LearningLayout.tsx` (`LearningLayout`, `LearningState`) | **chưa có**, tạo `FL/core/ui/learning_layout.dart` |
| Thẻ khoá học | `RN/components/common/CourseTile.tsx`, `CourseCover.tsx`, `CoverImage.tsx` | `FL/features/courses/course_tile.dart`, `FL/core/ui/cover_image.dart` |
| Nút | `RN/components/ui/Button/index.tsx`, `RN/modules/home/components/HomeButton.tsx` | `FL/core/ui/button.dart`, `FL/core/ui/paper_button.dart` |
| Nhấn co giãn | `RN/components/common/PressableScale.tsx` | `FL/core/ui/pressable.dart` |
| Trạng thái | `RN/components/common/ScreenState.tsx`, `RN/components/ui/Skeleton` | `FL/core/ui/states.dart` |
| Bottom sheet | `RN/components/common/AppSheet.tsx` | `showAppSheet` trong `FL/core/ui/cover_image.dart` |
| Icon | `RN/components/common/Icon.tsx` | `FL/core/ui/icon.dart` |
| Trang chủ | `RN/modules/home/StudentHome.tsx`, `ProductionStudentHome.tsx`, `components/HomeCarousel.tsx`, `HomeCompiler.tsx`, `HomeButton.tsx` | `FL/features/home/home_screen.dart`, `home_sections.dart` |
| Khoá học | `RN/modules/courses/CoursesScreen.tsx`, `CoursesRoute.tsx`, `components/Recommendations.tsx`, `FilterSheet.tsx`, `CourseSheet.tsx`, `ShoppingSheets.tsx` | `FL/features/courses/courses_screen.dart`, `course_sheet.dart` |
| Giỏ hàng | `RN/modules/cart/components/CartSheet.tsx` | `FL/features/cart/cart_sheet.dart` |
| Lịch học | `RN/modules/schedule/ScheduleScreen.tsx` | `FL/features/schedule/schedule_screen.dart` |
| Tài khoản | `RN/modules/account/AccountScreen.tsx` | `FL/features/account/account_screen.dart` |
| Lớp của tôi | `RN/modules/my-classes/MyClassesScreen.tsx` | `FL/features/my_classes/my_classes_screen.dart` |
| Chi tiết lớp / buổi | `RN/modules/my-classes/ClassDetailScreen.tsx`, `SessionDetailScreen.tsx`, `components/LearningHero.tsx`, `MeetingButton.tsx`, `ClassParticipantsSheet.tsx` | `FL/features/my_classes/class_detail_screen.dart` (tách thêm file nếu cần) |
| Thanh toán | `RN/modules/payment/PaymentScreen.tsx`, `components/PaymentResultTicket.tsx` | `FL/features/payment/payment_screen.dart`, `payment_result_ticket.dart` |
| Đăng ký / Welcome (tuỳ chọn, mục 11) | `RN/modules/auth/**` (`AuthShell.tsx`, `RegisterScreen.tsx`, `WelcomeScreen.tsx`) | `FL/features/auth/auth_shell.dart`, `register_screen.dart`, `welcome_screen.dart` |

Ảnh tham chiếu đã được owner duyệt: `MindyMobile/docs/IMPLEMENT/PHASE_0x/references/`.

## 2. Bảng quy đổi NativeWind → Flutter

RN dùng đơn vị dp, Flutter dùng logical px: **1 : 1**.

| NativeWind | Flutter |
| --- | --- |
| `p-[16px]`, `px-[16px]`, `pt-[8px]`, `gap-[12px]`, `mt-[2px]` | `EdgeInsets` / `SizedBox` đúng số đó. `gap` → `SizedBox` giữa các con (hoặc `spacing:` của `Row`/`Column`/`Wrap` nếu Flutter ≥ 3.27) |
| `-mt-[28px]` (margin âm) | `Transform.translate(offset: Offset(0,-28))` hoặc `Stack` chồng lên. Không bỏ qua |
| `-mx-[6px]` + con `px-[6px]` `w-1/2` | lưới 2 cột, khe giữa 12, không có lề thừa: dùng `Wrap(spacing: 12, runSpacing: 12)`, mỗi con rộng `(W-12)/2` |
| `rounded-[20px]` / `rounded-full` / `rounded-t-[28px]` | `BorderRadius.circular(20)` / `999` hoặc `BoxShape.circle` / `BorderRadius.vertical(top: Radius.circular(28))` |
| `border` / `border-2` / `border-[1.5px]` + `border-line` | `Border.all(width: 1/2/1.5, color: AppColors.line)` |
| `border-b border-line`, `border-l-2` | `Border(bottom: BorderSide(...))`, `Border(left: BorderSide(width: 2, ...))` |
| `border-dashed` | vẽ bằng `CustomPainter` (Flutter không có border nét đứt sẵn) |
| `text-xs` 12 · `text-sm` 14 · `text-base` 16 · `text-lg` 18 · `text-xl` 20 · `text-2xl` 24 · `text-3xl` 30 · `text-[15.5px]` | `fontSize` đúng số đó |
| `font-nunito` / `-semibold` / `-bold` / `-extrabold` | `FontWeight.w400` / `w600` / `w700` / `w800` (family Nunito là mặc định của theme) |
| `leading-[30.2px]` | `height: 30.2 / fontSize` |
| `tracking-[-0.54px]` | `letterSpacing: -0.54` |
| `tracking-tight` (−0.025em) | `letterSpacing: -0.025 * fontSize` (ví dụ 30px → −0.75; `AppText.sectionTitle` hiện để −0.5, **sửa thành −0.75**) |
| `tracking-[0.14em]` | `letterSpacing: 0.14 * fontSize` |
| `uppercase` | `.toUpperCase()` trên chuỗi |
| `text-canvas/45`, `bg-canvas/60`, `bg-mint/25`, `bg-forest-deep/45` | `AppColors.x.withValues(alpha: .45)`… |
| `opacity-50` / `opacity-40` | `Opacity(opacity: .5)` |
| `shadow-md shadow-forest/10` | `BoxShadow(color: forest @10%, blurRadius: 6, offset: (0,4))` |
| `shadow-lg shadow-forest/20` (hoặc `/25`, `/30`) | `BoxShadow(color: forest @20%, blurRadius: 15, offset: (0,10))` |
| `shadow-xl shadow-forest/20` | `BoxShadow(color: forest @20%, blurRadius: 25, offset: (0,20))` |
| `aspect-[3/4]`, `aspect-video`, `aspect-[4/3]` | `AspectRatio(aspectRatio: 3/4 \| 16/9 \| 4/3)` |
| `absolute inset-x-[12px] bottom-…` | `Positioned(left: 12, right: 12, bottom: …)` trong `Stack` |
| `numberOfLines={3}` | `maxLines: 3, overflow: TextOverflow.ellipsis` |
| `flex-1` trong row | `Expanded` · `shrink` → `Flexible` · `min-w-[0px]` → không cần |
| `min-h-[44px]` | `ConstrainedBox(constraints: BoxConstraints(minHeight: 44))` |
| `rotate-45` | `Transform.rotate(angle: pi/4)` |
| `StatusBar barStyle="light-content" backgroundColor=mint` | `AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light.copyWith(statusBarColor: AppColors.mint))` |
| `useSafeAreaInsets()` | `MediaQuery.paddingOf(context)` |
| `useWindowDimensions().fontScale > 1.2` | `MediaQuery.textScalerOf(context).scale(1) > 1.2` |
| `useReducedMotion()` | `Motion.reduced(context)` |

Kiểu chữ dùng chung (`global.css`): `.section-title` = 30 / w800 / tracking-tight / foreground · `.eyebrow` = 12 / w800 / UPPERCASE / 0.14em / mint · `.text-link` = 14 / w800 / mint · `.body-text` = 16 / w400 · `.caption` = 14 / w400 / muted-foreground.

## 3. Hiện trạng: các chỗ lệch đã xác nhận

Những điểm dưới đây đã đối chiếu trực tiếp với code. Còn lệch nhỏ khác thì phát hiện trong lúc port từng dòng.

- **Chung:** Flutter không có header mint `BrandBar`. Mọi màn chỉ có tiêu đề chữ trên nền trắng và `Scaffold.bottomNavigationBar` cố định.
- **CourseTile:** Flutter là thẻ trắng có viền, ảnh 16:10, chữ đen bên dưới, thêm eyebrow danh mục. RN là thẻ 3:4 ảnh phủ kín, gradient tối, chữ trắng đè lên ảnh, mũi tên cam, lưới 2 cột.
- **Tab bar:**
  - RN nổi (`absolute inset-x-[12px]`, `bottom = max(insets.bottom - 12, 0)`) và ẩn khi cuộn ở Home. Flutter tràn hết ngang và ăn trọn safe area.
  - Flutter thiếu `px-[4px]` cho hàng tab.
  - Logic `enabled` khác: RN chỉ bật Lịch học / Tài khoản khi `learningEnabled`, và `roomy` chỉ áp dụng khi `learningEnabled`.
- **Home:**
  - Thiếu hero mint, mascot, header thu gọn, ẩn tab bar khi cuộn.
  - Thẻ buổi tiếp theo sai màu (soft thay vì sunshine), thiếu nút Vào lớp / Xem trước, thừa tiêu đề section.
  - Khoá học hiện 1 cột thay vì 2.
  - Nút Khám phá không phải `HomeButton`.
  - Khối About và Footer không tràn hết ngang (bị padding 20 của ListView).
  - Footer thiếu dòng liên hệ, nút Đăng xuất (`sessionControls`) và border-top của copyright.
  - Intro carousel bỏ khung ảnh teal 4:3.
- **Khoá học:**
  - Thiếu BrandBar. Thứ tự sai: RN là Gợi ý → Danh mục (tiêu đề + nút lọc) → lưới → phân trang.
  - Nút lọc không phải nút tròn có viền, thiếu chấm coral.
  - Chip danh mục bo 999 thay vì 12, cao không đúng 38.
  - Gợi ý dùng CourseTile thay vì thẻ `Recommendations` có ruy-băng góc.
- **Lịch học:**
  - Sai cấu trúc. RN: header ‹ tháng › + lưới 7 ngày chia đều, danh sách **cả tuần** gom theo ngày, cột ngày bên trái tô xen kẽ soft/peach.
  - Flutter: link chữ, chip cuộn ngang, chỉ hiện một ngày.
- **Tài khoản:** sai hoàn toàn. RN có hero mint với avatar sunshine 88, nội dung bo trên 28 đè lên hero, các nhóm menu nền soft, sheet hồ sơ / ngôn ngữ / đăng xuất. Flutter dùng ListTile Material.
- **Lớp của tôi:**
  - Thiếu header nút back tròn và tiêu đề giữa.
  - Thiếu khối "thư mục" khoá học thu gọn / mở (`bg-soft rounded-18`, icon folder) và các dòng enrollment thụt lề có `border-l-2`.
- **Chi tiết lớp / buổi:** thiếu hero forest-deep với vòng tròn mint/25, nội dung bo trên 28 đè hero, ô người tham gia, `sessionDisplayStatus`, chi tiết buổi nền `cover-a-soft`.
- **Thanh toán:** thiếu mảng thông tin chuyển khoản, toast forest, sheet rời trang. Ticket kết quả thiếu mép xé và đường kẻ nét đứt.

## 4. Phase 1: Component dùng chung (làm trước, các màn khác phụ thuộc)

### 1.1 `BrandBar` (mới: `FL/core/ui/brand_bar.dart`)

Port từ `BrandBar.tsx`:
- Row `px-14 pt-2`: ô trống 44 bên trái | giữa `Expanded` căn giữa | nút giỏ 44×44 bên phải.
- Giữa là một `Pressable` (`minHeight 44`, gọi `onTop`), chứa hai dòng chữ:
  - `t('home.brand.name')`: 19 / w800 / height 19/19 / letterSpacing −0.19 / canvas.
  - Cách 2, `t('home.brand.subtitle')`: 10.5 / w800 / height 11/10.5 / letterSpacing 2.52 / sunshine.
- Nút giỏ: icon `cart` màu sáng. Badge `absolute right 2 top 4`, `minWidth 18`, nền coral, viền 2 mint, bo full, `px 4`, chữ 11 / w800 / canvas, quá 9 thì hiện `9+`.
- Props: `onTop`, `onCart` (null = disabled, opacity theo `PressableScale`), `cartCount`, `compact`.
- Nền mint do nơi dùng tự bọc (`Container(color: AppColors.mint)`).

### 1.2 `AppTabBar` (sửa `FL/core/ui/tab_bar.dart`)

- **Bỏ `SafeArea` bên trong.** Tab bar không còn nằm ở `Scaffold.bottomNavigationBar` cho Home / Courses. Nơi dùng đặt nó trong `Stack`: `Positioned(left: 12, right: 12, bottom: max(insets.bottom - 12, 0))`.
- Trong `LearningLayout` (Schedule / Account / MyClasses / ClassDetail), RN đặt tab bar **trong luồng** ở cuối `SafeAreaView` (edges top + bottom), không nổi. Port đúng như vậy.
- Kích thước: tổng cao 96 (roomy 116), nền trắng cao 68 (roomy 88), bo 26, `shadow-xl forest/20`, hàng tab `px 4`.
- Thêm prop `learningEnabled` (mặc định false) và `onTab` (nullable). Công thức `enabled` lấy y RN: home luôn bật; courses bật khi có `onTab`; schedule / account bật khi có `onTab` **và** `learningEnabled`; notifications luôn tắt. `roomy = learningEnabled && (width <= 360 || fontScale >= 1.3)`.
- Tab tắt: RN không giảm opacity cho tab bar (chỉ disabled). Bỏ `Opacity(0.5)` hiện có, trừ khi so screenshot RN thấy có mờ.
- Nút Home 78×78, viền 6 canvas, nền `action` khi đang chọn, ngược lại nền `mint`, `shadow-lg forest/30`, icon 30 sáng. Bấm thì luôn gọi `onTop` (RN: `id === 'home' ? onTop()`).
- Thêm `Key('${prefix}-tab-$id')`.

### 1.3 `LearningLayout` + `LearningState` (mới: `FL/core/ui/learning_layout.dart`)

Port từ `LearningLayout.tsx`:
- Bọc `SafeArea(top + bottom)`, nền canvas.
- `tintedStatusBar`: status bar chữ sáng, phía sau là dải màu cao `insets.top` (mint, hoặc forest-deep khi `statusTintTone == forest`).
- Không có `onBack` thì có header `BrandBar` nền mint (`onTop` → tab home, `onCart: null`).
- `showTitle`: row `px 16 py 12 gap 8`, gồm nút back ghost (nếu có) + tiêu đề 22 / w800 / height 28/22 / forest.
- Slot `header`, rồi vùng cuộn (`padding: px16 pb24`, gap 16, hoặc `contentClassName` override), có `RefreshIndicator` nếu có `onRefresh`.
- Slot `footer` (thường hoặc nổi: `floatingFooter` → `Positioned(bottom: insets.bottom)`).
- Cuối cùng là `AppTabBar(learningEnabled: true)` nếu có `tab`.
- `LearningState`:
  - loading lần đầu → 3 skeleton cao 100 bo 18, gap 16.
  - error lần đầu → `ScreenState`.
  - có data nhưng error → `ScreenState(title: learning.stale)` + nội dung.
  - đang refresh → dòng chữ `learning.refreshing` 14 muted.
  - empty → `ScreenState('<ns>.state.empty')`.

### 1.4 `CourseTile` (viết lại `course_tile.dart`)

Port từ `CourseTile.tsx`:
- Ô ngoài có `padding: horizontal 6, bottom 12` khi đứng trong lưới. Nên cho nơi gọi tự quyết lưới, còn tile chỉ là thẻ.
- Thẻ: `ClipRRect` bo 20, nền soft.
  - Lớp dưới: `CoverImage(url, fallback: CourseCover(index))`, `hideLabel`.
  - Lớp phủ: gradient dọc forestDeep, stop 0 → 0.45 → 1 với alpha 0 → .82 → .95.
  - Khối chữ: `px 12 pb 12 pt 44`, nằm `absolute bottom` (khi `fontScale > 1.2` thì nằm trong luồng với nền forestDeep):
    - nếu có `openClass`: `deliveryMode + t('home.starts', {date})`, 11 / w800 / sunshine.
    - `mt 3`, title 15 / w800 / height 18.8/15 / canvas, tối đa 3 dòng (không giới hạn khi chữ lớn).
    - `mt 8`, `mr 36`, giá `formatVnd`, 15 / w800 / canvas.
  - Nút mũi tên: `absolute bottom 7 right 7`, ô 44×44, chứa icon `arrow` 22 màu `action`.
- Tỉ lệ thẻ: theo `CourseCover` / `CoverImage` của RN (skeleton RN là `aspect-[3/4]`). Kiểm tra `CourseCover.tsx` và `CoverImage.tsx` để lấy đúng tỉ lệ ảnh và fallback.
- **Bỏ** eyebrow danh mục, viền, nền trắng và dòng "bắt đầu · giá" gộp.
- Key: `${prefix}-course-${id}`, `${prefix == 'home' ? 'home-course-open' : 'courses-open'}-${id}`.

### 1.5 `HomeButton` (nút "giấy")

`paper_button.dart` đang được dùng cho intro. Port đúng `HomeButton.tsx`:
- Lớp bóng đen phía sau dịch xuống 4px, bo full.
- Nút: viền 2 đen, nền canvas, `minHeight 46`, `px 22 py 8`, gap 12; chữ 14 / w800 / đen; icon `arrow` 18 đen.
- Nhấn thì dịch xuống 3px trong 120ms. Disabled thì `opacity .5`.
- So lại `PaperButton` hiện có, sửa cho khớp hoặc tạo `HomeButton` riêng.

### 1.6 Kiểm tra lại các thành phần nhỏ

- **`MindyButton`** (`button.dart`) vs `Button/index.tsx`:
  - `minHeight 54`, `px 24 py 12`, bo full, gap 8.
  - default: nền primary có gradient SVG + `shadow-lg forest/25`. Đối chiếu đúng màu và hướng gradient trong RN dòng 64–100.
  - outline: viền 1.5 banner. solid: forest. action: nền action, **chữ đen**. ghost.
  - Chữ 16 / w800. Chữ đen khi outline / ghost / action.
  - Cho phép override chiều cao / padding / bo góc, vì RN hay truyền `className` (ví dụ `min-h-[44px] rounded-[12px] px-[14px] py-[8px]`): thêm tham số `minHeight`, `padding`, `radius`.
- **`ScreenState`**, **`Skeleton`**: so với `ScreenState.tsx` và `Skeleton/index.tsx` (màu, bo, padding, nút retry, dòng requestId).
- **`showAppSheet`** vs `AppSheet.tsx`:
  - nền mờ `forestDeep @45%`.
  - sheet bo trên 28, nền canvas.
  - handle 40×5, bo 9, màu line, vùng handle `pt 10 pb 14`.
  - Tắt `showDragHandle` mặc định của Material, tự vẽ handle.
- **`MindyIcon`**: đối chiếu đủ tên icon RN dùng (`grid`, `calendar`, `home`, `bell`, `user`, `cart`, `arrow`, `filter`, `back`, `book`, `folder`, `folder-open`, `check-calendar`, `eye`…) và path SVG phải giống. Prop `light` của RN = màu canvas.
- **`Pressable`**: RN `PressableScale` không đổi opacity khi disabled. Chỗ nào RN có `opacity-50` / `opacity-40` thì tự thêm.

**Xong Phase 1 khi:** có golden riêng cho `BrandBar`, `AppTabBar` (home selected, courses selected, roomy), `CourseTile` (có ảnh, fallback, có openClass, chữ lớn).

## 5. Phase 2: Trang chủ (`home_screen.dart`, `home_sections.dart`)

Port từ `StudentHome.tsx`, đọc kèm `ProductionStudentHome.tsx` để biết action và footer.

Cấu trúc bắt buộc là `Stack` gồm (1) `CustomScrollView`/`ListView` **không có padding ngang chung**, (2) header thu gọn nổi, (3) tab bar nổi. Bỏ `Scaffold.bottomNavigationBar` và `SafeArea` bao ngoài.

1. **Status bar:** chữ sáng, nền mint.
2. **Hero** (`Key('home-header')`): nền mint, `paddingTop = insets.top`, `minHeight = insets.top + 190`, `pb 26`.
   - `BrandBar(onTop: top, onCart, cartCount)`.
   - Khối chào: `pl 18 pt 18`, `maxWidth` = `width < 360 ? width - mascotW - 4 : 218`.
     - `home.greeting` (14 / w700 / line).
     - `mt 12`, `home.title` (27 / w800 / height 30.2/27 / letterSpacing −0.54 / canvas, semantics header).
   - Mascot `mindy-mascot-laptop.png`, rộng `width < 360 ? 128 : 196`, cao = rộng × 0.8, contain, `Positioned(bottom: -14, right: -4)`. Hero cho phép tràn (`clipBehavior: none`).
3. **Lỗi refresh:** có `refreshError` thì hiện `ScreenState` trong `px 16 pt 16`.
4. **Buổi tiếp theo** (`Key('home-next-session')`): **chỉ hiện khi** status ≠ success **hoặc** có buổi. Không có buổi thì ẩn hẳn, không hiện nút Khám phá.
   - Hộp: `mx 16 mt 26`, bo 20, nền **sunshine**, `px 16 py 14`.
   - Lỗi → `ScreenState`. Loading → skeleton cao 72, bo 20, nền sunshine @50%.
   - Có data → `Wrap`, căn giữa theo trục dọc, gap 12:
     - Cột trái (`minWidth 144`, flex): dòng 1 `home.sections.nextSession · <giờ dd/MM HH:mm theo timeZone>` (12 / w800 / forest); `mt 2` dòng 2 `className · sessionTitle` (15.5 / w800 / đen, tối đa 2 dòng).
     - Nút `Button variant solid`, `minHeight 44`, bo 12, `px 14 py 8`. Nhãn `home.actions.previewClass` nếu `accessMode == CASH_PREVIEW`, ngược lại `home.actions.join`. Key `home-join-class-button`. Hành động: mở chi tiết lớp / buổi (giống `actions.onSession` RN).
   - **Không** có tiêu đề section riêng phía trên.
   - Model `homeNextSessionProvider` phải có `className`, `accessMode`. Thiếu thì bổ sung từ response (RN `home.service.ts`).
5. **Khoá học nổi bật** (`Key('home-featured-courses')`): `px 16 pt 28`.
   - Tiêu đề `home.sections.courses` (22 / w800 / letterSpacing −0.44 / đen, `mb 14`).
   - Lưới **2 cột** `CourseTile`. Loading = 4 skeleton 3:4 bo 20.
   - Empty → `ScreenState(home.empty.*)`.
   - `mt 16`: `HomeButton(home.actions.explore, minHeight 52)`.
6. **`HomeCarousel kind="intro"`:** port đúng `HomeCarousel.tsx`.
   - Tiêu đề 28 / w800 / height 30.8/28 / letterSpacing −0.84, có đoạn chữ mint.
   - Slide có khung ảnh `bg-teal p-9 shadow-lg mb-18`, ảnh `aspect-[4/3]` (placeholder `canvas/60`), hai vòng tròn trang trí `canvas/10` và `canvas/5`, mascot theo `mascotClasses[index]`, mô tả 14.5 / height 23.2, nút giấy.
   - Phân trang / chấm / pause đúng RN.
   - **Khôi phục khung ảnh** mà Flutter đang cố ý bỏ (xem mục 13).
7. **`HomeCompiler`:** port đúng `HomeCompiler.tsx`.
   - Hộp ngoài `mx 16 mt 44`, tiêu đề 21 / w800 / height 25.2/21.
   - Terminal: thanh trên `forest-night px 9 py 8`, ba chấm 7px; thân `px 10 pb 14 pt 10`, chữ 8.5 / height 15.3/8.5 **màu sunshine** (đối chiếu từng dòng màu); con trỏ khối 5×10 canvas.
   - Nút `mt 16 self-end`.
8. **`HomeCarousel kind="about"`:** tràn hết ngang, đúng padding / xoay / băng dính như RN.
9. **Footer** (`Key('home-footer')`): **tràn hết ngang**, nền forest, `px 16 pt 28`, `paddingBottom = 130 + insets.bottom` (chừa chỗ cho tab bar nổi).
   - Logo: ô 30 bo 9 nền canvas, chữ initial 16 / w800 / forest; gap 8; tên brand 17 / w800 / canvas.
   - Tagline (`mt 10 mb 18`, 14 / height 21.7/14 / line).
   - Cột rộng 1/2, gap 8: `home.footer.learn` (13 / w800 / sunshine), 3 link (14 / w400 / canvas, `minHeight 44`) với key `home-footer-courses`, `home-footer-schedule`, `home-my-classes`.
   - `mt 18`: `home.footer.contact` (13.5 / height 23/13.5 / line).
   - `sessionControls` (từ `ProductionStudentHome.tsx`): `mt 16`, gap 12, `ScreenState` lỗi logout (nếu có) + `Button` đăng xuất `auth.session.logout`, key `session-logout`.
   - Copyright: `mt 16`, border-top 1 canvas @20%, `pt 12`, 12 / banner.
10. **Header thu gọn** (`Key('home-compact-header')`):
    - `Positioned(top: 0, left: 0, right: 0)`, nền mint, `paddingTop = insets.top`, `pb 8`, `shadow-lg forest/20`, chứa `BrandBar(compact: true)`.
    - Hiện khi `scrollY > 150`: opacity 0 → 1, `translateY -(insets.top + 52)` → 0, 200ms, `Motion.curve`.
    - Khi ẩn thì `IgnorePointer` + `ExcludeSemantics`.
11. **Ẩn / hiện tab bar khi cuộn:**
    - `y < 20` hoặc `delta < -3` → hiện. `y > 60` và `delta > 3` → ẩn (translateY 160, 200ms).
    - Không ẩn khi bật reduce motion hoặc screen reader (`MediaQuery.accessibleNavigation`).
    - Bấm Home / logo → cuộn lên đầu và hiện lại tab bar.
12. `RefreshIndicator` màu mint.

## 6. Phase 3: Khoá học, sheet, giỏ hàng

### 3.1 `courses_screen.dart` ← `CoursesScreen.tsx` + `CoursesRoute.tsx`

Cấu trúc: `Stack` gồm cột (header + vùng cuộn) và tab bar nổi.

1. Status bar sáng / mint. Header (`Key('courses-header')`): nền mint, `paddingTop = insets.top`, `pb 8`, `shadow-lg forestDeep/20`, chứa `BrandBar(prefix: 'courses', onTop: về home, onCart, cartCount)`.
2. Vùng cuộn: `paddingBottom = 100 + insets.bottom`, nội dung `pt 20`, gap 22 giữa các khối.
3. **Gợi ý (đứng đầu):** loading = skeleton `mx 16`, cao 206, bo 24; error = `ScreenState`; data = `Recommendations` (3.2).
4. **Danh mục** (`Key('courses-categories')`):
   - Row `mx 16`, space-between: tiêu đề `courses.categories.title` (20 / w800 / đen) và nút lọc tròn 42×42 viền line, icon `filter` 19 đen, chấm coral 9×9 viền 2 canvas ở `top 6 right 7` khi có `deliveryMode` (`Key('courses-filter-dot')`).
   - Bên dưới: hàng chip cuộn ngang (`px 16 pt 12 pb 2`, gap 8). Chip cao 38, **bo 12**, `px 16`. Đang chọn: nền forest, chữ canvas; còn lại: nền soft, chữ forest; chữ 14 / w800.
   - Loading = 4 skeleton 76×38 bo 12.
   - Ghi nhớ vị trí y của khối này: đổi trang thì cuộn về đây (không animate).
5. **Lưới** (`px 16`): 2 cột `CourseTile(prefix: 'courses')`, tối đa 6 khoá. Loading = 6 skeleton 3:4 bo 20.
   - Empty: hộp bo 16, nền soft, `p 24`, chữ giữa 14 / w700 / muted. Nếu đang lọc thì có link `courses.grid.clearFilter` (14 / w800 / mint), bấm thì xoá cả category lẫn filter.
   - Bỏ logic "1 cột khi < 340px". RN luôn 2 cột.
6. **Phân trang:** nút tròn 40.
   - Đang chọn: nền mint. Disabled: viền line, opacity .4. Thường: nền soft.
   - Có nút ‹ ›, dấu `courses.pagination.ellipsis` (theo công thức `pageItems` của RN: hiện hết khi ≤ 5 trang, không thì hiện trang 1, trang cuối và các trang cách trang hiện tại ±1).
   - So `page_numbers.dart` với hàm `Page` của RN (màu chữ ở phần cuối file RN).
7. Bỏ tiêu đề "Khoá học" kiểu sectionTitle và hai icon trên header cũ.
8. Tab bar nổi: `selected: courses`, `learningEnabled` theo RN (`!!props.onLearningTab`, xem `CoursesRoute.tsx`).

### 3.2 `Recommendations` (mới, ← `Recommendations.tsx`)

Tiêu đề `mx 16`, 20 / w800 / letterSpacing −0.4 / đen. Carousel thẻ:
- Thẻ: `relative`, bo 24, nền soft, `p 14`, `shadow-md forest/10`.
- Ảnh `aspect-video`, bo 18.
- Ruy-băng góc: hộp `absolute -top-7 -right-7`, 104×104, cắt tràn. Bên trong là dải `bg-ribbon`, rộng 156, `rotate 45`, `-right 32 top 26`, `py 7`, viền trên / dưới **nét đứt** canvas @45%, chữ 10 / w800 / letterSpacing 1.4 / canvas. Hai ô gấp 7×7 `ribbon-fold` ở `left 6 top 0` và `right 0 bottom 6`.
- Khối chữ: gap 5, các cỡ 13 / 12 / 12.5 / 20 như RN.
- Nút `mt 8`, `minHeight 36`, bo full, viền line, nền canvas @90%, `px 16`.
- Chấm trang: `pt 12`, gap 8.

Đọc đủ file để lấy thứ tự chữ và key.

### 3.3 `FilterSheet` ← `FilterSheet.tsx`

Thay `_FilterSheet` hiện tại, port đúng bố cục, nút và đếm số khoá.

### 3.4 `course_sheet.dart` ← `CourseSheet.tsx` + `ShoppingSheets.tsx`

Port từng dòng (465 + 113 dòng RN): ảnh, thông tin, danh sách lớp, chọn lớp, CTA thêm giỏ / mua, các sheet phụ. Giữ `RegionColors.courseDetail` (forest / muted / mint → đen) như RN.

### 3.5 `cart_sheet.dart` ← `CartSheet.tsx`

Port từng dòng, giữ `RegionColors.cart`.

## 7. Phase 4: Lịch học (`schedule_screen.dart` ← `ScheduleScreen.tsx`)

Dùng `LearningLayout(tab: schedule, showTitle: false, tintedStatusBar: true, header: calendarHeader, contentPadding: zero, pb 20)`.

1. **`calendarHeader`** (cố định, không cuộn): nền canvas, `px 16`.
   - Row `py 10`, space-between:
     - Nút tròn 44 viền line, chữ `schedule.previous` 22 / w800 / mint (`Key('schedule-prev-week')`).
     - Giữa `Expanded`, `minHeight 44`: tên tháng 16 / w800 / đen căn giữa, bấm thì về hôm nay (`Key('schedule-today')`).
     - Nút tròn 44 `schedule.next` (`Key('schedule-next-week')`).
   - Lưới 7 ngày **chia đều** (không cuộn), border-bottom line. Mỗi ô `minHeight 84`, gap 4: thứ (11 / w700 / muted), số ngày, chấm có buổi. Lấy đúng class đang chọn / hôm nay / thường trong RN dòng ~139–188. `Key('schedule-day-<yyyy-mm-dd>')`.
2. **Danh sách cả tuần:** không lọc theo ngày đang chọn. Chọn ngày thì **cuộn tới nhóm của ngày đó** (lưu offset mỗi nhóm bằng `GlobalKey` / `Scrollable.ensureVisible`).
   - Ngày được chọn mà không có buổi: dòng `schedule.noSessionsOnDay` (`p 16`, 14 / muted, `Key('schedule-empty-day')`).
   - Bọc bằng `LearningState`.
3. **Nhóm ngày** (chỉ những ngày có buổi): `Row`.
   - Cột trái rộng 72 (56 khi `compact`), `pt 16 px 4`, gap 4, nền **xen kẽ soft / peach** theo thứ tự nhóm.
   - Chữ `dd/MM` (21 / w800 / đen; compact: 17 và xuống dòng `dd\n/MM`), rồi thứ (12 / đen).
   - Cột phải `pl 10 pr 16`, mỗi buổi là một khối `minHeight 64`, `py 14`, border-bottom line, gồm:
     - giờ bắt đầu – kết thúc (12 / w700 / muted, dấu nối 11).
     - ô số buổi (`classDetail.sessionNumber`, 10 / w700 / muted).
     - ô mã lớp (bo 14, nền soft, `px 12 py 8`: nhãn 10 muted + mã 14 / w800 / đen).
     - tên buổi 14 / w700 / đen.
     - phòng / mentor (11.5 / muted, fallback `classDetail.noRoom` / `noMentor`).
     - tag trạng thái + hình thức học (`flex-wrap gap 6`).
   - Port đúng class màu tag ở RN dòng ~260–405. Định nghĩa `compact` lấy trong RN.
   - Bấm buổi → giống RN (mở chi tiết lớp / buổi). Accessibility label ghép như RN dòng ~70–80.
4. Bỏ tiêu đề sectionTitle, các link chữ, chip cuộn ngang và timeline giờ hiện có.

## 8. Phase 5: Tài khoản (`account_screen.dart` ← `AccountScreen.tsx`)

`LearningLayout(tab: account, showTitle: false, …)`. Kiểm tra trong RN có `tintedStatusBar` không.

1. **Hero:** nền mint, `px 16 pb 40 pt 8`, căn giữa.
   - Avatar 88×88 bo full, viền 3 canvas, nền **sunshine**, chữ cái đầu 28 / w800 / forest.
   - Nút đổi avatar 32×32 ở `-bottom 4 -right 4`, viền line, nền canvas, disabled kèm hint `account.unavailable`.
   - `mt 8`: tên (20 / w800 / height 26/20 / canvas, `minHeight 44`, bấm thì mở sheet hồ sơ).
   - Dòng phụ 13.5 / height 20/13.5 / canvas (xem RN dòng ~194).
2. **Thân:** `Transform.translate(0, -28)` (hoặc Stack), bo trên 28, nền canvas, `px 16 pt 20 pb 24`, gap 12 giữa các nhóm. Mỗi nhóm bo 18, nền soft, `py 4`, gồm các `Row` item giống hàm row của RN (dòng ~40–80): ô icon 32 bo full nền canvas, nhãn, giá trị phụ bên phải (12 / muted, `maxWidth 100`), mũi tên `schedule.next` 17 / w700 / muted, disabled kèm hint.
   - Nhóm 1: Đơn hàng.
   - Nhóm 2: Sửa hồ sơ, Lớp của tôi, Chứng chỉ, Điểm danh.
   - Nhóm 3: Thông báo đẩy (có switch disabled), Ngôn ngữ, Trợ giúp, Chính sách.
   - Nhóm 4: Đăng xuất.
   - Item nào enabled / disabled thì theo RN.
3. **Sheet** (`showAppSheet`, gap 16):
   - tiêu đề 20 / w800 / forest.
   - **hồ sơ**: hộp bo 18 nền soft `p 16`, gap 12, các field `account.fields.*` (nhãn 12.5 muted, giá trị 14.5 / w700 / forest, `notUpdated` khi rỗng).
   - **ngôn ngữ**: danh sách nút `account.languages.*`, chọn xong thì đóng sheet.
   - **đăng xuất**: nút đăng xuất nền headsup + dòng lỗi 14 headsup.
   - Nút đóng / huỷ ở cuối (`learning.cancel` cho logout, `common.close` cho các sheet khác).
4. Bỏ `ListTile`, `SegmentedButton`, `CircleAvatar` và hiện field trực tiếp trên màn chính.

## 9. Phase 6: Lớp của tôi (`my_classes_screen.dart` ← `MyClassesScreen.tsx`)

`LearningLayout(onBack, showTitle: false, header: header, tab: origin)`. RN có `onBack` nên không có BrandBar.

1. **Header:** row `px 16 pt 10 pb 14`, gap 8.
   - Nút back tròn 44 viền line, icon `back` 18 (`Key('my-classes-back')`).
   - Tiêu đề giữa 18 / w800 / height 24/18 / đen (`myClasses.historyTitle` hoặc `myClasses.title`).
   - Bên phải: ở view history là nút tròn 44 icon `book` 18 (chuyển view), không thì ô trống 44.
   - Đổi view thì cuộn về đầu.
2. **Danh sách khoá dạng thư mục:** một hộp bo 18, nền soft, clip. Mỗi khoá cách nhau bằng border-bottom line (trừ khoá cuối).
   - Hàng khoá (`minHeight 64`, `px 14 py 12`, gap 12, bấm để mở / đóng, semantics expanded):
     - ô icon 34 bo 10: mở → nền mint, icon `folder-open` canvas; đóng → nền canvas, icon `folder` muted; size 19.
     - tên khoá 14.5 / w700 / đen.
     - `code · count` 12 / muted (`myClasses.loaded` khi còn trang, ngược lại `myClasses.count`).
     - ký hiệu bên phải 16 / w600 / muted: `myClasses.collapseSymbol` khi mở, `schedule.next` khi đóng.
   - Khi mở: khối `mb 8 ml 30`, border-left 2 line, `pl 8 pr 10`, gap 6, chứa các `EnrollmentRow`.
3. **`EnrollmentRow`:** hộp bo 12 nền canvas.
   - Phần tóm tắt `minHeight 52`, `px 10 py 8`: mã lớp 14 / w600 / đen; mô tả `delivery · start – end` 11.5 / height 16/11.5 / muted; `myClasses.preview` 11 muted (nếu CASH_PREVIEW); mũi tên 17 / w700 / mint nếu mở được. Toàn bộ là Pressable nếu `canOpen`.
   - Phần dưới (`px 10 pb 10`, gap 6), hiện khi cần:
     - lý do truy cập 11.5 muted (STATE_MISMATCH khi lệch trạng thái).
     - `myClasses.review` 11.5 / w600 / headsup.
     - hạn đơn 11 muted.
     - nút `myClasses.resume` (variant action, `minHeight 44 px12 py8`).
     - nút retry outline khi lệch trạng thái.
   - Logic `enrollmentAction` / `canOpen` / `mismatch` lấy y RN (`RN/modules/my-classes/access.ts`).
4. **Empty:** chữ `myClasses.empty.<view>` 14 muted + `Button(myClasses.explore)`.
   - Còn trang hoặc lỗi tải thêm: `Button outline` (`myClasses.loadMore` / `common.retry`, có loading).
   - Lỗi tải thêm: dòng `myClasses.moreError` 14 headsup.

## 10. Phase 7: Chi tiết lớp và chi tiết buổi

← `ClassDetailScreen.tsx` (579 dòng), `SessionDetailScreen.tsx` (251 dòng), `components/LearningHero.tsx`, `MeetingButton.tsx`, `ClassParticipantsSheet.tsx`, `sessionDisplayStatus.ts`, `nextLearningSession.ts`.

Flutter hiện gộp tất cả trong `class_detail_screen.dart` (239 dòng) ở mức khung. Tách thành `class_detail_screen.dart`, `session_detail_screen.dart`, `learning_hero.dart`, `meeting_button.dart`, `participants_sheet.dart`, rồi port từng dòng. Các mốc chính để đối chiếu:

- **Hero:**
  - nền forest-deep (`statusTintTone: forest`), `px 16 pb 52 pt 4`.
  - vòng tròn trang trí 224×224 mint @25% ở `-right 56 top 30`.
  - tiêu đề 24 / w800 / height 28/24 / canvas, mô tả 14.5 / height 20/14.5 / canvas.
  - badge coral bo full `px 12 py 6` (chữ 12 / w800 / canvas).
- **Thân:** dịch lên −28, bo trên 28, nền canvas, `px 16 pt 24 pb 16`, gap 20.
- **Khối buổi tiếp theo:** bo 12, nền sunshine, `p 14`, gap 8.
- **Hàng thông tin:** bo 18, nền soft, `p 14`, gap 12, row.
- **Avatar người tham gia:** tròn 36 nền sunshine; avatar xếp chồng 44 viền 2 canvas.
- **Nút nổi:** 54×54, viền line, nền canvas, `shadow-lg forest/20`.
- **Footer:** forest-deep `px 16 py 4`.
- **Chi tiết buổi:**
  - nền ngoài `cover-a-soft`, vùng trắng bo trên 28, `pt 20`.
  - header `px 16 pb 20 pt 8` (nút tròn 44 nền canvas, tiêu đề giữa 13 / w600 / forest).
  - tiêu đề 22 / w800, các ô thông tin 2 cột (`w-1/2 px 5 pb 10`; ô bo 14 nền soft `p 12`, `minHeight 64`, gap 5).
  - chip `rounded-full bg-canvas px 10 py 5`.
- Trạng thái buổi phải dùng `sessionDisplayStatus` giống RN (Flutter đã có hàm `sessionDisplayStatus`, kiểm tra cho khớp).

## 11. Phase 8: Thanh toán và ticket kết quả

← `PaymentScreen.tsx` (409 dòng), `PaymentResultTicket.tsx` (225 dòng), `PaymentRoute.tsx`.

- **`PaymentScreen`:**
  - header row `mb 16`: nút tròn 40 viền line, tiêu đề giữa 18 / w800 / đen, ô trống 40.
  - số tiền 28 / w800 / letterSpacing −0.56 / forest.
  - pill đếm ngược nền peach (`px 10 py 4`, chữ ember 12.5 / w700).
  - hộp QR 220 (bo 20, viền line, `p 12`, `shadow-md`), ảnh QR 196×196 bo 10, có trạng thái loading / lỗi / hết hạn với `minHeight 196`.
  - khối thông tin chuyển khoản: bo 18, nền soft, `px 14 py 4`; mỗi dòng có nhãn rộng 96 (12.5 muted) và nút copy pill viền banner (`minHeight 30`).
  - toast `absolute inset-x-20`, bo 14, nền forest, `px 16 py 13`, `shadow-xl forest/30`.
  - nút `minHeight 52` bo 14.
  - sheet xác nhận rời trang (thiếu bên Flutter).
- **`PaymentResultTicket`:**
  - nền tối `black @60%`, ticket `max-w 360` căn giữa, `px 24 pt 24 pb 34`.
  - **mép xé** (vẽ bằng `CustomPainter` / `ClipPath`, xem `ticket_paper.dart` và cách RN vẽ).
  - icon 56, tiêu đề 22 / w800 / forest, mô tả 14 muted.
  - số tiền 28 / w800 / height 34/28 / forest.
  - các dòng chi tiết (border-top line, `pt 16`, gap 6).
  - đường kẻ **nét đứt** (`mt 24 pt 20`).
  - nút `minHeight 52` **bo 2**.

## 12. Phase 9 (tuỳ chọn, hỏi owner trước): Đăng ký / Welcome

`auth_shell.dart` đang có `TODO(UI)` port từ `AuthShell.tsx`. `register_screen.dart` và `welcome_screen.dart` ở mức "Khung". Màn **Login** đã được owner quyết định dùng thiết kế Staff chung (`docs/UI.md` mục 9), **không đổi** nếu không có xác nhận.

## 13. Các điểm Flutter đang cố ý lệch: cần owner chốt

Yêu cầu là khớp 100%, nên mặc định **làm theo RN**. Ghi lại vào `docs/UI.md` mục 9 nếu owner muốn giữ điểm nào:

1. Khung ảnh 4:3 trong Intro carousel. Flutter bỏ vì "RN chưa có artwork". Làm như RN: placeholder `canvas/60`.
2. Tab Lịch học / Tài khoản luôn bật (Flutter) vs chỉ bật khi `learningEnabled` (RN). Làm như RN.
3. Lưới khoá học 1 cột khi màn < 340px / chữ lớn (Flutter). RN luôn 2 cột, CourseTile tự chuyển chữ vào luồng khi `fontScale > 1.2`. Làm như RN.
4. Tab bar cố định ở Home / Courses (Flutter) vs nổi và ẩn khi cuộn (RN). Làm như RN.

## 14. Kiểm tra (bắt buộc cho mỗi phase)

1. **Ảnh RN làm chuẩn:**
   - Chạy `MindyMobile` trên iOS Simulator **iPhone 15 (393×852)** và một máy Android 360dp, đăng nhập cùng tài khoản student dev, cùng ngôn ngữ vi.
   - Chụp mọi màn và trạng thái chính (loading, empty, có data, lỗi, đầu trang, sau khi cuộn quá 150px), lưu vào `MindyFlutter/docs/parity/rn/<screen>_<state>.png`.
   - Tham khảo thêm `MindyMobile/docs/IMPLEMENT/PHASE_0x/references/`.
2. **Ảnh Flutter:** chụp cùng máy, cùng dữ liệu, lưu `docs/parity/flutter/…`. Đặt cạnh nhau (hoặc overlay 50%) để so. Lệch quá 2px hoặc sai màu là chưa đạt.
3. **Golden test:** thêm `test/student_parity_golden_test.dart`, mock provider bằng dữ liệu cố định, chụp mỗi màn ở 390 và 320, vi + en, textScale 1.0 và 1.3. Tên file `test/goldens/student_<screen>_<w>_<lang>.png`.
4. **Widget test:** tìm theo `Key` trùng testID của RN (ví dụ `home-join-class-button`, `courses-filter-dot`, `schedule-day-…`, `my-classes-open-…`). Cập nhật `test/home_widget_test.dart`, `remaining_widget_test.dart` nếu đổi cấu trúc.
5. `flutter analyze` sạch, `flutter test` xanh. Test i18n (`i18n_completeness_test.dart`) phải pass sau khi thêm key.
6. **Accessibility:** semantics label / hint / selected / disabled giống RN; vùng chạm ≥ 44.

**Định nghĩa "xong" của một màn:** ảnh Flutter và RN trùng bố cục, màu, chữ ở cả 393 và 360/320; các trạng thái loading / empty / error giống nhau; hành vi cuộn, ẩn hiện và nhấn giống nhau; golden và widget test đã thêm; `docs/UI.md` mục 6.2 đổi trạng thái sang **Đủ**.

## 15. Thứ tự thực hiện và cập nhật tài liệu

1. Phase 1 (component chung) → 2. Home → 3. Khoá học + sheet + giỏ → 4. Lịch học → 5. Tài khoản → 6. Lớp của tôi → 7. Chi tiết lớp / buổi → 8. Thanh toán → 9. (tuỳ chọn) Auth.

Mỗi phase là một commit riêng, message dạng `s<n>: parity <màn> với RN`. Cuối mỗi phase cập nhật `MindyFlutter/docs/UI.md`: bảng mục 6.2, mục 9 (điểm lệch còn lại) và xoá các `TODO(UI)` đã xử lý.
