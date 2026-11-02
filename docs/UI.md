# UI — quản lý toàn bộ giao diện MindyFlutter

Cập nhật: **02/11/2026**. File này là nguồn chính về giao diện: hệ thiết kế, token, component, danh sách màn và trạng thái, các điểm lệch so với thiết kế. Sửa UI xong thì cập nhật bảng ở mục 6 và mục 9.

Liên quan: `docs/REMAINING_WORK_PLAN.md` (việc còn lại theo phase), `docs/codeRule.md` (quy tắc code), `docs/design/mentor/*.png` (ảnh thiết kế Mentor).

---

## 1. Hai hệ thiết kế trong một app

| | **Học viên** (Student) | **Staff** (Login chung, Mentor, sau này Quản lý) |
| --- | --- | --- |
| Nguồn thiết kế | Code RN `MindyMobile/src` + `MindyMobile/assets/Student Home Page Design/` (`Student Home.dc.html`, `Auth.dc.html`) + ảnh owner trong `MindyMobile/docs/IMPLEMENT/PHASE_0x/references/` | `MINDY-BE/Mentor Mobile UI.html`, `MINDY-BE/Login (1).html`, `MINDY-BE/Thiết kế Home UI.html` (Quản lý) |
| Font | Nunito 400/600/700/800 | Be Vietnam Pro 400/500/600/700 |
| Icon | `MindyIcon` (SVG nét, 32 icon copy từ RN) | `Sym` (Material Symbols Rounded, trục FILL 0/1) |
| Màu chủ đạo | forest `#1D5B57`, mint `#338A85`, action `#FF9973` | teal `#123236 → #1F4F55 → #2B6A71`, nền kem `#F6F5F2`, nhấn `#C2410C` |
| Điều hướng | Tab bar đáy 5 ô, nút Home tròn nổi giữa | Không tab bar: Home + lưới tiện ích mở trang con (push) |
| Thư mục code | `lib/core/ui/` + `lib/core/theme/` | `lib/core/ui/staff/` |

**Quy tắc chọn hệ:**

- Màn thuộc khu `/home…`, `/my-classes`, `/classes/…`, `/payment/…`, Đăng ký, Welcome dùng hệ **Học viên**.
- Màn Đăng nhập (dùng chung mọi role) và mọi màn `/mentor…` dùng hệ **Staff**.
- **Không trộn** component của hai hệ trong cùng một màn. Ngoại lệ duy nhất: `Pressable`, `Skeleton`, `ScreenState`, `AsyncView` dùng chung được.
- App chỉ có **light theme** (máy bật dark mode vẫn hiện sáng).

---

## 2. Token

### 2.1. Màu Học viên — `AppColors` (`lib/core/theme/app_colors.dart`)

| Nhóm | Token |
| --- | --- |
| Chính | `forest #1D5B57`, `mint #338A85`, `canvas #FFFFFF`, `coral #FF7F50`, `headsup #FF5400` (lỗi), `sunshine #FFDDAE` |
| Phụ | `soft #F1F7F6`, `line #D8E9E8`, `muted #346B68`, `peach #FFEEE8`, `action #FF9973`, `banner #CAE1DF`, `catalogInk #262626` |
| Trạng thái | `statusGreen #15803D`, `statusYellow #A16207`, `statusRed #B91C1C` |
| Bìa khoá học | `covers` = 4 cặp (`coverA/ASoft` … `coverD/DSoft`), chọn theo `index % 4` |
| Vùng màu | `RegionColors.home / cart / courseDetail / catalog`: đổi màu chữ forest/muted/mint trong vùng (port từ `regions.ts`). Đọc bằng `RegionColors.of(context)` |

### 2.2. Màu Staff — `StaffColors` (`lib/core/ui/staff/staff_theme.dart`)

