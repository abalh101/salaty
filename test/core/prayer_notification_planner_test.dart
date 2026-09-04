import 'package:flutter_test/flutter_test.dart';
import 'package:salah_focus/core/notifications/notification_service.dart';
import 'package:salah_focus/core/notifications/prayer_notification_planner.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_status.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_type.dart';

void main() {
  test('planner schedules prayer and grace reminder for future prayer', () async {
    final FakeNotificationService service = FakeNotificationService();
    final PrayerNotificationPlanner planner = PrayerNotificationPlanner(service);
    final PrayerEntry entry = _entry(DateTime.utc(2026, 8, 15, 10));

    await planner.reschedule(<PrayerEntry>[entry], prayerName: (_) => 'Dhuhr', languageCode: 'en', nowUtc: DateTime.utc(2026, 8, 14, 10));

    expect(service.cancelledPending, 1);
    expect(service.prayers, <String>[entry.id]);
    expect(service.grace, <String>[entry.id]);
  });

  test('planner ignores final prayers', () async {
    final FakeNotificationService service = FakeNotificationService();
    final PrayerNotificationPlanner planner = PrayerNotificationPlanner(service);
    final PrayerEntry entry = _entry(DateTime.utc(2026, 8, 15, 10)).copyWith(status: PrayerStatus.prayed);

    await planner.reschedule(<PrayerEntry>[entry], prayerName: (_) => 'Dhuhr', languageCode: 'en', nowUtc: DateTime.utc(2026, 8, 14, 10));

    expect(service.prayers, isEmpty);
    expect(service.grace, isEmpty);
  });
}

PrayerEntry _entry(DateTime scheduled) => PrayerEntry(
      id: '2026-08-15:dhuhr',
      localDate: '2026-08-15',
      type: PrayerType.dhuhr,
      scheduledAtUtc: scheduled,
      timezoneId: 'Europe/Berlin',
      graceEndsAtUtc: scheduled.add(const Duration(hours: 1)),
      trackingEndsAtUtc: scheduled.add(const Duration(hours: 4)),
      status: PrayerStatus.upcoming,
    );

class FakeNotificationService implements NotificationService {
  @override
  Stream<String> get payloads => const Stream<String>.empty();

  final List<String> prayers = <String>[];
  final List<String> grace = <String>[];
  int cancelledPending = 0;

  @override
  Future<bool> canScheduleExactly() async => true;

  @override
  Future<String?> takeInitialPayload() async => null;

  @override
  Future<void> cancelAllFuturePrayerNotifications() async => cancelledPending++;

  @override
  Future<void> cancelPrayer(PrayerEntry prayer) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleGraceReminder(PrayerEntry prayer, String prayerName, {required String languageCode}) async => grace.add(prayer.id);

  @override
  Future<void> schedulePrayer(PrayerEntry prayer, String prayerName, {required String languageCode}) async => prayers.add(prayer.id);

  @override
  Future<void> scheduleSnoozeReminder(PrayerEntry prayer, String prayerName, {required String languageCode}) async {}

  @override
  Future<void> scheduleSoftReminder(PrayerEntry prayer, String prayerName, {required String languageCode}) async {}
}
