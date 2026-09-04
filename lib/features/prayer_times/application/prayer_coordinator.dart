import 'package:salah_focus/core/database/app_database.dart';
import 'package:salah_focus/core/notifications/notification_service.dart';
import 'package:salah_focus/core/notifications/prayer_notification_planner.dart';
import 'package:salah_focus/core/time/clock_service.dart';
import 'package:salah_focus/core/time/timezone_service.dart';
import 'package:salah_focus/features/prayer_focus/domain/prayer_focus_policy.dart';
import 'package:salah_focus/features/prayer_focus/domain/prayer_focus_service.dart';
import 'package:salah_focus/features/prayer_focus/domain/prayer_focus_session.dart';
import 'package:salah_focus/features/prayer_times/data/prayer_cache_key.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_day.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_settings.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_state_machine.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_status.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:salah_focus/features/prayer_times/domain/user_location.dart';

class PrayerCoordinator {
  PrayerCoordinator({
    required PrayerTimesRepository repository,
    required AppDatabase database,
    required NotificationService notifications,
    required PrayerFocusService focusService,
    required ClockService clock,
  })  : _repository = repository,
        _database = database,
        _notifications = notifications,
        _focusService = focusService,
        _clock = clock,
        _planner = PrayerNotificationPlanner(notifications);

  final PrayerTimesRepository _repository;
  final AppDatabase _database;
  final NotificationService _notifications;
  final PrayerFocusService _focusService;
  final ClockService _clock;
  final PrayerNotificationPlanner _planner;
  final PrayerStateMachine _stateMachine = const PrayerStateMachine();
  final PrayerFocusPolicy _focusPolicy = const PrayerFocusPolicy();
  final Set<String> _syncedKeys = <String>{};

  Future<PrayerDay?> loadToday({
    required UserLocation location,
    required PrayerSettings settings,
    required String languageCode,
  }) async {
    final DateTime nowUtc = _clock.nowUtc();

    // Fetch the UTC day and its immediate neighbours. This avoids assuming
    // that a manually selected city shares the device timezone.
    final DateTime utcDate = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final Set<String> months = <String>{};
    for (final int offset in <int>[-1, 0, 1]) {
      final DateTime candidate = utcDate.add(Duration(days: offset));
      final String key = '${candidate.year}-${candidate.month}';
      if (months.add(key)) {
        await _ensureMonth(
          year: candidate.year,
          month: candidate.month,
          location: location,
          settings: settings,
        );
      }
    }

    PrayerDay? day = await _resolveCurrentDay(nowUtc);
    if (day == null) {
      final DateTime deviceLocal =
          TimezoneService.toLocal(nowUtc, location.timezoneId);
      day = await _repository.day(_isoDate(deviceLocal));
    }
    if (day == null) return null;

    final DateTime localNow = TimezoneService.toLocal(nowUtc, day.timezoneId);
    final DateTime horizonLocal = localNow.add(const Duration(days: 4));
    if (horizonLocal.month != localNow.month ||
        horizonLocal.year != localNow.year) {
      await _ensureMonth(
        year: horizonLocal.year,
        month: horizonLocal.month,
        location: location,
        settings: settings,
      );
    }

    final List<PrayerEntry> advanced = <PrayerEntry>[];
    for (final PrayerEntry entry in day.entries) {
      final PrayerEntry next = _stateMachine.advance(entry, nowUtc);
      advanced.add(next);
      await _repository.saveEntry(next);
    }
    day = day.copyWith(entries: advanced);

    final String today = day.localDate;
    final String end = _isoDate(horizonLocal);
    final List<PrayerEntry> upcoming =
        await _repository.entriesBetween(today, end);
    await _planner.reschedule(
      upcoming,
      prayerName: (PrayerEntry entry) =>
          entry.type.localizedName(languageCode),
      languageCode: languageCode,
      nowUtc: nowUtc,
    );

    if (settings.focusEnabled) {
      // DeviceActivity can reject excessive/tightly packed monitoring. Keep
      // native shields on a conservative rolling window while notifications
      // remain planned farther ahead.
      final DateTime nativeFocusHorizon = nowUtc.add(const Duration(days: 2));
      await _focusService.cancelAllScheduledFocus();
      for (final PrayerEntry entry in upcoming) {
        if (entry.status.isFinal ||
            !entry.graceEndsAtUtc.isAfter(nowUtc) ||
            !entry.graceEndsAtUtc.isBefore(nativeFocusHorizon)) {
          continue;
        }
        final DateTime maximumEnd = _focusPolicy.maximumEnd(entry);
        if (maximumEnd.isAfter(entry.graceEndsAtUtc)) {
          await _focusService.scheduleFocus(
            identifier: entry.id,
            startUtc: entry.graceEndsAtUtc,
            endUtc: maximumEnd,
          );
        }
      }
    } else {
      // A disabled switch must also remove schedules created on an earlier
      // run. This is intentionally fail-open.
      await _focusService.stopFocus();
      await _focusService.cancelAllScheduledFocus();
      await _database.endAllFocusSessions();
    }
    return day;
  }