| Nhóm | Token |
| --- | --- |
| Teal | `teal900 #123236`, `teal700 #1F4F55` (nút chính), `teal600 #1F5F66` (link/icon), `teal500 #2B6A71`, `tealSoft #E4EFED`, `tealTint #EEF4F3`, `tealLine #D6E3E1`, `onTealMuted #C7DCD9` (chữ phụ trên nền teal) |
| Nền/chữ | `bg #F6F5F2`, `ink #1C1B19`, `muted #6B6862`, `subtle #8A867E`, `faint #B5B1A9`, `line #E3E0DA`, `lineError #E8C9BF`, `surface #FFFFFF` |
| Nhấn | `accent #C2410C` (badge số, chấm chưa đọc, nhãn MỚI), `star #C98A12` |
| Gradient | `headerGradient` = teal900 → teal700 → teal500 (dừng 0 / .55 / 1) |
| Chip trạng thái | `StatusTone.green / teal / amber / red / blue / gray` (mỗi tone có `bg` + `fg`) |

### 2.3. Chữ

| Học viên — `AppText` | Staff — `StaffText` |
| --- | --- |
| `sectionTitle` 30/800 · `title` 20/800 · `label` 14/700 · `body` 16 · `caption` 14 · `eyebrow` 12/800 giãn chữ · `link` 14/800 mint | `pageTitle` 20/600 · `title`/`section` 17/600 · `body` 15 · `bodyStrong` 15/600 · `label` 13/500 · `caption` 13 · `small` 12 · `eyebrow` 12/600 · `link` 13/600 teal600 · `bigTime` 28/600 · `button` 15/600 |

### 2.4. Hình khối và chuyển động

| | Học viên | Staff |
| --- | --- | --- |
| Bo góc | Nút/ô nhập 999; thẻ 18–24; sheet 28 | Nút/ô nhập/chip 999; thẻ kính 20; header bo đáy 28; sheet 28; panel trang con bo trên 28 |
| Bóng | Nút primary bóng forest 25% | Thẻ kính `0 8 24` teal 10%; header `0 10 24` teal900 35% |
| Chuyển động | `Motion.fast 150 / base 250 / slow 350 ms`, `easeOutCubic`, nhấn thu nhỏ `0.97`, stagger 40 ms tối đa 8 mục | Dùng chung `Motion` |
| Giảm chuyển động | `Motion.reduced(context)` = tắt scale/animation | như trên |

---

## 3. Component

### 3.1. Dùng chung

| Component | File | Dùng khi |
| --- | --- | --- |
| `Pressable` | `core/ui/pressable.dart` | Mọi vùng bấm tự vẽ; thu nhỏ 0.97, có `semanticLabel`, `selected` |
| `Skeleton` | `core/ui/states.dart` | Đang tải; tự tắt nhấp nháy khi giảm chuyển động |
| `ScreenState` | `core/ui/states.dart` | Khối lỗi/rỗng có tiêu đề, mô tả, mã hỗ trợ, nút Thử lại |
| `AsyncView` | `core/ui/states.dart` | Hiển thị `AsyncValue` 3 trạng thái loading / error / data |

### 3.2. Học viên (`core/ui/`)

| Component | Ghi chú |
| --- | --- |
| `MindyButton` | Biến thể `primary` (gradient mint→forest), `outline`, `solid`, `action`, `ghost`; cao tối thiểu 54; `loading` |
| `TextLink` | Link chữ mint đậm, vùng bấm cao 44 |
| `MindyInput` | Nhãn trên, viền tròn, icon trái, nút hiện/ẩn mật khẩu, dòng lỗi màu headsup |
| `MindyIcon` + `MindyIconName` | 32 icon nét, mặc định màu `muted` |
| `AppTabBar` | 5 ô: Khoá học, Lịch học, Home (tròn giữa), Thông báo (luôn tắt), Tài khoản; tự giãn khi màn ≤ 360 px hoặc chữ ≥ ×1,3 |
| `CoverImage` | Ảnh mạng có fallback nền banner + icon |
| `showAppSheet` | Bottom sheet kéo được, né bàn phím |
| `CourseTile` | Thẻ khoá học (`features/courses/course_tile.dart`) |
| `FormFeedback`, `AuthShell` | Khung và hộp báo lỗi của Đăng ký/Welcome (`features/auth/auth_shell.dart`) |

### 3.3. Staff (`core/ui/staff/`)

