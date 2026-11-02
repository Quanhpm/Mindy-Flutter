# Manager — kết quả triển khai 02/11/2026

Đã hoàn thiện phần code **MG0–MG6 và MGX1–MGX4** trên nhánh
`flutter/manager-core`, từ main `860f30b`, theo yêu cầu “thực hiện toàn bộ”.
MG7 đã qua kiểm tra tự động/build và review Simulator; UAT deploy/liên role và
signed distribution vẫn là gate riêng. Không tự push main ở lượt này.

## Chức năng đã nối

- MANAGER ACTIVE dùng Login/me/refresh/logout hiện có, khu vực/route riêng;
  Student và Mentor giữ khu vực tương ứng, ADMIN chưa có mobile workspace.
- Home có queue counts từ total server, links cùng filter,9 tiện ích, yêu thích
  theo actor (3 cố định, tối đa6), tài khoản/đăng xuất và refresh khi hiện/foreground.
- Đơn nghỉ: trạng thái/Mentor, chi tiết đủ trang, buổi gốc/bù/gia hạn/xung đột,
  stale source và hạn xử lý; duyệt/từ chối có lý do/version/receipt, FULL_DAY ack.
- Tài liệu: kho tổng/khóa/Unit/type/status, ARTICLE canonical HTML và file/ảnh,
  approve kèm publish, reject lý do, publish/unpublish, tạo/sửa/xóa theo canEdit và
  revision. Editor giữ HTML cũ, availability theo server zone và draft back guard.
- Upload: native picker, stream PUT không cookie, complete/status/READY, tiến độ,
  cancel/check/explicit retry, attachments/inline/primary, chỉ gắn file khi chọn dùng.
- CASH: lọc trạng thái/lớp/mã, chi tiết tiền/người thu/review, nhập đúng toàn bộ
  số tiền + checkbox; GET mới trước ghi và GET đối soát khi unknown. PAYOS chỉ đọc.
- Tra cứu Mentor/Student/lớp/Unit/lớp liên quan/lịch tuần Mentor.
- Phân công primary và substitute/xóa override từ candidates/version server,
  có xác nhận tác động và receipt. Không thêm tạo/mở/hủy lớp ADMIN.
- Buổi chưa hoàn tất, báo cáo chuyên cần và audit chỉ đọc; rate null giữ null.
- Xếp/hủy học bù học viên từ candidates/sĩ số, checkbox tương đương nội dung,
  conflict/target/placement versions và receipt. Không gọi API Student để lấy đích.

Các endpoint và giới hạn ở `API_CONTRACT_MANAGER.md`. Backend/web chỉ đọc đối chiếu,
không sửa source/quyền. Không thêm package. Text vi/en đầy đủ.

## Bảo vệ ghi và phiên

Receipt controller chung được tách từ Mentor MF7, giữ nguyên semantics cũ;
Manager leave/assignment/makeup dùng cùng key/body/action khi phản hồi chưa rõ.
409 phải đọc lại trước ý định mới. Material/CASH không có receipt contract, không
thêm header hoặc tự replay POST. ACK material rồi response/parser lỗi khóa ghi để
đối soát; CASH ACK rồi GET lỗi chỉ được GET tiếp. Create material unknown chọn
bản đã tạo thuộc actor/Unit, không POST mù.

Các provider đọc gắn epoch/cancel; read queue kiểm epoch trước HTTP. Route/sheet
reset State khi actor đổi; late response không cập nhật actor mới. Upload và signed
access không lưu URL/receipt vào preferences. Draft bảo vệ khi back, không mất HTML.

## Bằng chứng kiểm tra

| Kiểm tra | Kết quả |
| --- | --- |
| `bash tool/check.sh` sau các thay đổi cuối | analyze sạch; **341 test pass,1 live test skip** |
| Manager logic/API/controller | **21 test pass**, gồm login thật qua AuthApi fixture, paging/metadata, receipt lost ACK/409, nonreceipt reconciliation, queued reads/actor change, upload |
| Manager widget/router | **45 test pass**:19 màn ×vi/en,320×640 chữ1,3 và7 luồng thao tác |
| Golden |16 ảnh8 màn vi/en đã mở xem, không overflow; danh sách dài/lower actions có kiểm cuộn |
| Android main | `flutter build apk --debug -t lib/main.dart` pass,17,1s Gradle |
| iOS Manager preview | Simulator debug build pass,14,7s Xcode; Home/list/detail/confirm đã xem và duyệt fixture đọc lại APPROVED |
| iOS main | `flutter build ios --simulator --debug -t lib/main.dart --dart-define-from-file=env/dev.json` pass,9,2s Xcode |
| Whitespace | `git diff --check` sạch |

Tổng tăng66 test so với baseline275. Test cũ “Manager chưa có app → Welcome”
được cập nhật thành Manager workspace; Admin vẫn Welcome. Fixture HTTP adapter
chặn route lạ bằng501, không fallback ra server. Native thao tác duyệt chỉ ghi RAM
fixture, không xử lý đơn thật. Các cảnh báo file_picker/Kotlin và
flutter_secure_storage/SwiftPM là cảnh báo plugin hiện có; build vẫn pass.

Sau preview đã cài/chạy lại **lib/main.dart**; không để bản fixture thay app thật.
Màn cuối đã kiểm lại: Home Student theo phiên hiện có, không còn preview Manager.
Một vùng dữ liệu Home báo lỗi kết nối server; việc phục hồi main không được coi
là UAT backend. Không thay tài khoản hiện có để giả lập Manager trong main.

## Gate chưa chạy

Chi tiết tại `MANAGER_TEST_DATA.md`: chưa có account/dataset UAT Manager được cấp
cho lượt này; chưa chứng minh chuỗi Mentor→Manager→Student, hai actor trên server
thật hay upload Manager qua storage/worker deploy. Cũng chưa chạy VoiceOver/
TalkBack thiết bị, signed APK/AAB, TestFlight/Play. Không coi fixture hoặc build
debug là pass những gate này. Cần endpoint/quyền của bản deploy khớp source đã đọc.
