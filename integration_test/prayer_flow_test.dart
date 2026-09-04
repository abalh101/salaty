import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_state_machine.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_status.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_type.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const PrayerStateMachine machine = PrayerStateMachine();

  PrayerEntry prayer(PrayerType type, DateTime scheduled) => PrayerEntry(
        id: '2026-08-14:${type.name}',
        localDate: '2026-08-14',
        type: type,
        scheduledAtUtc: scheduled,
        timezoneId: 'Europe/Berlin',
        graceEndsAtUtc: scheduled.add(const Duration(hours: 1)),
        trackingEndsAtUtc: scheduled.add(const Duration(hours: 4)),
        status: PrayerStatus.upcoming,
      );

  test('scenario 1: Fajr begins and user confirms prayer', () {
    final DateTime start = DateTime.utc(2026, 8, 14, 2, 21);
    PrayerEntry fajr = machine.advance(prayer(PrayerType.fajr, start), start);
    expect(fajr.status, PrayerStatus.active);

    fajr = machine.confirm(fajr, start.add(const Duration(minutes: 8)));
    expect(fajr.status, PrayerStatus.prayed);
    expect(fajr.confirmedAtUtc, start.add(const Duration(minutes: 8)));
  });

  test('scenario 2: Dhuhr grace expires, snoozes 20 minutes, then returns pending', () {
    final DateTime start = DateTime.utc(2026, 8, 14, 11, 31);
    final PrayerEntry dhuhr = prayer(PrayerType.dhuhr, start);
    final DateTime graceEnd = start.add(const Duration(hours: 1));

    PrayerEntry current = machine.advance(dhuhr, graceEnd);
    expect(current.status, PrayerStatus.pending);

    current = machine.snooze(
      current,
      graceEnd,
      const Duration(minutes: 20),
      maximumSnoozes: 2,
    );
    expect(current.status, PrayerStatus.snoozed);

    current = machine.advance(current, graceEnd.add(const Duration(minutes: 20)));
    expect(current.status, PrayerStatus.pending);
  });

  test('scenario 3: Asr Prayer Focus ends after confirmation', () {
    final DateTime start = DateTime.utc(2026, 8, 14, 15, 18);
    final PrayerEntry asr = prayer(PrayerType.asr, start);
    PrayerEntry current = machine.advance(
      asr,
      start.add(const Duration(hours: 1)),
    );
    expect(current.status, PrayerStatus.pending);

    current = machine.confirm(
      current,
      start.add(const Duration(hours: 1, minutes: 4)),
    );
    expect(current.status, PrayerStatus.prayed);
  });
}