| Component | Ghi chú |
| --- | --- |
| `StaffBackground` | Nền kem có 2 vệt sáng teal/cát; bọc mọi màn staff |
| `StaffHeader` | Header gradient bo đáy 28, tự cộng safe area trên |
| `StaffPage` | Khung trang con: header (back, tiêu đề, phụ đề, `headerExtra`) + panel kem phủ lên |
| `GlassCard` | Thẻ kính trắng mờ; `onTap` tuỳ chọn |
| `InitialsAvatar` | Chữ cái đầu + cuối của tên ("Trần Thị Linh" → "TL") |
| `StatusChip` + `StatusTone` | Chip trạng thái nhỏ, có thể kèm icon |
| `FilterChipsBar<T>` | Hàng chip lọc cuộn ngang, chip chọn nền teal700 |
| `UtilityTile` | Ô tiện ích tròn 56: `highlighted`, badge `isNew` (MỚI), `count`, `mark` (chế độ Sửa) |
| `StaffButton` | Nút teal đặc hoặc viền (`outlined`), cao 52, `loading` |
| `StaffInput` | Ô nhập staff: nhãn, icon, mật khẩu, viền lỗi |
| `showStaffSheet` / `openStaffSheet` | Bottom sheet có tiêu đề + phụ đề |
| `showStaffToast` | Toast nổi đáy, tự ẩn 2,2 s |
| `DayStrip` | Dải bảy ngày, vùng bấm ≥44px, cuộn ngang khi chữ lớn |
| `TeachingCard` | Thẻ giờ/buổi dùng chung lịch và dạy thay |
| `StaffStats` | Hàng số liệu co giãn, không trộn hệ Học viên |
| `StaffDataState` | Rỗng/lỗi + mã hỗ trợ + thử lại đúng hệ Staff |
| `Sym` | Icon Material Symbols: `Icon(Sym.calendarMonth, fill: 1)` |

Đã có DayStrip/thẻ buổi (MF2), hàng điểm danh và số liệu (MF3). Còn hàng tài liệu và thanh tiến độ upload ở MF5.

### 3.4. Bảng tone chip trạng thái (Staff)

| Miền | Trạng thái → tone |
| --- | --- |
| Lớp | Đang dạy → `green` · Sắp mở → `teal` · Đã kết thúc → `gray` |
| Buổi học | Đang diễn ra → `green` · Sắp tới / Hôm nay → `teal` · Đã kết thúc / Đã dạy → `gray` · Đã huỷ → `red` · Dạy thay → `amber` (icon `swapHoriz`) |
| Điểm danh | Có mặt → `green` · Vắng → `red` · Chưa điểm danh → `gray` |
| Tài liệu | Đã duyệt → `green` · Chờ duyệt → `amber` · Nháp → `gray` · Bị từ chối → `red` |
| Học viên | Cần chú ý → `amber` |
| Nhãn | MỚI → nền `accent`, chữ trắng |

---

## 4. Quy tắc trạng thái màn hình

- Mọi vùng dữ liệu có đủ **loading** (Skeleton đúng kích thước nội dung), **rỗng** (câu giải thích + hành động tiếp theo nếu có), **lỗi** (câu theo `errorKey`, mã hỗ trợ `requestId`, nút Thử lại), **disabled** (mờ 50%, có nhãn trợ năng giải thích).
- Lỗi một vùng **không** làm hỏng cả màn (Home có vùng khoá học và vùng buổi học riêng).
- Lỗi form hiện **ngay dưới ô** hoặc hộp lỗi trên nút gửi; lỗi thao tác nhanh dùng toast (staff) hoặc dòng chữ đỏ (học viên).
- Thao tác đang gửi: nút hiện `loading`, khoá bấm lặp.
- Không bao giờ hiện thành công khi server chưa xác nhận (thanh toán, đăng xuất, điểm danh).

---

## 5. Kích thước, trợ năng, an toàn hiển thị

- Mốc kiểm tra bắt buộc: **320×640 logical px** với **chữ ×1,3**, và một máy cỡ thường (≈ 390×844). Không cắt chữ ở nút chính.
- Vùng bấm tối thiểu **44×44**.
- Mọi icon-only button có `tooltip` hoặc `semanticLabel`; ảnh trang trí bọc `ExcludeSemantics`; vùng báo lỗi dùng `Semantics(liveRegion: true)`.
- Tôn trọng safe area (tai thỏ, thanh điều hướng), bàn phím (sheet có `viewInsets`, form cuộn được).
- Thời gian hiển thị theo `timeZone` của response; tiền dạng `1.500.000 VND`; ngày `dd/MM` hoặc `dd/MM/yyyy`.

