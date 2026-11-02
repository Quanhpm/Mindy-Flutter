#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
config="${1:?Usage: bash tool/build_release.sh env/prod.local.json [apk|appbundle|ipa]}"
artifact="${2:-appbundle}"
case "$artifact" in apk|appbundle|ipa) ;; *) echo 'Unsupported release artifact' >&2; exit 64;; esac
dart tool/validate_release.dart "$config"
flutter build "$artifact" --release --dart-define-from-file="$config"
