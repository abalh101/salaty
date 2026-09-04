import 'package:dio/dio.dart';
import 'package:salah_focus/core/api/api_client.dart';
import 'package:salah_focus/core/errors/app_exception.dart';
import 'package:salah_focus/features/prayer_times/data/prayer_times_provider.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_settings.dart';
import 'package:salah_focus/features/prayer_times/domain/user_location.dart';

class AlAdhanPrayerTimesProvider implements PrayerTimesProvider {
  AlAdhanPrayerTimesProvider(this._client);

  final ApiClient _client;

  @override
  Future<List<RemotePrayerDay>> fetchMonth({
    required int year,
    required int month,
    required UserLocation location,
    required PrayerSettings settings,
  }) async {
    try {
      final Response<Object?> response = await _client.dio.get<Object?>(
        '/calendar/$year/$month',
        queryParameters: <String, Object?>{
          'latitude': location.latitude,
          'longitude': location.longitude,
          'method': settings.calculationMethodId,
          'school': settings.apiSchool,
          'latitudeAdjustmentMethod': settings.apiLatitudeAdjustmentMethod,
        },
      );
      final Map<String, Object?> root = _map(response.data, 'root');
      final Object? rawData = root['data'];
      if (rawData is! List<Object?>) {
        throw const PrayerDataException('Prayer API returned no calendar data.');
      }
      final List<RemotePrayerDay> days = <RemotePrayerDay>[];
      for (final Object? item in rawData) {
        final Map<String, Object?> day = _map(item, 'day');
        final Map<String, Object?> date = _map(day['date'], 'date');
        final Map<String, Object?> gregorian =
            _map(date['gregorian'], 'gregorian');
        final String rawDate = gregorian['date']! as String;
        final List<String> dmy = rawDate.split('-');
        if (dmy.length != 3) {
          continue;
        }
        final String localDate = '${dmy[2]}-${dmy[1]}-${dmy[0]}';
        final Map<String, Object?> meta = _map(day['meta'], 'meta');
        final String timezoneId =
            (meta['timezone'] as String?) ?? location.timezoneId;
        final Map<String, Object?> rawTimings =
            _map(day['timings'], 'timings');
        final Map<String, String> timings = <String, String>{};
        for (final MapEntry<String, Object?> entry in rawTimings.entries) {
          if (entry.value is String) {
            timings[entry.key] = entry.value! as String;
          }
        }
        String? hijriDate;
        final Object? rawHijri = date['hijri'];
        if (rawHijri is Map) {
          final Map<String, Object?> hijri =
              Map<String, Object?>.from(rawHijri);
          final String? dayPart = hijri['day'] as String?;
          final Map<String, Object?>? monthMap = hijri['month'] is Map
              ? Map<String, Object?>.from(hijri['month']! as Map)
              : null;
          final String? monthName = monthMap?['en'] as String?;
          final String? yearPart = hijri['year'] as String?;
          if (dayPart != null && monthName != null && yearPart != null) {
            hijriDate = '$dayPart $monthName $yearPart';
          }
        }
        days.add(
          RemotePrayerDay(
            localDate: localDate,
            timezoneId: timezoneId,
            timings: timings,
            hijriDate: hijriDate,
          ),
        );
      }
      if (days.isEmpty) {
        throw const PrayerDataException('Prayer API calendar was empty.');
      }
      return days;
    } on DioException catch (error) {
      throw NetworkException(
        'Prayer times could not be downloaded. Cached data will be used.',
        cause: error,
      );
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw PrayerDataException(
        'Prayer API returned unexpected data.',
        cause: error,
      );
    }
  }

  static Map<String, Object?> _map(Object? value, String name) {
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    throw PrayerDataException('Invalid $name object from Prayer API.');
  }
}
