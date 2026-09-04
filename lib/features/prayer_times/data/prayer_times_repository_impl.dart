import 'package:salah_focus/core/database/app_database.dart';
import 'package:salah_focus/core/errors/app_exception.dart';
import 'package:salah_focus/core/time/timezone_service.dart';
import 'package:salah_focus/features/prayer_times/data/prayer_cache_key.dart';
import 'package:salah_focus/features/prayer_times/data/prayer_times_provider.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_day.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_settings.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_status.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_type.dart';
import 'package:salah_focus/features/prayer_times/domain/user_location.dart';

class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  PrayerTimesRepositoryImpl(this._database, this._provider);

  final AppDatabase _database;
  final PrayerTimesProvider _provider;

  @override
  Future<PrayerDay?> day(String localDate) async {
    final List<PrayerEntry> entries =
        await _database.prayerEntriesForDate(localDate);
    if (entries.isEmpty) {
      return null;
    }
    final PrayerDayMeta? meta = await _database.dayMeta(localDate);
    return PrayerDay(
      localDate: localDate,
      timezoneId: meta?.timezoneId ?? entries.first.timezoneId,
      entries: entries,
      hijriDate: meta?.hijriDate,
      sunriseUtc: meta?.sunriseUtc,
    );
  }

  @override
  Future<List<PrayerEntry>> entriesBetween(
    String startDate,
    String endDate,
  ) => _database.prayerEntriesBetween(startDate, endDate);

  @override
  Future<bool> hasCachedMonth(
    int year,
    int month, {
    required UserLocation location,
    required PrayerSettings settings,
  }) =>
      _database.hasMonth(year, month, PrayerCacheKey.build(location, settings));

  @override
  Future<void> refreshMonth({
    required int year,
    required int month,
    required UserLocation location,
    required PrayerSettings settings,
  }) async {
    final String sourceKey = PrayerCacheKey.build(location, settings);
    final List<RemotePrayerDay> remote = await _provider.fetchMonth(
      year: year,
      month: month,
      location: location,
      settings: settings,
    );

    final List<List<_ScheduledPrayer>> scheduledDays = <List<_ScheduledPrayer>>[];
    for (final RemotePrayerDay day in remote) {
      final List<_ScheduledPrayer> scheduled = <_ScheduledPrayer>[];
      for (final PrayerType type in PrayerType.values) {
        final String? hhmm = day.timings[type.apiKey];
        if (hhmm == null) {
          continue;
        }
        final int adjustment = settings.adjustmentFor(type);
        final DateTime instant = TimezoneService.localPartsToUtc(
          dateIso: day.localDate,
          hhmm: hhmm,
          timezoneId: day.timezoneId,
        ).add(Duration(minutes: adjustment));
        scheduled.add(
          _ScheduledPrayer(
            type: type,
            instantUtc: instant,
            adjustment: adjustment,
          ),
        );
      }
      if (scheduled.length != PrayerType.values.length) {
        throw PrayerDataException(
          'Prayer API did not provide all five required prayer times for ${day.localDate}.',
        );
      }
      for (int i = 1; i < scheduled.length; i++) {
        if (!scheduled[i].instantUtc.isAfter(scheduled[i - 1].instantUtc)) {
          throw PrayerDataException(
            'Adjusted prayer times are not chronological for ${day.localDate}.',
          );
        }
      }
      scheduledDays.add(scheduled);
    }

    for (int dayIndex = 0; dayIndex < remote.length; dayIndex++) {
      final RemotePrayerDay day = remote[dayIndex];
      final List<_ScheduledPrayer> scheduled = scheduledDays[dayIndex];
      final List<PrayerEntry> entries = <PrayerEntry>[];
      for (int i = 0; i < scheduled.length; i++) {
        final _ScheduledPrayer current = scheduled[i];
        DateTime trackingEnd;
        if (i + 1 < scheduled.length) {
          trackingEnd = scheduled[i + 1].instantUtc;
        } else if (dayIndex + 1 < scheduledDays.length &&
            scheduledDays[dayIndex + 1].isNotEmpty) {
          trackingEnd = scheduledDays[dayIndex + 1].first.instantUtc;
        } else {
          trackingEnd = current.instantUtc.add(const Duration(hours: 12));
        }
        final DateTime rawGrace = current.instantUtc.add(
          Duration(minutes: settings.gracePeriodMinutes),
        );
        final DateTime latestGrace =
            trackingEnd.subtract(const Duration(minutes: 1));
        final DateTime graceEnd = rawGrace.isBefore(latestGrace)
            ? rawGrace
            : latestGrace;
        entries.add(
          PrayerEntry(
            id: '${day.localDate}:${current.type.name}',
            localDate: day.localDate,
            type: current.type,
            scheduledAtUtc: current.instantUtc,
            timezoneId: day.timezoneId,
            graceEndsAtUtc: graceEnd,
            trackingEndsAtUtc: trackingEnd,
            status: PrayerStatus.upcoming,
            manualOffsetMinutes: current.adjustment,
          ),
        );
      }
      await _database.upsertPrayerEntries(entries);
      DateTime? sunriseUtc;
      final String? sunrise = day.timings['Sunrise'];
      if (sunrise != null) {
        try {
          sunriseUtc = TimezoneService.localPartsToUtc(
            dateIso: day.localDate,
            hhmm: sunrise,
            timezoneId: day.timezoneId,
          );
        } on FormatException {
          sunriseUtc = null;
        }
      }
      await _database.upsertDayMeta(
        localDate: day.localDate,
        timezoneId: day.timezoneId,
        hijriDate: day.hijriDate,
        sunriseUtc: sunriseUtc,
        sourceKey: sourceKey,
      );
    }

    // A monthly API response cannot know the following month's Fajr while it
    // builds the final Isha entry. Whenever adjacent months are present, repair
    // that boundary so Isha ends at the actual next Fajr instead of the safe
    // temporary fallback window.
    if (remote.isNotEmpty) {
      final String firstDate = remote.first.localDate;
      final String lastDate = remote.last.localDate;
      await _linkDayToNext(
        _shiftIsoDate(firstDate, -1),
        settings: settings,
        sourceKey: sourceKey,
      );
      await _linkDayToNext(
        lastDate,
        settings: settings,
        sourceKey: sourceKey,
      );
    }
  }

  Future<void> _linkDayToNext(
    String localDate, {
    required PrayerSettings settings,
    required String sourceKey,
  }) async {
    final String nextDate = _shiftIsoDate(localDate, 1);
    final PrayerDayMeta? currentMeta = await _database.dayMeta(localDate);
    final PrayerDayMeta? nextMeta = await _database.dayMeta(nextDate);
    if (currentMeta?.sourceKey != sourceKey || nextMeta?.sourceKey != sourceKey) {
      return;
    }
    final PrayerEntry? isha = await _database.prayerEntryById(
      '$localDate:${PrayerType.isha.name}',
    );
    final PrayerEntry? fajr = await _database.prayerEntryById(
      '$nextDate:${PrayerType.fajr.name}',
    );
    if (isha == null ||
        fajr == null ||
        !fajr.scheduledAtUtc.isAfter(isha.scheduledAtUtc)) {
      return;
    }

    final DateTime latestGrace =
        fajr.scheduledAtUtc.subtract(const Duration(minutes: 1));
    final DateTime requestedGrace = isha.scheduledAtUtc.add(
      Duration(minutes: settings.gracePeriodMinutes),
    );
    final DateTime graceEnd = requestedGrace.isBefore(latestGrace)
        ? requestedGrace
        : latestGrace;

    PrayerStatus status = isha.status;
    bool clearSnooze = false;
    final DateTime? snoozedUntil = isha.snoozedUntilUtc;
    if (status == PrayerStatus.snoozed &&
        snoozedUntil != null &&
        !snoozedUntil.isBefore(fajr.scheduledAtUtc)) {
      status = PrayerStatus.upcoming;
      clearSnooze = true;
    }

    await _database.upsertPrayerEntry(
      isha.copyWith(
        graceEndsAtUtc: graceEnd,
        trackingEndsAtUtc: fajr.scheduledAtUtc,
        status: status,
        clearSnoozedUntil: clearSnooze,
      ),
    );
  }

  static String _shiftIsoDate(String localDate, int days) {
    final List<int> parts = localDate.split('-').map(int.parse).toList();
    if (parts.length != 3) {
      throw FormatException('Invalid local date: $localDate');
    }
    final DateTime shifted =
        DateTime.utc(parts[0], parts[1], parts[2]).add(Duration(days: days));
    return '${shifted.year.toString().padLeft(4, '0')}-'
        '${shifted.month.toString().padLeft(2, '0')}-'
        '${shifted.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<void> saveEntry(PrayerEntry entry) => _database.upsertPrayerEntry(entry);
}

class _ScheduledPrayer {
  const _ScheduledPrayer({
    required this.type,
    required this.instantUtc,
    required this.adjustment,
  });

  final PrayerType type;
  final DateTime instantUtc;
  final int adjustment;
}
