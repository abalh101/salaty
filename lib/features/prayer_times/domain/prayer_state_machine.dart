import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_status.dart';

class PrayerStateMachine {
  const PrayerStateMachine();

  PrayerEntry advance(PrayerEntry prayer, DateTime nowUtc) {
    final DateTime now = nowUtc.toUtc();
    if (prayer.status.isFinal) {
      return prayer;
    }

    if (!now.isBefore(prayer.trackingEndsAtUtc)) {
      return prayer.copyWith(
        status: PrayerStatus.missed,
        clearSnoozedUntil: true,
      );
    }

    if (prayer.status == PrayerStatus.snoozed) {
      final DateTime? until = prayer.snoozedUntilUtc;
      if (until != null && !now.isBefore(until)) {
        return prayer.copyWith(
          status: PrayerStatus.pending,
          clearSnoozedUntil: true,
        );
      }
      return prayer;
    }

    if (!now.isBefore(prayer.graceEndsAtUtc)) {
      return prayer.copyWith(status: PrayerStatus.pending);
    }

    if (!now.isBefore(prayer.scheduledAtUtc)) {
      return prayer.copyWith(status: PrayerStatus.active);
    }

    return prayer.copyWith(status: PrayerStatus.upcoming);
  }

  PrayerEntry confirm(PrayerEntry prayer, DateTime nowUtc) {
    if (prayer.status == PrayerStatus.skipped ||
        prayer.status == PrayerStatus.missed) {
      // A user can still record that they prayed later; the app is a tracker,
      // not a religious authority.
    }
    return prayer.copyWith(
      status: PrayerStatus.prayed,
      confirmedAtUtc: nowUtc.toUtc(),
      clearSnoozedUntil: true,
    );
  }

  PrayerEntry snooze(
    PrayerEntry prayer,
    DateTime nowUtc,
    Duration duration, {
    int? maximumSnoozes,
  }) {
    if (prayer.status.isFinal) {
      throw StateError('A finished prayer cannot be snoozed.');
    }
    if (maximumSnoozes != null && prayer.snoozeCount >= maximumSnoozes) {
      throw StateError('Maximum snooze count reached.');
    }
    final DateTime until = nowUtc.toUtc().add(duration);
    if (!until.isBefore(prayer.trackingEndsAtUtc)) {
      throw StateError('Snooze would exceed the tracking window.');
    }
    return prayer.copyWith(
      status: PrayerStatus.snoozed,
      snoozedUntilUtc: until,
      snoozeCount: prayer.snoozeCount + 1,
    );
  }

  PrayerEntry skip(PrayerEntry prayer) {
    if (prayer.status == PrayerStatus.prayed) {
      throw StateError('A confirmed prayer cannot be skipped.');
    }
    return prayer.copyWith(
      status: PrayerStatus.skipped,
      clearSnoozedUntil: true,
    );
  }
}
