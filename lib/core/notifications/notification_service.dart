import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';

abstract interface class NotificationService {
  Stream<String> get payloads;

  Future<void> initialize();

  Future<String?> takeInitialPayload();

  Future<bool> requestPermission();

  Future<bool> requestExactAlarmPermission();

  Future<bool> canScheduleExactly();

  Future<void> schedulePrayer(
    PrayerEntry prayer,
    String prayerName, {
    required String languageCode,
  });

  Future<void> scheduleGraceReminder(
    PrayerEntry prayer,
    String prayerName, {
    required String languageCode,
  });

  Future<void> scheduleSnoozeReminder(
    PrayerEntry prayer,
    String prayerName, {
    required String languageCode,
  });

  Future<void> scheduleSoftReminder(
    PrayerEntry prayer,
    String prayerName, {
    required String languageCode,
  });

  Future<void> cancelPrayer(PrayerEntry prayer);

  Future<void> cancelAllFuturePrayerNotifications();
}
