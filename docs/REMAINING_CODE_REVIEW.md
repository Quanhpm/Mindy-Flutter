# Chốt code S2–S5, MF7 và chuẩn bị phát hành

02/11/2026. Thực hiện theo ủy quyền tự quyết và yêu cầu owner **code trước, test gom
sau**. Các mục code trong phạm vi plan đã nối; nghiệm thu server/thiết bị và ký
phát hành vẫn ghi riêng, không đổi thành Done khi thiếu bằng chứng.

## Học viên

- **S2:** Gợi ý dùng carousel có pause/lifecycle/reduced motion; trang số có dấu
  lược; grid tự đổi một cột khi màn hẹp/chữ lớn. Sheet có hero, mô tả mở/thu gọn,
  lịch tóm tắt đọc từ lớp và timezone server. Metadata khoá/lớp sớm nhất giới hạn
  6 tác vụ cùng lúc, đọc hết trang, cache lớp sớm nhất hết hạn sau 5 phút.
- **Giỏ:** ảnh khoá, cảnh báo giá mới, tổng/checkout cố định đáy; footer có scroll
  riêng khi sheet quá thấp. Checkout unknown giữ trong RAM qua đóng/mở, chặn POST
  mới tới khi đối soát; đọc hết các trang đơn pending, nhiều kết quả thì không
  đoán. Đổi actor reset pending, response cũ không ghi vào state phiên mới.
- **S3:** xác nhận rời trang, ngân hàng thử nghiệm chỉ hiện khi cấu hình đầy đủ
  ở development, sao chép từng field; ticket CustomClipper mép xé. Countdown và
  watcher dừng khi nền; đồng hồ không thay trạng thái thanh toán của backend.
- **S4:** folder lớp thu gọn + thumbnail; chi tiết lớp/buổi/Người tham gia; trạng
  thái trình bày theo endsAt; timeline, tháng, tuần và ngày theo timezone server.
  Backend chưa có endpoint danh sách bạn học cho Student nên sheet chỉ hiển thị
  mentor biết được và thông báo giới hạn, không dựng học viên giả.
- **S5:** giữ phong cách Học viên theo quyết định đã ghi trong plan. Form responsive,
  trim tên/email/điện thoại và bỏ phone rỗng; giữ nguyên mật khẩu.
- Modal Học viên đóng/reset khi epoch đổi; màn thanh toán và form MF7 tạo State
  mới theo actor. Nạp date symbols trước UI để tên tháng Việt/Anh dùng được.

## Mentor MF7

Tái dùng hệ Staff. Lối vào Nghỉ dạy/Dạy bù ở Tiện ích; Công cụ buổi dạy ở lịch,
dạy thay, danh sách buổi của lớp và sheet phòng.

- Danh sách theo trạng thái, chi tiết đọc hết trang item, lý do duyệt/từ chối,
  số xung đột học viên và ngày kết thúc lớp được gia hạn.
- Tạo đơn theo ngày/period, preview lịch và sourceVersions thật; từng buổi phải
  chọn targetDate/period và slot server cung cấp. Không tự nhập giờ trống hay
  suy quyền từ lịch máy. FULL_DAY gửi sessionMappings, đúng backend hiện tại.
- Rút đơn PENDING có lý do và expectedVersion. Create/withdraw và ghi chú giữ
  IdempotentCall sâu, cùng key/body qua mất mạng và đóng/mở màn, reset theo actor.
  409 yêu cầu đọc/xem lại snapshot trước ý định mới; không replay tự động.
- Ghi chú có content/nextSteps, version riêng; sửa IN_PROGRESS/COMPLETED trong
  editableUntil của server. Xung đột giữ bản nháp, hiển thị bản mới và bắt nhận
  phiên bản mới trước lưu. 403/404 về lịch, không tiếp tục dùng context cũ.
- Link buổi dùng override hoặc kế thừa link lớp. PATCH không có receipt: unknown
  chỉ đọc lại context, người dùng xem và xác nhận version mới trước PATCH mới.
  Cho phép no-op cùng version như backend; không coi đó là response hỏng.
