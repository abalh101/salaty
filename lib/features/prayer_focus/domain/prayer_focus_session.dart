class PrayerFocusSession {
  const PrayerFocusSession({
    required this.prayerEntryId,
    required this.startedAtUtc,
    required this.maximumEndAtUtc,
    this.isActive = true,
  });

  final String prayerEntryId;
  final DateTime startedAtUtc;
  final DateTime maximumEndAtUtc;
  final bool isActive;

  PrayerFocusSession end() => PrayerFocusSession(
        prayerEntryId: prayerEntryId,
        startedAtUtc: startedAtUtc,
        maximumEndAtUtc: maximumEndAtUtc,
        isActive: false,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'prayer_entry_id': prayerEntryId,
        'started_at_utc': startedAtUtc.toIso8601String(),
        'maximum_end_at_utc': maximumEndAtUtc.toIso8601String(),
        'is_active': isActive ? 1 : 0,
      };
}