  Future<PrayerDay?> _resolveCurrentDay(DateTime nowUtc) async {
    final DateTime utcDate = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    for (final int offset in <int>[-1, 0, 1]) {
      final String candidate = _isoDate(utcDate.add(Duration(days: offset)));
      final PrayerDay? day = await _repository.day(candidate);
      if (day == null) continue;
      final DateTime local = TimezoneService.toLocal(nowUtc, day.timezoneId);
      if (_isoDate(local) == candidate) return day;
    }
    return null;
  }

  Future<void> _ensureMonth({
    required int year,
    required int month,
    required UserLocation location,
    required PrayerSettings settings,
  }) async {
    final String syncKey =
        '$year-$month|${PrayerCacheKey.build(location, settings)}';
    if (_syncedKeys.contains(syncKey)) {
      return;
    }
    final bool cached = await _repository.hasCachedMonth(
      year,
      month,
      location: location,
      settings: settings,
    );
    try {
      await _repository.refreshMonth(
        year: year,
        month: month,
        location: location,
        settings: settings,
      );
      _syncedKeys.add(syncKey);
    } on Object {
      if (!cached) {
        rethrow;
      }
      _syncedKeys.add(syncKey);
    }
  }

  Future<PrayerEntry?> prayerById(String id) async {
    final PrayerEntry? entry = await _database.prayerEntryById(id);
    if (entry == null) {
      return null;
    }
    final PrayerEntry advanced = _stateMachine.advance(entry, _clock.nowUtc());
    await _repository.saveEntry(advanced);
    return advanced;
  }

  Future<PrayerEntry> confirm(PrayerEntry prayer) async {
    final PrayerEntry updated =
        _stateMachine.confirm(prayer, _clock.nowUtc());
    await _repository.saveEntry(updated);
    await _database.clearFocusBypass(updated.id);
    await _notifications.cancelPrayer(updated);
    await _focusService.stopFocus();
    await _focusService.cancelScheduledFocus(updated.id);
    await _database.endAllFocusSessions();
    return updated;
  }

  Future<PrayerEntry> snooze(
    PrayerEntry prayer,
    PrayerSettings settings,
    String prayerName,
    String languageCode,
  ) async {
    final PrayerEntry updated = _stateMachine.snooze(
      prayer,
      _clock.nowUtc(),
      Duration(minutes: settings.snoozeMinutes),
      maximumSnoozes: settings.maxSnoozes,
    );
    await _repository.saveEntry(updated);
    await _database.clearFocusBypass(updated.id);
    await _notifications.cancelPrayer(prayer);
    await _notifications.scheduleSnoozeReminder(updated, prayerName, languageCode: languageCode);
    await _focusService.stopFocus();
    await _database.endAllFocusSessions();
    final DateTime? snoozedUntil = updated.snoozedUntilUtc;
    if (settings.focusEnabled && snoozedUntil != null) {
      final DateTime maximumEnd = _focusPolicy.maximumEnd(updated);
      if (maximumEnd.isAfter(snoozedUntil)) {
        await _focusService.scheduleFocus(
          identifier: updated.id,
          startUtc: snoozedUntil,
          endUtc: maximumEnd,
        );
      }
    }
    return updated;
  }