- Form có bảo vệ back khi nháp/đang gửi, khoá thao tác lặp, lỗi có requestId,
  đủ Việt/Anh; controller được giữ trong RAM chỉ khi cần đối soát.

Nguồn contract: `Mindy-BE/src/modules/teaching-operations/` (DTO/controller/service),
ưu tiên hơn schema web cũ cho FULL_DAY. **Assignments và chat trực tiếp vẫn ngoài
phạm vi plan**, không coi thông báo CHAT_MESSAGE là đã làm màn chat.

## Kiểm tra đã chạy

- Analyze sạch; **248 test pass, 1 live test mặc định skip**. Thêm 34 test:
  idempotency/unknown/version/epoch, giới hạn concurrency, paging, enum i18n,
  MF7/S2/S3/S4 màn 320×640 chữ ×1,3 Việt/Anh và sheet giỏ thu xuống 256 px.
- 8 golden mới: leave/notes/payment-ticket/schedule Việt/Anh; đã mở xem. Cập nhật
  4 golden cũ có thay đổi thực tế: số tiện ích và công cụ buổi trong chi tiết lớp.
- Sửa fixture polling: nạp I18n ở setUpAll để I/O asset không kẹt trong fake clock.
  Đồng hồ/anchor của golden lịch cố định để không đổi ảnh theo giờ chạy test.
- APK debug build pass sau sửa Kotlin tích hợp của AGP 9; iOS main Simulator build
  pass (12,4 giây). Cấu hình Android hiện tại/CI dùng Flutter 3.47.4.
- Probe production: HTTPS hợp lệ pass; HTTP/URL rỗng bị từ chối; DEBUG_MODE=true
  và ngân hàng development vẫn không bật ở production. Dry-run release thiếu
  keystore bị chặn đúng thông báo, không tự dùng debug key.

`tool/operations_preview.dart` là fixture debug **chặn toàn bộ HTTP**, không cookie
lưu/không bootstrap. Bản preview không phải bằng chứng mutation server thật.
Đã nhập nháp ghi chú, mở cảnh báo và xác nhận rời về menu trên iPhone Simulator.
Ảnh: `design/mentor/review/mf7_ios_draft_guard.png` và `mf7_ios_leave_detail.png`.

## Giới hạn còn lại

MF7 chưa chạy end-to-end trên backend/thiết bị với hai actor thật. Các UAT nhiều
loại file, Android picker, accessibility, background và server dev trong
`MENTOR_UAT.md` vẫn còn. Backend local attendance/material smoke ở MF6 là bằng
chứng cũ đã chạy, không thay UAT MF7. CI mới được thêm, chưa push/chạy remote.
Production URL/Origin, keystore, Apple team/profile không có trong workspace;
`RELEASE.md` ghi cách điền/build. Không có bản signed store hay TestFlight.

## Thay đổi đồng thời trong workspace

Sau mốc 248 test pass/analyze sạch, xuất hiện lượt chỉnh UI Học viên theo
`STUDENT_UI_PARITY_PLAN.md` với `brand_bar.dart`, `learning_layout.dart` và UI kit.
Không sửa/restore hay commit thay đổi của luồng đó. Analyze toàn workspace ở
lượt build cuối báo 3 lint trong `learning_layout.dart` mới; APK debug và iOS main
vẫn build pass (17,0/19,9 giây). Kết quả test nêu trên thuộc mốc trước các thay đổi
đồng thời này, không phải nghiệm thu UI Học viên đang tiếp tục sửa.


## Kiểm tra tích hợp trước đưa lên main — 02/11

Đã tích hợp cả chuỗi commit UI Học viên vào cùng nhánh và chạy lại
`bash tool/check.sh`: **analyze sạch, 275 test pass, 1 live test mặc định skip**.
Các lint nêu ở mốc trước đã được xử lý trong chuỗi UI. Mốc này thay cho giới hạn
"chưa kiểm tra sau chỉnh UI"; không thay các gate UAT backend/thiết bị/signing.
Bản chạy mặc định là `lib/main.dart`; đã cài lại app chính trên iPhone Simulator
và xác minh Home Mentor sau lần review fixture MF7.
