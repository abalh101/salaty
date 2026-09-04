import 'package:salah_focus/features/prayer_times/domain/prayer_settings.dart';
import 'package:salah_focus/features/prayer_times/domain/user_location.dart';

class RemotePrayerDay {
  const RemotePrayerDay({
    required this.localDate,
    required this.timezoneId,
    required this.timings,
    this.hijriDate,
  });

  final String localDate;
  final String timezoneId;
  final Map<String, String> timings;
  final String? hijriDate;
}

abstract interface class PrayerTimesProvider {
  Future<List<RemotePrayerDay>> fetchMonth({
    required int year,
    required int month,
    required UserLocation location,
    required PrayerSettings settings,
  });
}
