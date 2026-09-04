#!/usr/bin/env python3
"""Fast source-package checks that do not require a Flutter SDK.

This complements (not replaces) `flutter analyze` and `flutter test`. It is
useful in restricted CI/container environments to catch missing local imports,
localization drift, unsafe native permissions, and incomplete deliverables.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "pubspec.yaml",
    "analysis_options.yaml",
    "README.md",
    "PRIVACY.md",
    "ARCHITECTURE.md",
    "lib/main.dart",
    "lib/app/app.dart",
    "lib/features/prayer_times/application/prayer_coordinator.dart",
    "lib/features/prayer_times/domain/prayer_state_machine.dart",
    "lib/features/prayer_focus/domain/prayer_focus_service.dart",
    "lib/features/prayer_tracker/presentation/tracker_screen.dart",
    "lib/features/qibla/presentation/qibla_screen.dart",
    "lib/features/settings/presentation/settings_screen.dart",
    "native/android/MainActivity.kt",
    "native/ios/AppDelegate.swift",
    "native/ios/PrayerDeviceActivityMonitor/PrayerDeviceActivityMonitor.swift",
    "native/ios/PrayerDeviceActivityMonitor/Info.plist",
]


def fail(message: str) -> None:
    print(f"ERROR: {message}")
    raise SystemExit(1)


def check_required_files() -> None:
    missing = [item for item in REQUIRED if not (ROOT / item).is_file()]
    if missing:
        fail("missing required files: " + ", ".join(missing))


def check_pubspec() -> None:
    text = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    if not re.search(r"(?m)^name:\s*salah_focus\s*$", text):
        fail("pubspec project name must be salah_focus")
    for dep in (
        "flutter_riverpod",
        "go_router",
        "dio",
        "sqflite",
        "geolocator",
        "flutter_local_notifications",
        "timezone",
        "flutter_compass",
    ):
        if not re.search(rf"(?m)^\s{{2}}{re.escape(dep)}:\s*", text):
            fail(f"required dependency missing: {dep}")


def check_local_imports() -> None:
    pattern = re.compile(r"import\s+['\"]package:salah_focus/([^'\"]+)['\"]")
    missing: list[str] = []
    for file in (ROOT / "lib").rglob("*.dart"):
        text = file.read_text(encoding="utf-8")
        for match in pattern.finditer(text):
            target = ROOT / "lib" / match.group(1)
            if not target.is_file():
                missing.append(f"{file.relative_to(ROOT)} -> {target.relative_to(ROOT)}")
    if missing:
        fail("broken local imports:\n  " + "\n  ".join(missing))


def check_localizations() -> None:
    text = (ROOT / "lib/app/localization/app_strings.dart").read_text(encoding="utf-8")
    # Parse the three top-level locale map bodies using their explicit markers.
    blocks: dict[str, str] = {}
    for code, next_code in (("de", "en"), ("en", "ar")):
        start = text.find(f"    '{code}': {{")
        end = text.find(f"    '{next_code}': {{", start + 1)
        if start < 0 or end < 0:
            fail(f"cannot locate localization block {code}")
        blocks[code] = text[start:end]
    start = text.find("    'ar': {")
    end = text.find("};\n\nclass", start)
    if start < 0 or end < 0:
        # Fallback to the end of the map when class formatting differs.
        end = text.rfind("};")
    blocks["ar"] = text[start:end]

    key_re = re.compile(r"^      '([^']+)'\s*:\s*", re.MULTILINE)
    keys = {code: set(key_re.findall(body)) for code, body in blocks.items()}
    reference = keys["de"]
    for code in ("en", "ar"):
        if keys[code] != reference:
            missing = sorted(reference - keys[code])
            extra = sorted(keys[code] - reference)
            fail(f"localization key mismatch for {code}; missing={missing}, extra={extra}")


def check_native_safety() -> None:
    android = (ROOT / "native/android/MainActivity.kt").read_text(encoding="utf-8")
    ios = (ROOT / "native/ios/AppDelegate.swift").read_text(encoding="utf-8")
    monitor = (ROOT / "native/ios/PrayerDeviceActivityMonitor/PrayerDeviceActivityMonitor.swift").read_text(encoding="utf-8")
    setup = (ROOT / "tool/apply_platform_setup.py").read_text(encoding="utf-8")
    forbidden = ("android.permission.SYSTEM_ALERT_WINDOW", "android.permission.QUERY_ALL_PACKAGES", "android.permission.BIND_ACCESSIBILITY_SERVICE")
    for token in forbidden:
        if token in setup:
            fail(f"unsafe/unsupported Android permission found in platform setup: {token}")
    if "store.shield.applicationCategories = nil" not in ios or "store.shield.applicationCategories = nil" not in monitor:
        fail("iOS category shielding must stay disabled for the MVP safety model")
    if "clearAllSettings()" not in ios or "clearAllSettings()" not in monitor:
        fail("iOS fail-open shield cleanup is missing")


def check_no_placeholders() -> None:
    hits: list[str] = []
    pattern = re.compile(r"\b(TODO|FIXME|IMPLEMENT_ME)\b")
    for root in (ROOT / "lib", ROOT / "native", ROOT / "test", ROOT / "integration_test"):
        for file in root.rglob("*"):
            if file.is_file() and file.suffix in {".dart", ".kt", ".swift"}:
                for index, line in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
                    if pattern.search(line):
                        hits.append(f"{file.relative_to(ROOT)}:{index}")
    if hits:
        fail("placeholder markers remain: " + ", ".join(hits))


def main() -> int:
    check_required_files()
    check_pubspec()
    check_local_imports()
    check_localizations()
    check_native_safety()
    check_no_placeholders()
    dart_files = len(list((ROOT / "lib").rglob("*.dart")))
    tests = len(list((ROOT / "test").rglob("*_test.dart"))) + len(
        list((ROOT / "integration_test").rglob("*_test.dart"))
    )
    print(f"Source verification passed: {dart_files} Dart source files, {tests} tests.")
    print("Run `flutter analyze` and `flutter test` on a Flutter 3.47+ workstation for compiler-level verification.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
