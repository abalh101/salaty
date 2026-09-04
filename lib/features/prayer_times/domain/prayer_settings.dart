import 'package:salah_focus/features/prayer_times/domain/prayer_type.dart';

enum AsrMadhhab { standard, hanafi }

enum HighLatitudeRule { middleOfNight, oneSeventh, angleBased }

class PrayerSettings {
  const PrayerSettings({
    this.calculationMethodId = 3,
    this.madhhab = AsrMadhhab.standard,
    this.highLatitudeRule = HighLatitudeRule.angleBased,
    this.gracePeriodMinutes = 60,
    this.snoozeMinutes = 20,
    this.maxSnoozes = 2,
    this.focusEnabled = true,
    this.softReminderAfterSkip = true,
    this.confirmationText = 'Wallah, ich habe gebetet',
    this.adjustments = const <PrayerType, int>{},
  });

  final int calculationMethodId;
  final AsrMadhhab madhhab;
  final HighLatitudeRule highLatitudeRule;
  final int gracePeriodMinutes;
  final int snoozeMinutes;
  final int? maxSnoozes;
  final bool focusEnabled;
  final bool softReminderAfterSkip;
  final String confirmationText;
  final Map<PrayerType, int> adjustments;

  int adjustmentFor(PrayerType type) {
    final int value = adjustments[type] ?? 0;
    if (value < -60) return -60;
    if (value > 60) return 60;
    return value;
  }

  PrayerSettings copyWith({
    int? calculationMethodId,
    AsrMadhhab? madhhab,
    HighLatitudeRule? highLatitudeRule,
    int? gracePeriodMinutes,
    int? snoozeMinutes,
    int? maxSnoozes,
    bool clearMaxSnoozes = false,
    bool? focusEnabled,
    bool? softReminderAfterSkip,
    String? confirmationText,
    Map<PrayerType, int>? adjustments,
  }) {
    return PrayerSettings(
      calculationMethodId: calculationMethodId ?? this.calculationMethodId,
      madhhab: madhhab ?? this.madhhab,
      highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      maxSnoozes: clearMaxSnoozes ? null : maxSnoozes ?? this.maxSnoozes,
      focusEnabled: focusEnabled ?? this.focusEnabled,
      softReminderAfterSkip:
          softReminderAfterSkip ?? this.softReminderAfterSkip,
      confirmationText: confirmationText ?? this.confirmationText,
      adjustments: adjustments ?? this.adjustments,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'calculationMethodId': calculationMethodId,
        'madhhab': madhhab.name,
        'highLatitudeRule': highLatitudeRule.name,
        'gracePeriodMinutes': gracePeriodMinutes,
        'snoozeMinutes': snoozeMinutes,
        'maxSnoozes': maxSnoozes,
        'focusEnabled': focusEnabled,
        'softReminderAfterSkip': softReminderAfterSkip,
        'confirmationText': confirmationText,
        'adjustments': <String, int>{
          for (final PrayerType type in PrayerType.values)
            type.name: adjustmentFor(type),
        },
      };

  factory PrayerSettings.fromJson(Map<String, Object?> json) {
    final Object? rawAdjustments = json['adjustments'];
    final Map<PrayerType, int> adjustments = <PrayerType, int>{};
    if (rawAdjustments is Map) {
      for (final MapEntry<Object?, Object?> entry in rawAdjustments.entries) {
        if (entry.key is String && entry.value is num) {
          try {
            adjustments[PrayerType.values.byName(entry.key! as String)] =
                (entry.value! as num).toInt();
          } on ArgumentError {
            // Ignore unknown prayer keys from future app versions.
          }
        }
      }
    }
    final int rawMethod = (json['calculationMethodId'] as num?)?.toInt() ?? 3;
    final int rawGrace = (json['gracePeriodMinutes'] as num?)?.toInt() ?? 60;
    final int rawSnooze = (json['snoozeMinutes'] as num?)?.toInt() ?? 20;
    final int? rawMaxSnoozes = (json['maxSnoozes'] as num?)?.toInt();
    final String rawConfirmation =
        ((json['confirmationText'] as String?) ?? 'Wallah, ich habe gebetet')
            .trim();
    return PrayerSettings(
      calculationMethodId: <int>{1, 2, 3, 4, 5, 13}.contains(rawMethod)
          ? rawMethod
          : 3,
      madhhab: _parseMadhhab(json['madhhab']),
      highLatitudeRule: _parseHighLatitudeRule(json['highLatitudeRule']),
      gracePeriodMinutes: _clampInt(rawGrace, 0, 120),
      snoozeMinutes: _clampInt(rawSnooze, 5, 30),
      maxSnoozes: rawMaxSnoozes == null
          ? null
          : _clampInt(rawMaxSnoozes, 1, 5),
      focusEnabled: (json['focusEnabled'] as bool?) ?? true,
      softReminderAfterSkip:
          (json['softReminderAfterSkip'] as bool?) ?? true,
      confirmationText: rawConfirmation.isEmpty
          ? 'Wallah, ich habe gebetet'
          : rawConfirmation.substring(
              0,
              rawConfirmation.length > 80 ? 80 : rawConfirmation.length,
            ),
      adjustments: adjustments,
    );
  }

  static int _clampInt(int value, int minimum, int maximum) {
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
  }

  static AsrMadhhab _parseMadhhab(Object? value) {
    for (final AsrMadhhab item in AsrMadhhab.values) {
      if (item.name == value) return item;
    }
    return AsrMadhhab.standard;
  }

  static HighLatitudeRule _parseHighLatitudeRule(Object? value) {
    for (final HighLatitudeRule item in HighLatitudeRule.values) {
      if (item.name == value) return item;
    }
    return HighLatitudeRule.angleBased;
  }

  int get apiSchool => madhhab == AsrMadhhab.hanafi ? 1 : 0;

  int get apiLatitudeAdjustmentMethod => switch (highLatitudeRule) {
        HighLatitudeRule.middleOfNight => 1,
        HighLatitudeRule.oneSeventh => 2,
        HighLatitudeRule.angleBased => 3,
      };
}
