import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';

/// Safety policy shared by scheduled and live Prayer Focus sessions.
class PrayerFocusPolicy {
  const PrayerFocusPolicy();

  /// A native shield may never remain active for more than this duration from
  /// the original grace-period end, even if the prayer tracking window is
  /// longer. The in-app prayer state can continue independently afterwards.
  static const Duration maximumNativeFocusDuration = Duration(minutes: 90);

  DateTime maximumEnd(PrayerEntry prayer) {
    final DateTime hardLimit = prayer.graceEndsAtUtc.add(
      maximumNativeFocusDuration,
    );
    return prayer.trackingEndsAtUtc.isBefore(hardLimit)
        ? prayer.trackingEndsAtUtc
        : hardLimit;
  }
}
