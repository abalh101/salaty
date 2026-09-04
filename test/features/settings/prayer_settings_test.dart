import 'package:flutter_test/flutter_test.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_settings.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_type.dart';

void main() {
  test('settings round-trip preserves prayer calculation configuration', () {
    final PrayerSettings value = PrayerSettings(
      calculationMethodId: 13,
      madhhab: AsrMadhhab.hanafi,
      highLatitudeRule: HighLatitudeRule.angleBased,
      gracePeriodMinutes: 45,
      snoozeMinutes: 15,
      maxSnoozes: 3,
      focusEnabled: true,
      softReminderAfterSkip: false,
      confirmationText: 'Alhamdulillah, erledigt',
      adjustments: const <PrayerType, int>{PrayerType.fajr: 2, PrayerType.isha: -2},
    );

    final PrayerSettings decoded = PrayerSettings.fromJson(value.toJson());
    expect(decoded.calculationMethodId, 13);
    expect(decoded.madhhab, AsrMadhhab.hanafi);
    expect(decoded.highLatitudeRule, HighLatitudeRule.angleBased);
    expect(decoded.gracePeriodMinutes, 45);
    expect(decoded.snoozeMinutes, 15);
    expect(decoded.maxSnoozes, 3);
    expect(decoded.focusEnabled, isTrue);
    expect(decoded.adjustmentFor(PrayerType.fajr), 2);
    expect(decoded.adjustmentFor(PrayerType.isha), -2);
  });


  test('invalid stored values are sanitized instead of crashing', () {
    final PrayerSettings decoded = PrayerSettings.fromJson(
      <String, Object?>{
        'calculationMethodId': 999,
        'madhhab': 'future_value',
        'highLatitudeRule': 'future_value',
        'gracePeriodMinutes': -500,
        'snoozeMinutes': 900,
        'maxSnoozes': 99,
        'confirmationText': '   ',
        'adjustments': <String, int>{'fajr': 999},
      },
    );

    expect(decoded.calculationMethodId, 3);
    expect(decoded.madhhab, AsrMadhhab.standard);
    expect(decoded.highLatitudeRule, HighLatitudeRule.angleBased);
    expect(decoded.gracePeriodMinutes, 0);
    expect(decoded.snoozeMinutes, 30);
    expect(decoded.maxSnoozes, 5);
    expect(decoded.adjustmentFor(PrayerType.fajr), 60);
    expect(decoded.confirmationText, 'Wallah, ich habe gebetet');
  });
}
