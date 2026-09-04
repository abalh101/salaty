# SalahFocus

**Prayer first, phone second.**

SalahFocus is a local-first Flutter app for Muslims who want reliable prayer reminders and a calm way to reduce phone distractions around Salah. It combines prayer times, confirmation, configurable grace periods, snooze, a prayer tracker, Qibla and a fail-safe Prayer Focus mode.

The app is intentionally **not** a religious authority and does not shame or judge the user. Focus restrictions are voluntary and always fail open.

## MVP included

- iOS + Android Flutter application architecture
- 7-step onboarding
- GPS location or manual city/country selection
- AlAdhan monthly prayer-time provider behind a provider interface
- local SQLite cache for prayer days/history
- five daily prayers: Fajr, Dhuhr, Asr, Maghrib, Isha
- calculation method, Asr school, high-latitude rule and per-prayer minute offsets
- correct IANA timezone/DST handling
- next-prayer countdown and daily prayer status
- local prayer-time, grace-period and snooze notifications
- Android exact-alarm permission fallback
- Prayer state machine: upcoming → active → pending → prayed/snoozed/skipped/missed
- configurable grace period, snooze duration and snooze limit
- configurable confirmation text
- safe Emergency Unlock with a per-prayer bypass
- tracker: today, current week and current month
- Qibla bearing + compass fallback
- light/dark/system theme
- German, English and Arabic/RTL UI architecture
- notification deep links into Prayer Focus
- Android safe Basic Prayer Focus fallback
- native iOS Screen Time bridge using FamilyControls / ManagedSettings / DeviceActivity
- unit and integration tests

Features explicitly described as later phases in the product specification (Quran, Adhkar library, mosque search, accounts/cloud sync, Watch/Wear OS, family mode, Ramadan tracker and widgets) are not bundled into this first release branch.

## Required toolchain

Recommended baseline:

- Flutter **3.47.0+**
- Dart **3.13.0+** (bundled with Flutter 3.47)
- Android Studio with Android SDK API 36
- Java 17+
- Xcode with an iOS 16+ SDK for iOS builds
- CocoaPods for iOS

Check your environment:

```bash
flutter doctor -v
```

## First-time setup

This source archive intentionally keeps generated Flutter platform scaffolding reproducible instead of checking in machine-generated Android/iOS template files.

### macOS / Linux

```bash
chmod +x tool/bootstrap.sh
./tool/bootstrap.sh
```

### Windows PowerShell

```powershell
Set-ExecutionPolicy -Scope Process Bypass
./tool/bootstrap.ps1
```

The bootstrap script:

1. creates fresh Android/iOS platform templates with the installed Flutter SDK,
2. applies SalahFocus Android/iOS native code,
3. configures scheduled-notification receivers and permissions,
4. enables Android core-library desugaring,
5. configures the iOS location usage description,
6. runs `flutter pub get`,
7. runs `flutter analyze`,
8. runs `flutter test`.

Then start the app:

```bash
flutter run
```

## Manual Flutter commands

After bootstrapping:

```bash
flutter pub get
flutter analyze
flutter test
flutter test integration_test
```

Release builds:

```bash
flutter build appbundle --release
flutter build ipa --release
```

Signing still has to be configured with your own Google Play / Apple Developer credentials.


### Source-only verification

If Flutter is not installed yet, the repository still includes a lightweight, dependency-free Python static verifier that checks required source files, package imports, localization-key parity and unsafe Android permission regressions:

```bash
python3 tool/verify_source.py
python3 tool/smoke_platform_setup.py
```

This is not a replacement for `flutter analyze` or `flutter test`; compiler-level verification requires the Flutter SDK.

## Android setup

`tool/apply_platform_setup.py` adds only the permissions the current MVP needs:

