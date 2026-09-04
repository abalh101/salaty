import 'package:salah_focus/core/notifications/notification_service.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_status.dart';

class PrayerNotificationPlanner {
  PrayerNotificationPlanner(this._notifications);

  final NotificationService _notifications;

  Future<void> reschedule(
    List<PrayerEntry> entries, {
    required String Function(PrayerEntry entry) prayerName,
    required String languageCode,
    DateTime? nowUtc,
    int horizonDays = 4,
  }) async {
    final DateTime now = (nowUtc ?? DateTime.now()).toUtc();
    final DateTime horizon = now.add(Duration(days: horizonDays));
    await _notifications.cancelAllFuturePrayerNotifications();
    for (final PrayerEntry entry in entries) {
      if (entry.status == PrayerStatus.prayed ||
          entry.status == PrayerStatus.skipped ||
          entry.status == PrayerStatus.missed) {
        continue;
      }
      if (entry.scheduledAtUtc.isAfter(now) &&
          entry.scheduledAtUtc.isBefore(horizon)) {
        await _notifications.schedulePrayer(entry, prayerName(entry), languageCode: languageCode);
      }
      if (entry.graceEndsAtUtc.isAfter(now) &&
          entry.graceEndsAtUtc.isBefore(horizon)) {
        await _notifications.scheduleGraceReminder(entry, prayerName(entry), languageCode: languageCode);
      }
      if (entry.status == PrayerStatus.snoozed &&
          entry.snoozedUntilUtc != null &&
          entry.snoozedUntilUtc!.isAfter(now)) {
        await _notifications.scheduleSnoozeReminder(entry, prayerName(entry), languageCode: languageCode);
      }
    }
  }
}