---

## 6. Danh sách màn hình và trạng thái

Trạng thái: **Khung** (chạy được, UI chưa port chi tiết) · **Đủ** (khớp thiết kế, chờ owner duyệt) · **Duyệt** (owner đã duyệt UI) · **Chưa làm**.

### 6.1. Chung

| Màn | Route | File | Nguồn thiết kế | Trạng thái |
| --- | --- | --- | --- | --- |
| Splash (kiểm tra phiên) | `/splash` | `features/auth/splash_screen.dart` | RN `session-loading` | Đủ |
| Đăng nhập (mọi role) | `/login` | `features/auth/login_screen.dart` | `Login (1).html` | Đủ (MF1) |
| Đăng ký | `/register` | `features/auth/register_screen.dart` | RN `RegisterScreen.tsx`, `Auth.dc.html` | Khung — chờ owner chọn kiểu (S5) |
| Welcome / tài khoản nhân sự chưa hỗ trợ | `/welcome` | `features/auth/welcome_screen.dart` | RN `WelcomeScreen.tsx`, `StaffSession` | Khung |

### 6.2. Học viên

| Màn | Route | File | Nguồn RN | Trạng thái | Phase |
| --- | --- | --- | --- | --- | --- |
| Trang chủ | `/home` | `features/home/home_screen.dart` | `home/StudentHome.tsx`, `HomeCarousel`, `HomeCompiler` | Khung (thiếu carousel, compiler, về chúng tôi, footer) | S1 |
| Khoá học | `/home/courses` | `features/courses/courses_screen.dart` | `courses/CoursesScreen.tsx`, `Recommendations.tsx` | Khung | S2 |
| Sheet khoá học / chọn lớp | sheet | `features/courses/course_sheet.dart` | `CourseSheet.tsx` | Khung | S2 |
| Sheet bộ lọc | sheet | trong `courses_screen.dart` | `FilterSheet.tsx` | Khung | S2 |
| Sheet giỏ hàng | sheet | `features/cart/cart_sheet.dart` | `CartSheet.tsx` | Khung | S2 |
| Thanh toán QR | `/payment/:orderId` | `features/payment/payment_screen.dart` | `PaymentScreen.tsx` | Khung (thiếu sheet rời trang, thông tin chuyển khoản) | S3 |
| Ticket kết quả | trong payment | `features/payment/payment_result_ticket.dart` | `PaymentResultTicket.tsx` + ảnh owner Phase 5 | Khung (chưa có mép xé) | S3 |
| Lịch học | `/home/schedule` | `features/schedule/schedule_screen.dart` | `schedule/ScheduleScreen.tsx` | Khung (chưa timeline) | S4 |
| Tài khoản | `/home/account` | `features/account/account_screen.dart` | `account/AccountScreen.tsx` | Khung | S4 |
| Lớp của tôi | `/my-classes` | `features/my_classes/my_classes_screen.dart` | `MyClassesScreen.tsx` | Khung (chưa folder thu gọn, ảnh khoá) | S4 |
| Chi tiết lớp / buổi | `/classes/:classId` | `features/my_classes/class_detail_screen.dart` | `ClassDetailScreen.tsx`, `SessionDetailScreen.tsx` | Khung (chưa `sessionDisplayStatus`, người tham gia) | S4 |

### 6.3. Mentor

Ảnh tham chiếu trong `docs/design/mentor/`: `mentor_home.png`, `mentor_pages_1.png` (Lịch dạy, Lớp phụ trách, Chi tiết lớp, Báo cáo), `mentor_pages_2.png` (Học viên, Tài liệu, Tải file bước 1, ~~Mở chương~~), `mentor_pages_3.png` (Tất cả tiện ích, Thông báo, Tải file bước 2), `mentor_pages_4.png` (Buổi dạy thay, Đồng bộ sĩ số, Lọc học viên).

