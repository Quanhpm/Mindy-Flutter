#!/usr/bin/env bash
# Chạy 1 lần trên máy Mac, trong thư mục MindyFlutter:
#   bash tool/setup.sh
# - Sinh thư mục android/ ios/ (không ghi đè lib/, pubspec.yaml, test/ đã có)
# - Cho phép gọi API http://localhost khi dev
# - Cài package, phân tích code, chạy test
set -euo pipefail
cd "$(dirname "$0")/.."
# Ghi toàn bộ output ra setup.log để Claude đọc và sửa lỗi
exec > >(tee setup.log) 2>&1

echo "==> flutter create (android, ios)"
flutter create --org vn.mindy --project-name mindy_flutter --platforms android,ios .

MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  echo "==> Android: thêm quyền INTERNET"
  perl -0pi -e 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
fi
if ! grep -q 'usesCleartextTraffic' "$MANIFEST"; then
  echo "==> Android: cho phép http (dev localhost/10.0.2.2)"
  perl -0pi -e 's#<application#<application android:usesCleartextTraffic="true"#' "$MANIFEST"
fi

PLIST=ios/Runner/Info.plist
if ! /usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity' "$PLIST" >/dev/null 2>&1; then
  echo "==> iOS: cho phép http tới localhost khi dev"
  /usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity dict' "$PLIST"
  /usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true' "$PLIST"
fi

echo "==> flutter pub get"
flutter pub get

echo "==> flutter analyze"
flutter analyze || echo "!! analyze còn lỗi - xem log ở trên"

echo "==> flutter test"
flutter test || echo "!! test chưa đạt - xem log ở trên"

echo
echo "Xong. Chạy app:"
echo "  flutter run --dart-define-from-file=env/dev.json"
