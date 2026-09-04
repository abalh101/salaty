# Build and verification notes

This repository was assembled as a complete SalahFocus MVP source tree. The execution environment used to create this archive does not contain the Flutter or Dart SDK and does not permit downloading it, so an actual `flutter analyze`, `flutter test`, Android build or iOS build could not be executed here.

## Verification already performed

- Dependency-free Python source verifier passes (`python3 tool/verify_source.py`).
- All local Dart package imports resolve to files in this repository.
- DE/EN/AR localization key sets are identical.
- YAML parses successfully.
- Bootstrap shell syntax is valid.
- Swift source parses successfully with `swiftc -frontend -parse`.
- Android Kotlin bridge syntax was checked with lightweight Flutter API stubs.
- `tool/apply_platform_setup.py` passes `python3 tool/smoke_platform_setup.py` against synthetic Android/iOS Flutter template files.
- The Android setup intentionally excludes Accessibility, overlays, full-screen intent, background location and device-owner privileges.
- Native Focus scheduling has a 90-minute hard cap and a cancel-all path when Focus is disabled.
- Current notification API usage was checked against the package documentation for the pinned dependency line.

## Verification required on a Flutter workstation

Run either bootstrap script. It generates the Flutter platform templates, patches them, resolves dependencies and then runs analyzer/tests automatically.

macOS/Linux:

```bash
chmod +x tool/bootstrap.sh
./tool/bootstrap.sh
```

Windows PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
./tool/bootstrap.ps1
```

Then test physical devices before release:

```bash
flutter run
flutter test integration_test
flutter build appbundle --release
# macOS only, after Apple signing/entitlements:
flutter build ipa --release
```

## iOS release prerequisite

Native iOS app shielding depends on Apple's Family Controls entitlement and a Device Activity Monitor Extension target. The source and entitlement templates are included under `native/ios/`, but Apple Developer approval, signing and attaching the extension target must be done in Xcode with the developer account that will publish the app.

## Android Prayer Focus

Android intentionally ships the fail-safe in-app Prayer Focus mode rather than an Accessibility/overlay-based blocker. This is a product and store-safety decision, not an unfinished placeholder.
