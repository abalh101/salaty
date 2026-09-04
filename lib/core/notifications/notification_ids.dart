import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';

class NotificationIds {
  const NotificationIds._();

  static int prayer(PrayerEntry entry) => _base(entry) + 1;
  static int grace(PrayerEntry entry) => _base(entry) + 2;
  static int snooze(PrayerEntry entry) => _base(entry) + 3;
  static int soft(PrayerEntry entry) => _base(entry) + 4;

  static int _base(PrayerEntry entry) {
    final String compact = entry.localDate.replaceAll('-', '');
    final int date = int.tryParse(compact.substring(2)) ?? 0;
    return date * 100 + entry.type.index * 10;
  }
}
