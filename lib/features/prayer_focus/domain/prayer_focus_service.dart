class PrayerFocusCapabilities {
  const PrayerFocusCapabilities({
    required this.appShieldingSupported,
    required this.backgroundSchedulingSupported,
    required this.appSelectionSupported,
    this.reason,
  });

  final bool appShieldingSupported;
  final bool backgroundSchedulingSupported;
  final bool appSelectionSupported;
  final String? reason;
}

abstract interface class PrayerFocusService {
  Future<PrayerFocusCapabilities> capabilities();

  Future<bool> requestAuthorization();

  Future<bool> selectBlockedApps();

  Future<bool> startFocus({
    required DateTime maximumEndUtc,
  });

  Future<void> stopFocus();

  Future<void> scheduleFocus({
    required String identifier,
    required DateTime startUtc,
    required DateTime endUtc,
  });

  Future<void> cancelScheduledFocus(String identifier);

  /// Cancels every future native Prayer Focus schedule created by this app.
  Future<void> cancelAllScheduledFocus();
}
