import 'package:salah_focus/features/prayer_times/domain/prayer_status.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_type.dart';

class PrayerEntry {
  const PrayerEntry({
    required this.id,
    required this.localDate,
    required this.type,
    required this.scheduledAtUtc,
    required this.timezoneId,
    required this.graceEndsAtUtc,
    required this.trackingEndsAtUtc,
    required this.status,
    this.confirmedAtUtc,
    this.snoozedUntilUtc,
    this.snoozeCount = 0,
    this.manualOffsetMinutes = 0,
  });

  final String id;
  final String localDate;
  final PrayerType type;
  final DateTime scheduledAtUtc;
  final String timezoneId;
  final DateTime graceEndsAtUtc;
  final DateTime trackingEndsAtUtc;
  final PrayerStatus status;
  final DateTime? confirmedAtUtc;
  final DateTime? snoozedUntilUtc;
  final int snoozeCount;
  final int manualOffsetMinutes;

  PrayerEntry copyWith({
    DateTime? scheduledAtUtc,
    String? timezoneId,
    DateTime? graceEndsAtUtc,
    DateTime? trackingEndsAtUtc,
    PrayerStatus? status,
    DateTime? confirmedAtUtc,
    bool clearConfirmedAt = false,
    DateTime? snoozedUntilUtc,
    bool clearSnoozedUntil = false,
    int? snoozeCount,
    int? manualOffsetMinutes,
  }) {
    return PrayerEntry(
      id: id,
      localDate: localDate,
      type: type,
      scheduledAtUtc: scheduledAtUtc ?? this.scheduledAtUtc,
      timezoneId: timezoneId ?? this.timezoneId,
      graceEndsAtUtc: graceEndsAtUtc ?? this.graceEndsAtUtc,
      trackingEndsAtUtc: trackingEndsAtUtc ?? this.trackingEndsAtUtc,
      status: status ?? this.status,
      confirmedAtUtc:
          clearConfirmedAt ? null : confirmedAtUtc ?? this.confirmedAtUtc,
      snoozedUntilUtc:
          clearSnoozedUntil ? null : snoozedUntilUtc ?? this.snoozedUntilUtc,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      manualOffsetMinutes: manualOffsetMinutes ?? this.manualOffsetMinutes,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'local_date': localDate,
        'type': type.name,
        'scheduled_at_utc': scheduledAtUtc.toIso8601String(),
        'timezone_id': timezoneId,
        'grace_ends_at_utc': graceEndsAtUtc.toIso8601String(),
        'tracking_ends_at_utc': trackingEndsAtUtc.toIso8601String(),
        'status': status.name,
        'confirmed_at_utc': confirmedAtUtc?.toIso8601String(),
        'snoozed_until_utc': snoozedUntilUtc?.toIso8601String(),
        'snooze_count': snoozeCount,
        'manual_offset_minutes': manualOffsetMinutes,
      };

  factory PrayerEntry.fromMap(Map<String, Object?> map) {
    return PrayerEntry(
      id: map['id']! as String,
      localDate: map['local_date']! as String,
      type: PrayerType.values.byName(map['type']! as String),
      scheduledAtUtc: DateTime.parse(map['scheduled_at_utc']! as String).toUtc(),
      timezoneId: map['timezone_id']! as String,
      graceEndsAtUtc:
          DateTime.parse(map['grace_ends_at_utc']! as String).toUtc(),
      trackingEndsAtUtc:
          DateTime.parse(map['tracking_ends_at_utc']! as String).toUtc(),
      status: PrayerStatus.values.byName(map['status']! as String),
      confirmedAtUtc: map['confirmed_at_utc'] == null
          ? null
          : DateTime.parse(map['confirmed_at_utc']! as String).toUtc(),
      snoozedUntilUtc: map['snoozed_until_utc'] == null
          ? null
          : DateTime.parse(map['snoozed_until_utc']! as String).toUtc(),
      snoozeCount: (map['snooze_count'] as int?) ?? 0,
      manualOffsetMinutes: (map['manual_offset_minutes'] as int?) ?? 0,
    );
  }
}
