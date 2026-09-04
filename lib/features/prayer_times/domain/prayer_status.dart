enum PrayerStatus {
  upcoming,
  active,
  pending,
  snoozed,
  prayed,
  skipped,
  missed;

  bool get isFinal => this == prayed || this == skipped || this == missed;
}
