# S1 — Trang chủ Học viên (02/11/2026)

Tự review theo ủy quyền owner. Nguồn RN: `home/StudentHome.tsx`,
`components/HomeCarousel.tsx`, `HomeCompiler.tsx`, `HomeButton.tsx`,
`services/home.service.ts`, `shared/hooks/useCarouselAutoplay.ts`.

## Đã triển khai

- Home có carousel giới thiệu, Compiler minh họa, carousel ghi chú Về chúng tôi,
  footer và liên kết Khoá học/Lịch học/Lớp của tôi đúng route/origin.
- Carousel tự chuyển 1→2→3→1 mỗi 3 giây; dừng khi app không resumed, route Home
  bị che hoặc đang vuốt. Giữ lựa chọn dừng thủ công khi cuộn khỏi rồi trở lại.
  Chỉ slide hiện tại có semantics; dots có nhãn/selected và vùng bấm 44.
- Chiều cao tự nhiên theo nội dung dài nhất, không cố định chiều cao cắt chữ lớn.
  About dùng giấy gấp/băng dính; Compiler xếp dọc ở màn nhỏ/chữ lớn, terminal nổi
  ở màn thường. Terminal có caption nói rõ không chạy mã thật.
- Roboto Mono bundle từ Google Fonts, có OFL và ghi nguồn trong
  `assets/fonts/FONTS-LICENSES.md`; không tải font khi chạy. Dấu check dùng SVG
  có sẵn, tránh phụ thuộc glyph của font hệ điều hành.
- Lớp khai giảng sớm nhất đọc **đủ các trang**, kiểm tra metadata/ID/courseId,
  không suy từ 100 lớp đầu. Lỗi metadata lớp giữ thẻ khoá theo RN. Home đã đọc
  null/error thì CourseTile không gọi lại metadata lần hai.
- Home refresh khi quay lại từ màn khác hoặc foreground; không gửi lượt refresh
  khi route bị che, không tải lặp lần đầu. Có test hồi quy theo focus RN.
- Request khoá/lớp Home có cancel khi rời provider; response khoá kiểm tra trang,
  pageSize và ID trùng trước khi đọc metadata.

## Tự quyết chi tiết UI

- RN chưa cấu hình ba ảnh intro (`HOME_INTRO_IMAGES` đều undefined). Giữ mascot
  đã bundle, không dựng khung ảnh trắng lớn hoặc dùng ảnh học viên tự suy diễn.
- Nút intro/Compiler giữ disabled như `ProductionStudentHome` RN (không có
  onIntro/onCompiler). Không mở rộng sang sản phẩm compiler thật ngoài plan.
- Thêm Dừng/Tiếp tục tự chuyển. Giảm chuyển động hoặc accessibleNavigation thì
  tắt autoplay, vẫn chọn dot/vuốt thủ công; tránh tự đổi nội dung khi đang đọc.
- Không hiển thị số hỗ trợ mẫu `1900 0000` trong footer. Giữ tagline, liên kết và
  copyright từ bản dịch. Dấu nối ý trong ghi chú vi dùng dấu chấm phẩy dễ đọc.
- Header/thẻ khoá hiện hữu được giữ trong S1; phần CourseTile/catalog/cart tiếp
  tục ở S2. Đây không phải tuyên bố toàn bộ UI Học viên đã hoàn thiện.

## Bằng chứng

- `test/home_data_test.dart`: 5 ca về trang sau/sai metadata/ID trùng/sai course,
  lỗi metadata không làm mất khoá. Ba lỗi API đã có test đỏ trước khi sửa.
- `test/auto_carousel_test.dart`: 6 ca vòng trang, dispose, lifecycle, route bị
  che, giảm chuyển động/semantics, đang vuốt và giữ lựa chọn pause qua scroll.
- `test/home_widget_test.dart`: 14 ca; 9 golden vi/en 320×640 chữ ×1,3 và Compiler
  390×844 chữ thường; cả ba slide intro/about đều đã được mở trong test.
- Golden `test/goldens/s1_*.png` đã mở xem; sửa font terminal và glyph từ kết quả
  review. Footer điều hướng được kiểm tra bằng route đích thực tế, gồm push lớp.
- Native preview iPhone 17/iOS 27 build **18,6 giây**; đã cuộn Home, chọn note thứ
  ba và dừng carousel. Ảnh `docs/design/student/review/s1_ios_intro_compiler.png`.
  Preview có banner, dữ liệu tổng hợp và adapter chặn mọi request ra ngoài.
- `tool/student_home_preview.dart` chỉ debug; fixture không import vào `lib/main`.

`bash tool/check.sh`: **214 test pass**, 1 live test mặc định skip, analyze sạch.
Main entrypoint iOS Simulator build thành công **12,0 giây**.

UAT Student trên server dev/thiết bị Android chưa chạy. Không đánh dấu Done toàn
bộ S1–S5 từ các ảnh preview; phần việc tiếp theo là S2 theo plan.
