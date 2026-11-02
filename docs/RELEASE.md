# Chuẩn bị phát hành Mindy

Bản code 02/11/2026. Android `vn.mindy.mindy_flutter`, iOS
`vn.mindy.mindyFlutter`: giữ ID riêng để cài song song bản RN. Tên hiển thị **Mindy**.
Icon và splash dùng mascot laptop từ bộ thiết kế Mindy đã bundle, thay icon Flutter
và logo S của boilerplate. Tái tạo bằng `tool/generate_brand_assets.py` (Pillow chỉ
là công cụ tạo asset, không thêm dependency runtime).

## Kiểm tra và APK nội bộ

`.github/workflows/flutter.yml` chạy analyze, test và APK debug với `env/dev.json`.
Artifact giữ 7 ngày, là bản development dùng debug key, không phải bản store.
Chạy tương đương:

```sh
bash tool/check.sh
flutter build apk --debug --dart-define-from-file=env/dev.json
flutter build ios --simulator --debug --dart-define-from-file=env/dev.json
```

## Cấu hình production

Copy `env/prod.json` thành `env/prod.local.json` (git ignore), điền **URL production
thật** và **Origin HTTPS có trong CORS_ORIGINS của backend**. Không suy từ URL dev.
Không cần đưa token/password vào dart-define. `DEBUG_MODE` không thể bật ở
production, dữ liệu ngân hàng thử nghiệm cũng không xuất hiện. App kiểm tra cấu
hình trước bootstrap; release wrapper kiểm tra trước build, không in giá trị.

```sh
dart tool/validate_release.dart env/prod.local.json
bash tool/build_release.sh env/prod.local.json appbundle
```

Các define `DEV_BANK_NAME`, `DEV_BANK_ACCOUNT`, `DEV_BANK_OWNER` chỉ dùng ở môi
trường development, phải đủ cả ba mới hiện khối chuyển khoản thử nghiệm. Không
điền số tài khoản giả mặc định. Đồng hồ thanh toán chỉ hiển thị; trạng thái đơn
luôn theo backend/PAYOS.

## Android signing

Copy `android/key.properties.example` thành `android/key.properties`, điền
keystore/alias/password thật. `storeFile` tính từ thư mục `android/`. File thật và
`*.jks` bị git ignore. Release **không dùng debug signing**; thiếu key sẽ dừng với
hướng dẫn. Kiểm tra unsigned nội bộ được phép rõ ràng bằng
`ORG_GRADLE_PROJECT_allowUnsignedRelease=true flutter build appbundle ...`;
artifact unsigned không cài được hay đăng store được trước khi ký.

Không tạo keystore mới thay cho key phát hành đã có. CI hiện chỉ tạo APK debug;
release signed chạy trên máy có key hoặc pipeline riêng với secret của owner.

## iOS signing

Mở `ios/Runner.xcworkspace`, chọn Runner → Signing & Capabilities, dùng team và
provisioning được cấp cho bundle ID trên. Không tự gán team ID hoặc certificate.
Sau khi cấu hình thật:

```sh
bash tool/build_release.sh env/prod.local.json ipa
```

Bản simulator không cần signing. TestFlight/App Store cần Apple account,
certificate, profile và quyền upload thật; code chuẩn bị không thay các bước này.

## Gate còn lại trước phát hành thật

- URL/Origin production và backend CORS thật; không commit giá trị đoán.
- Keystore Android, Apple team/provisioning và distribution.
- UAT server dev/thiết bị Android, hai thiết bị xung đột điểm danh/ghi chú,
  TalkBack/VoiceOver, picker nhiều loại file và app chạy nền.
- Chạy workflow trên remote sau push; có workflow không có nghĩa CI đã chạy.

## Cấu hình Android đã kiểm tra

AGP 9.1.0/Flutter 3.47.4: bật `android.builtInKotlin=true`, giữ old DSL cho
plugin Groovy. `file_picker` 11.0.3 không biên dịch Kotlin khi chỉ nhìn AGP 9
mà built-in bị tắt; đã tái hiện lỗi plugin registrant và build APK pass sau sửa.
Không nâng major picker vì 12/13 thay đổi API đọc stream đã dùng ở MF5.
Tham chiếu [Flutter Kotlin migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
và [issue file_picker #2200](https://github.com/vicajilau/flutter_file_picker/issues/2200).
Dart/Flutter constraint trong pubspec giữ nguyên; **build Android theo bộ công cụ
CI đã pin**. Flutter vẫn cảnh báo legacy KGP của picker; đây là việc nâng package
sau, không phải lỗi build hiện tại.