  Future<PrayerEntry> skip(
    PrayerEntry prayer,
    PrayerSettings settings,
    String prayerName,
    String languageCode,
  ) async {
    final PrayerEntry updated = _stateMachine.skip(prayer);
    await _repository.saveEntry(updated);
    await _database.clearFocusBypass(updated.id);
    await _notifications.cancelPrayer(prayer);
    if (settings.softReminderAfterSkip) {
      await _notifications.scheduleSoftReminder(updated, prayerName, languageCode: languageCode);
    }
    await _focusService.stopFocus();
    await _focusService.cancelScheduledFocus(updated.id);
    await _database.endAllFocusSessions();
    return updated;
  }

  Future<bool> shouldOpenFocus(PrayerEntry prayer) async {
    final DateTime now = _clock.nowUtc();
    if (prayer.status != PrayerStatus.pending || !now.isBefore(prayer.trackingEndsAtUtc)) {
      return false;
    }
    if (await _database.isFocusBypassed(prayer.id, now)) {
      return false;
    }
    final DateTime maximumEnd = _focusPolicy.maximumEnd(prayer);
    if (!now.isBefore(maximumEnd)) {
      await _focusService.stopFocus();
      await _focusService.cancelScheduledFocus(prayer.id);
      await _database.endAllFocusSessions();
      await _database.setFocusBypass(prayer.id, prayer.trackingEndsAtUtc);
      return false;
    }
    return true;
  }

  Future<void> startFocus(PrayerEntry prayer) async {
    final DateTime now = _clock.nowUtc();
    if (!await shouldOpenFocus(prayer)) {
      return;
    }
    final DateTime maximumEnd = _focusPolicy.maximumEnd(prayer);
    await _database.saveFocusSession(
      PrayerFocusSession(
        prayerEntryId: prayer.id,
        startedAtUtc: now,
        maximumEndAtUtc: maximumEnd,
      ),
    );
    await _focusService.startFocus(maximumEndUtc: maximumEnd);
  }

  Future<void> emergencyUnlock(PrayerEntry prayer) async {
    await _focusService.stopFocus();
    await _focusService.cancelScheduledFocus(prayer.id);
    await _database.endAllFocusSessions();
    await _database.setFocusBypass(prayer.id, prayer.trackingEndsAtUtc);
  }


  Future<void> disableFocus() async {
    await _focusService.stopFocus();
    await _focusService.cancelAllScheduledFocus();
    await _database.endAllFocusSessions();
  }

  Future<PrayerEntry?> focusCandidateForNow(PrayerDay today) async {
    final DateTime now = _clock.nowUtc();
    final DateTime localNow = TimezoneService.toLocal(now, today.timezoneId);
    final String previousDate = _isoDate(localNow.subtract(const Duration(days: 1)));
    final List<PrayerEntry> candidates = await _repository.entriesBetween(
      previousDate,
      today.localDate,
    );

    PrayerEntry? best;
    for (final PrayerEntry entry in candidates) {
      final PrayerEntry advanced = _stateMachine.advance(entry, now);
      await _repository.saveEntry(advanced);
      if (advanced.status != PrayerStatus.pending ||
          !now.isBefore(advanced.trackingEndsAtUtc) ||
          await _database.isFocusBypassed(advanced.id, now)) {
        continue;
      }
      if (best == null || advanced.scheduledAtUtc.isAfter(best.scheduledAtUtc)) {
        best = advanced;
      }
    }
    return best;
  }

  Future<List<PrayerEntry>> entriesBetween(String start, String end) async {
    final DateTime now = _clock.nowUtc();
    final List<PrayerEntry> entries = await _repository.entriesBetween(start, end);
    final List<PrayerEntry> advanced = <PrayerEntry>[];
    for (final PrayerEntry entry in entries) {
      final PrayerEntry next = _stateMachine.advance(entry, now);
      advanced.add(next);
      await _repository.saveEntry(next);
    }
    return advanced;
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
