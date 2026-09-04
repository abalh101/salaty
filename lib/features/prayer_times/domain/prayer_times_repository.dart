import 'package:salah_focus/features/prayer_times/domain/prayer_day.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_settings.dart';
import 'package:salah_focus/features/prayer_times/domain/user_location.dart';

abstract interface class PrayerTimesRepository {
  Future<PrayerDay?> day(String localDate);

  Future<List<PrayerEntry>> entriesBetween(String startDate, String endDate);

  Future<void> refreshMonth({
    required int year,
    required int month,
    required UserLocation location,
    required PrayerSettings settings,
  });

  Future<void> saveEntry(PrayerEntry entry);

  Future<bool> hasCachedMonth(
    int year,
    int month, {
    required UserLocation location,
    required PrayerSettings settings,
  });
}