- `INTERNET`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_FINE_LOCATION`
- `POST_NOTIFICATIONS`
- `RECEIVE_BOOT_COMPLETED`
- `VIBRATE`
- `SCHEDULE_EXACT_ALARM`

The app deliberately does **not** request:

- `QUERY_ALL_PACKAGES`
- `SYSTEM_ALERT_WINDOW`
- `USE_FULL_SCREEN_INTENT`
- background location
- an Accessibility Service
- device-owner privileges

### Exact alarms

Prayer notifications use exact scheduling only when Android reports that the app can schedule exact alarms. Otherwise SalahFocus automatically uses an inexact idle-safe notification mode.

Android vendors can still apply additional background/battery restrictions to scheduled work. The release checklist therefore requires physical-device testing on Samsung, Pixel and at least one aggressively managed Android skin such as Xiaomi; SalahFocus does not attempt to bypass OEM power-management policies.

The user can request precise-alarm permission from Onboarding or Settings. A denied permission must never crash the app.

### Android Prayer Focus

A normal consumer Android app cannot safely suspend arbitrary third-party apps through a general public app-blocking API. SalahFocus therefore does **not** disguise an Accessibility Service or overlay as an app blocker.

Android MVP behavior:

- Prayer Focus screen inside SalahFocus
- persistent prayer/focus state
- notifications after grace/snooze
- confirmation, snooze and skip
- Emergency Unlock
- no lock-out of Phone, Maps, emergency or system functionality

The Kotlin platform bridge explicitly reports system-level app shielding as unavailable. This is intentional.

## iOS setup

The main iOS platform-channel implementation is in:

```text
native/ios/AppDelegate.swift
```

It uses:

- `FamilyControls`
- `ManagedSettings`
- `DeviceActivity`
- `FamilyActivityPicker`

The selection is stored in the App Group:

```text
group.com.salahfocus.app
```

### Important: Apple Family Controls entitlement

Apple controls distribution of the Family Controls entitlement. No repository can include an approval for your Apple Developer account.

To enable real iOS app shielding:

1. Create/register the Runner App ID in your Apple Developer account.
2. Request/enable **Family Controls** for the app.
3. Add the **Family Controls** capability in Xcode.
4. Add the **App Groups** capability and group `group.com.salahfocus.app`.
5. Use the template `native/ios/entitlements/Runner.entitlements` as the Runner entitlement configuration.
6. Add a **Device Activity Monitor Extension** target in Xcode.
7. Add `native/ios/PrayerDeviceActivityMonitor/PrayerDeviceActivityMonitor.swift` to that extension target.
8. Use `native/ios/PrayerDeviceActivityMonitor/Info.plist` for the monitor extension configuration.
9. Add Family Controls + the same App Group to the extension target.
10. Apply `native/ios/entitlements/PrayerDeviceActivityMonitor.entitlements` to the extension.
11. Request the distribution entitlement for every Screen Time target before App Store submission.

Without Apple authorization, all prayer-time, tracker, Qibla, notification and Basic Prayer Focus features still work; native shielding simply fails open.

### iOS fail-safe design

- selected apps only are shielded
- category-wide shielding is disabled; only explicit app selections are applied
- the picker uses privacy-preserving app tokens, so SalahFocus does not try to inspect app identities; the UI tells the user to leave SalahFocus and essential apps unselected
- direct `stopFocus()` always clears the named ManagedSettings store
- disabling Prayer Focus immediately cancels every SalahFocus `DeviceActivity` schedule and clears active shields
- a native shield has a hard safety cap of **90 minutes after the configured grace period ends**, or earlier when the prayer tracking window ends
- background iOS shields are scheduled on a rolling **48-hour** window to avoid excessive DeviceActivity monitoring; prayer notifications remain planned farther ahead
- scheduled DeviceActivity intervals have an end time
- the monitor extension clears shields at interval end
- Emergency Unlock clears the current session and creates a temporary bypass
- no code attempts to lock the entire iPhone

## Prayer-time API

The MVP uses the AlAdhan calendar endpoint through the abstraction:

```text
PrayerTimesProvider
└── AlAdhanPrayerTimesProvider
```

No API key is hardcoded or required for this provider.

The app requests a monthly calendar, converts the provider's local prayer times using the returned IANA timezone and caches prayer entries locally. Every cached month is bound to a source profile containing location, calculation method, Madhhab, high-latitude rule, minute adjustments and grace period, so stale data from another city or configuration is not silently reused. Month boundaries are repaired when adjacent months are cached so the final Isha tracking window ends at the following Fajr. The UI reads from the repository instead of directly from the network.

Failure behavior:

1. try network refresh,
2. use the cached month if refresh fails,
3. use today's cached data if present,
4. show a clear error if no reliable cache exists,
5. never fabricate `00:00` prayer times.

## Local data

SQLite (`sqflite`) stores:

- prayer entries/history
- cached prayer schedules
- prayer-day metadata and timezone
- Hijri display value from the prayer provider
- focus sessions
- Emergency Unlock bypass state

Small user preferences are stored locally with SharedPreferences:

- location selection
- calculation settings
- grace/snooze settings
- theme/language
- onboarding status

No account is required.

## Project structure

```text
lib/
├── app/
│   ├── localization/
│   └── router/
├── core/
│   ├── api/
│   ├── database/
│   ├── errors/
│   ├── location/
│   ├── notifications/
│   ├── theme/
│   └── time/
├── features/
│   ├── onboarding/
│   ├── prayer_focus/
│   ├── prayer_times/
│   ├── prayer_tracker/
│   ├── qibla/
│   └── settings/
└── shared/
```

Business logic does not depend on widgets. Prayer Focus is behind `PrayerFocusService`, and prayer-time providers are interchangeable.

## State machine

```text
UPCOMING
   │ prayer begins
   ▼
