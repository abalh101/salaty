import 'package:salah_focus/features/prayer_times/domain/prayer_settings.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_type.dart';
import 'package:salah_focus/features/prayer_times/domain/user_location.dart';

/// Builds a deterministic fingerprint for prayer-time data stored offline.
///
/// A cached month is only safe to reuse when the location and all settings
/// that influence the generated prayer schedule still match.
abstract final class PrayerCacheKey {
  static String build(UserLocation location, PrayerSettings settings) {
    final String adjustments = PrayerType.values
        .map((PrayerType type) => '${type.name}:${settings.adjustmentFor(type)}')
        .join(',');
    return '${location.latitude.toStringAsFixed(5)}|'
        '${location.longitude.toStringAsFixed(5)}|'
        '${settings.calculationMethodId}|'
        '${settings.madhhab.name}|'
        '${settings.highLatitudeRule.name}|'
        '$adjustments|'
        '${settings.gracePeriodMinutes}';
  }
}
