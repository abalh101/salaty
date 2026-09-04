import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class TimezoneService {
  TimezoneService._();

  static bool _initialized = false;

  static Future<String> initialize() async {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
    try {
      final dynamic rawTimezone = await FlutterTimezone.getLocalTimezone();
      final String timezoneId = rawTimezone is String ? rawTimezone : rawTimezone.name as String;
      final tz.Location location = tz.getLocation(timezoneId);
      tz.setLocalLocation(location);
      return timezoneId;
    } on Object {
      tz.setLocalLocation(tz.UTC);
      return 'UTC';
    }
  }

  static tz.Location locationOrUtc(String timezoneId) {
    try {
      return tz.getLocation(timezoneId);
    } on Object {
      return tz.UTC;
    }
  }

  static DateTime localPartsToUtc({
    required String dateIso,
    required String hhmm,
    required String timezoneId,
  }) {
    final List<String> dateParts = dateIso.split('-');
    if (dateParts.length != 3) {
      throw const FormatException('Invalid ISO date.');
    }
    final RegExpMatch? timeMatch =
        RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm.trim());
    if (timeMatch == null) {
      throw FormatException('Invalid prayer time: $hhmm');
    }
    final tz.Location location = locationOrUtc(timezoneId);
    final tz.TZDateTime local = tz.TZDateTime(
      location,
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(timeMatch.group(1)!),
      int.parse(timeMatch.group(2)!),
    );
    return local.toUtc();
  }

  static tz.TZDateTime toLocal(DateTime utc, String timezoneId) {
    return tz.TZDateTime.from(utc.toUtc(), locationOrUtc(timezoneId));
  }

  static String isoLocalDate(DateTime instantUtc, String timezoneId) {
    final tz.TZDateTime local = toLocal(instantUtc, timezoneId);
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
