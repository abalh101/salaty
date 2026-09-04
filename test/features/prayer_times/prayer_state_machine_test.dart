import 'package:flutter_test/flutter_test.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_state_machine.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_status.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_type.dart';

void main() {
  const PrayerStateMachine machine = PrayerStateMachine();
  final DateTime scheduled = DateTime.utc(2026, 8, 14, 15);

  PrayerEntry entry({PrayerStatus status = PrayerStatus.upcoming, DateTime? snoozedUntil, int snoozeCount = 0}) => PrayerEntry(
        id: '2026-08-14:asr',
        localDate: '2026-08-14',
        type: PrayerType.asr,
        scheduledAtUtc: scheduled,
        timezoneId: 'Europe/Berlin',
        graceEndsAtUtc: scheduled.add(const Duration(hours: 1)),
        trackingEndsAtUtc: scheduled.add(const Duration(hours: 3)),
        status: status,
        snoozedUntilUtc: snoozedUntil,
        snoozeCount: snoozeCount,
      );

  group('PrayerStateMachine.advance', () {
    test('keeps upcoming prayer before scheduled time', () {
      expect(machine.advance(entry(), scheduled.subtract(const Duration(seconds: 1))).status, PrayerStatus.upcoming);
    });

    test('moves prayer to active when prayer time begins', () {
      expect(machine.advance(entry(), scheduled).status, PrayerStatus.active);
    });

    test('moves prayer to pending when grace period expires', () {
      expect(machine.advance(entry(), scheduled.add(const Duration(hours: 1))).status, PrayerStatus.pending);
    });

    test('returns snoozed prayer to pending after snooze expires', () {
      final DateTime until = scheduled.add(const Duration(hours: 1, minutes: 20));
      final PrayerEntry snoozed = entry(status: PrayerStatus.snoozed, snoozedUntil: until, snoozeCount: 1);
      expect(machine.advance(snoozed, until).status, PrayerStatus.pending);
    });

    test('marks unresolved prayer missed when tracking window ends', () {
      expect(machine.advance(entry(status: PrayerStatus.pending), scheduled.add(const Duration(hours: 3))).status, PrayerStatus.missed);
    });

    test('does not rewrite final state', () {
      final PrayerEntry prayed = machine.confirm(entry(), scheduled.add(const Duration(minutes: 10)));
      expect(machine.advance(prayed, scheduled.add(const Duration(days: 1))).status, PrayerStatus.prayed);
    });
  });

  group('actions', () {
    test('confirmation stores time and prayed state', () {
      final DateTime confirmation = scheduled.add(const Duration(minutes: 8));
      final PrayerEntry result = machine.confirm(entry(status: PrayerStatus.active), confirmation);
      expect(result.status, PrayerStatus.prayed);
      expect(result.confirmedAtUtc, confirmation);
    });

    test('snooze increments counter and schedules next pending time', () {
      final DateTime now = scheduled.add(const Duration(hours: 1));
      final PrayerEntry result = machine.snooze(entry(status: PrayerStatus.pending), now, const Duration(minutes: 20), maximumSnoozes: 2);
      expect(result.status, PrayerStatus.snoozed);
      expect(result.snoozeCount, 1);
      expect(result.snoozedUntilUtc, now.add(const Duration(minutes: 20)));
    });

    test('multiple snoozes respect configured maximum', () {
      final PrayerEntry twice = entry(status: PrayerStatus.pending, snoozeCount: 2);
      expect(
        () => machine.snooze(twice, scheduled.add(const Duration(hours: 1)), const Duration(minutes: 20), maximumSnoozes: 2),
        throwsStateError,
      );
    });

    test('snooze cannot extend beyond prayer tracking window', () {
      final PrayerEntry pending = entry(status: PrayerStatus.pending);
      expect(
        () => machine.snooze(
          pending,
          scheduled.add(const Duration(hours: 2, minutes: 55)),
          const Duration(minutes: 20),
        ),
        throwsStateError,
      );
    });

    test('skip produces skipped final state', () {
      expect(machine.skip(entry(status: PrayerStatus.pending)).status, PrayerStatus.skipped);
    });
  });
}
