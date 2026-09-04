import 'package:flutter_test/flutter_test.dart';
import 'package:salah_focus/core/time/timezone_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('Berlin winter time converts with CET offset', () {
    final DateTime value = TimezoneService.localPartsToUtc(
      dateIso: '2026-01-15',
      hhmm: '12:30 (CET)',
      timezoneId: 'Europe/Berlin',
    );
    expect(value, DateTime.utc(2026, 1, 15, 11, 30));
  });

  test('Berlin summer time converts with CEST offset', () {
    final DateTime value = TimezoneService.localPartsToUtc(
      dateIso: '2026-08-14',
      hhmm: '12:30 (CEST)',
      timezoneId: 'Europe/Berlin',
    );
    expect(value, DateTime.utc(2026, 8, 14, 10, 30));
  });

  test('timezone conversion follows DST instead of fixed UTC offsets', () {
    final winter = TimezoneService.toLocal(DateTime.utc(2026, 1, 15, 12), 'Europe/Berlin');
    final summer = TimezoneService.toLocal(DateTime.utc(2026, 8, 14, 12), 'Europe/Berlin');
    expect(winter.hour, 13);
    expect(summer.hour, 14);
  });
}