ACTIVE
   │ grace expires
   ▼
PENDING ───────► PRAYED
   │
   ├───────────► SKIPPED
   │
   └───────────► SNOOZED
                    │ snooze expires
                    ▼
                 PENDING

ACTIVE / PENDING / SNOOZED
            │ tracking window ends
            ▼
          MISSED
```

`MISSED` is presented to the user as **not confirmed**, not as a religious ruling.

## Tests

Current tests include:

```text
test/features/prayer_times/prayer_state_machine_test.dart
test/features/prayer_times/prayer_cache_key_test.dart
test/core/timezone_service_test.dart
test/core/prayer_notification_planner_test.dart
test/features/settings/prayer_settings_test.dart
test/features/prayer_focus/prayer_focus_policy_test.dart
test/features/qibla/qibla_calculator_test.dart
integration_test/app_smoke_test.dart
integration_test/prayer_flow_test.dart
```

Run:

```bash
flutter test
flutter test integration_test
```

## Privacy

See [PRIVACY.md](PRIVACY.md).

Design principles:

- local first
- no advertising SDK
- no prayer-behavior analytics
- no public ranking
- no account requirement
- no sale of data
- no permanent background GPS

## Release checklist

Before publishing:

- run `flutter analyze`
- run all unit/integration tests on real Android and iPhone devices
- verify prayer times against local mosque expectations for supported methods
- test Berlin DST transitions and at least one non-European timezone
- test offline launch with an existing monthly cache
- test denied location and notification permissions
- test Android exact-alarm denied/allowed states
- test Android reboot rescheduling
- test iOS Family Controls authorization revoked while Focus is enabled
- test Emergency Unlock repeatedly
- test Arabic RTL and large text / VoiceOver / TalkBack
- configure Android release signing
- configure Apple signing and Family Controls distribution entitlement
- prepare App Store privacy details and Google Play Data Safety declaration
- replace default Flutter app icons with final licensed brand assets
- only add licensed Adhan audio if audio is enabled in a later release

## Product safety rule

If any platform-specific Prayer Focus operation fails, SalahFocus **fails open**. It must never leave a person permanently unable to use their device.
