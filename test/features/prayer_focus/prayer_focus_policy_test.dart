import 'package:flutter_test/flutter_test.dart';
import 'package:salah_focus/features/prayer_focus/domain/prayer_focus_policy.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_status.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_type.dart';

void main() {
  const PrayerFocusPolicy policy = PrayerFocusPolicy();
  final DateTime scheduled = DateTime.utc(2026, 8, 14, 15);

  PrayerEntry entry({required DateTime trackingEnd}) => PrayerEntry(
        id: '2026-08-14:asr',
        localDate: '2026-08-14',
        type: PrayerType.asr,
        scheduledAtUtc: scheduled,
        timezoneId: 'Europe/Berlin',
        graceEndsAtUtc: scheduled.add(const Duration(hours: 1)),
        trackingEndsAtUtc: trackingEnd,
        status: PrayerStatus.pending,
      );

  test('native focus is capped at 90 minutes after grace end', () {
    final PrayerEntry prayer = entry(
      trackingEnd: scheduled.add(const Duration(hours: 5)),
    );

    expect(
      policy.maximumEnd(prayer),
      scheduled.add(const Duration(hours: 2, minutes: 30)),
    );
  });

  test('next prayer tracking end wins when it is earlier than hard cap', () {
    final PrayerEntry prayer = entry(
      trackingEnd: scheduled.add(const Duration(hours: 2)),
    );

    expect(policy.maximumEnd(prayer), prayer.trackingEndsAtUtc);
  });
}
