#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is required. Install Flutter 3.47 or newer and put it on PATH." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

flutter create \
  --platforms=android,ios \
  --org com.salahfocus \
  --project-name salah_focus \
  "$TMP/salah_focus"

rm -rf android ios
cp -R "$TMP/salah_focus/android" ./android
cp -R "$TMP/salah_focus/ios" ./ios

python3 tool/apply_platform_setup.py
flutter pub get
flutter analyze
flutter test

echo "SalahFocus is ready. Run: flutter run"
