#!/usr/bin/env bash
# One-shot iOS dependency setup for Flutter (Runner + CocoaPods).
# Run from repo:  bash app/ios/bootstrap_ios.sh
# Requires: Flutter SDK + CocoaPods in PATH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found in PATH. Install Flutter and add it to PATH." >&2
  exit 1
fi

if ! command -v pod >/dev/null 2>&1; then
  echo "error: pod (CocoaPods) not found. Install: sudo gem install cocoapods" >&2
  exit 1
fi

cd "${APP_DIR}"

# Avoid stale FLUTTER_ROOT from another machine (breaks podhelper require).
rm -f ios/Flutter/Generated.xcconfig

echo "==> flutter pub get"
flutter pub get

cd ios

echo "==> pod deintegrate (ignore errors if first run)"
pod deintegrate 2>/dev/null || true

echo "==> pod install"
pod install

echo ""
echo "Done. Open: ${SCRIPT_DIR}/Runner.xcworkspace in Xcode, select a device/simulator, then Product > Run."