| # | Màn | Route | File | Trạng thái | Phase |
| --- | --- | --- | --- | --- | --- |
| H | Home Mentor | `/mentor` | `features/mentor/mentor_home_screen.dart` | Đủ; API MF2 đã nối, tự review theo ủy quyền | MF1 → MF2 |
| — | Sheet Tài khoản / Đăng xuất | sheet | trong `mentor_home_screen.dart` | Đủ (bổ sung, thiết kế không có) | MF1 |
| P10 | Tất cả tiện ích | `/mentor/utilities` | `features/mentor/mentor_pages.dart` | Đủ; đã sửa Material, test 320×640 chữ ×1,3 pass; chờ duyệt | MF1/P0 |
| — | Trang tạm cho tiện ích chưa làm | `/mentor/page/:key` | `mentor_pages.dart` | Tạm, gỡ dần | MF2–MF5 |
| N | Thông báo | panel | `features/notifications/` | Đủ; cursor + đọc + timer foreground | MF2 |
| P1 | Lịch dạy | `/mentor/page/schedule` | `features/mentor/schedule/` | Đủ; API phân trang/timezone | MF2 |
| S2 | Sheet Phòng học | sheet | `features/mentor/session/room_sheet.dart` | Đủ; context + sao chép + mở link | MF2 |
| P9 | Buổi dạy thay | `/mentor/page/substitute` | `features/mentor/substitute/` | Đủ; lịch 30 ngày trước/60 ngày tới | MF2 |
| S1 | Sheet Điểm danh | sheet | `features/mentor/attendance/` | Đủ; UI + API + controller, tự review; chờ UAT live | MF3 |
| S3 | Sheet Đồng bộ sĩ số | sheet | `features/mentor/attendance/` | Đủ; UI + API + controller, tự review; chờ UAT live | MF3 |
| S4 | Sheet Chốt buổi | sheet | `features/mentor/attendance/` | Đủ; UI + API + controller, tự review; chờ UAT live | MF3 |
| P2 | Lớp phụ trách | `/mentor/page/classes` | `features/mentor/classes/` | Chưa làm | MF4 |
| P3 | Chi tiết lớp | (route mới) | `features/mentor/classes/` | Chưa làm | MF4 |
| P4 | Báo cáo điểm danh | `/mentor/page/attendance` | `features/mentor/reports/` | Chưa làm | MF4 |
| P5 | Học viên + sheet lọc | `/mentor/page/students` | `features/mentor/students/` | Chưa làm | MF4 |
| P6 | Tài liệu | `/mentor/page/materials` | `features/mentor/materials/` | Chưa làm | MF5 |
| P7 | Tải file lên (2 bước) | `/mentor/page/upload` | `features/mentor/materials/` | Chưa làm | MF5 |
| ~~P8~~ | ~~Mở chương~~ | — | — | **Bỏ** (owner 02/11, backend đã gỡ) | — |

### 6.4. Quản lý (chưa trong phạm vi)

Thiết kế `Thiết kế Home UI.html`: Home Quản lý (đơn nghỉ, duyệt tài liệu, xác nhận tiền mặt, phân công dạy thay, buổi chưa chốt, thông báo). Dùng lại hệ Staff khi làm.

---

## 7. Asset

| Loại | File | Ghi chú |
| --- | --- | --- |
| Font Học viên | `assets/fonts/Nunito-{Regular,SemiBold,Bold,ExtraBold}.ttf` | Family `Nunito` (font mặc định của theme) |
| Font Staff | `assets/fonts/BeVietnamPro-{Regular,Medium,SemiBold,Bold}.ttf` | Family `BeVietnamPro`; gộp 3 subset từ file thiết kế; có thể thay bằng TTF chính thức |
| Icon Staff | `assets/fonts/MaterialSymbolsRounded.ttf` | Family `MaterialSymbolsRounded`; bản release tự cắt bớt icon không dùng (tree-shake) |
| Giấy phép font | `assets/fonts/FONTS-LICENSES.md` | OFL 1.1 / Apache 2.0 |
| Mascot Học viên | `assets/illustrations/mindy-mascot-{book,laptop,map}.png` | Từ RN |
| Ếch Staff | `assets/illustrations/mindy-frog-teacher.png` (Login), `mindy-frog-peek.png` (Home Mentor) | Trích từ file thiết kế |
| Logo | `assets/images/logo.png` | Từ RN |

