import 'package:flutter_test/flutter_test.dart';
import 'package:salah_focus/features/prayer_times/data/prayer_cache_key.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_settings.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_type.dart';
import 'package:salah_focus/features/prayer_times/domain/user_location.dart';

void main() {
  const UserLocation duesseldorf = UserLocation(
    latitude: 51.2277,
    longitude: 6.7735,
    city: 'Düsseldorf',
    country: 'Deutschland',
    timezoneId: 'Europe/Berlin',
    isAutomatic: false,
  );

  test('cache key changes when prayer-time inputs change', () {
    const PrayerSettings base = PrayerSettings();
    final String baseKey = PrayerCacheKey.build(duesseldorf, base);

    expect(
      PrayerCacheKey.build(
        duesseldorf,
        base.copyWith(calculationMethodId: 13),
      ),
      isNot(baseKey),
    );
    expect(
      PrayerCacheKey.build(
        duesseldorf,
        base.copyWith(
          adjustments: <PrayerType, int>{PrayerType.fajr: 2},
        ),
      ),
      isNot(baseKey),
    );
    expect(
      PrayerCacheKey.build(
        duesseldorf,
        base.copyWith(gracePeriodMinutes: 30),
      ),
      isNot(baseKey),
    );
  });

  test('cache key changes with location', () {
    const PrayerSettings settings = PrayerSettings();
    const UserLocation istanbul = UserLocation(
      latitude: 41.0082,
      longitude: 28.9784,
      city: 'Istanbul',
      country: 'Türkiye',
      timezoneId: 'Europe/Istanbul',
      isAutomatic: false,
    );

    expect(
      PrayerCacheKey.build(duesseldorf, settings),
      isNot(PrayerCacheKey.build(istanbul, settings)),
    );
  });
}
