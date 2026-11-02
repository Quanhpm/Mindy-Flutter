#!/usr/bin/env bash
# Cài package, phân tích code, chạy test. Kết quả ghi vào check.log để Claude đọc.
#   bash tool/check.sh
cd "$(dirname "$0")/.."
exec > >(tee check.log) 2>&1
echo "==> flutter pub get";  flutter pub get
echo "==> flutter analyze";  flutter analyze
echo "==> flutter test";     flutter test
echo "==> xong"