**Thêm icon Staff:** tra codepoint ở https://fonts.google.com/icons (mục *Code point*), thêm `static const tenIcon = IconData(0x…, fontFamily: _f);` vào `lib/core/ui/staff/sym.dart`. **Thêm icon Học viên:** thêm path SVG 24×24 vào `_paths` trong `core/ui/icon.dart`.

---

## 8. Quy trình làm một màn

Cập nhật owner 02/11/2026: đã ủy quyền tự quyết các phase tiếp theo, không hỏi lại.
Agent tự đối chiếu ảnh, kiểm tra responsive rồi tiếp tục API; trạng thái tự review
được ghi riêng, không giả mạo owner đã xem từng màn.

1. Mở ảnh/HTML thiết kế; ghi vào bảng mục 6 nguồn thiết kế và phase.
2. Dựng UI bằng component có sẵn; thiếu component thì thêm vào `core/ui/` hoặc `core/ui/staff/` (không tự vẽ lại trong màn).
3. Dữ liệu mẫu (fixture) chỉ bật ở bản debug.
4. Đối chiếu ở 320×640 chữ ×1,3 và máy thường; chụp ảnh so với thiết kế.
5. Cập nhật trạng thái mục 6; ghi sai khác vào mục 9.
6. Owner duyệt UI → đổi trạng thái thành **Duyệt** → mới gắn API.

---

## 9. Nhật ký sai khác so với thiết kế

| Ngày | Màn | Sai khác | Lý do |
| --- | --- | --- | --- |
| 02/11/2026 | Đăng nhập | Phụ đề "Đăng nhập bằng tài khoản Mindy của bạn" (thiết kế: "Dùng tài khoản trung tâm đã cấp cho bạn") | Login dùng chung, học viên tự đăng ký |
| 02/11/2026 | Đăng nhập | Giữ link "Chưa có tài khoản? Đăng ký" (thiết kế: "Liên hệ trung tâm") | Quyết định owner #2 |
| 02/11/2026 | Đăng nhập | Ẩn "Quên mật khẩu?" và "Tiếp tục với Google" | Quyết định owner #4, backend chưa có luồng mobile |
| 02/11/2026 | Mentor | Bỏ tiện ích + trang Mở chương và thông báo "chương sẽ mở" | Quyết định owner #3, backend đã gỡ API |
| 02/11/2026 | Điểm danh | 3 trạng thái (thêm "Chưa điểm danh") + bước Bắt đầu buổi (thiết kế: mặc định vắng) | Quyết định owner #5, theo backend |
| 02/11/2026 | Home Mentor | Thêm sheet Tài khoản/Đăng xuất khi chạm avatar | Thiết kế không có chỗ đăng xuất |
| 02/11/2026 | Home Mentor | Thẻ buổi dạy hiện mô tả tạm, chuông báo "đang phát triển" | MF1 chưa gắn lịch/thông báo |
| 02/11/2026 | Học viên — Lọc | Bỏ lọc "Bảo lưu" ở màn Học viên (Mentor) | Backend không có trạng thái này |
| dự kiến MF2 | Lịch dạy | Thêm nút tuần trước/sau (thiết kế chỉ có tuần hiện tại) | Cần xem lịch tuần khác |
| dự kiến MF4 | Học viên | Chạm học viên mở sheet chi tiết (thiết kế chỉ hiện toast) | Có API lịch sử điểm danh/tiến độ |
| 02/11/2026 | Điểm danh | Buổi COMPLETED vẫn có thể sửa PRESENT/ABSENT trong hạn theo canEditAttendance | Contract backend thực tế; chốt không khoá vĩnh viễn |
| 02/11/2026 | Lớp/tiến độ | Không dùng storedUnitCount làm số unit hoàn thành hay tự tính % học tập | Backend trả completionPolicy=UNDEFINED |

Review MF2: xem `docs/MF2_UI_REVIEW.md` và `test/goldens/mf2_*.png`. Đã kiểm tra UI tự động; UAT backend thật chưa chạy do thiếu tài khoản dev.

Review MF3: `docs/MF3_REVIEW.md`, golden `test/goldens/mf3_attendance_320_vi.png`. Sync không đoán danh sách học viên mới; số thêm lấy từ response.
