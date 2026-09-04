enum PrayerType {
  fajr,
  dhuhr,
  asr,
  maghrib,
  isha;

  String get apiKey => switch (this) {
        PrayerType.fajr => 'Fajr',
        PrayerType.dhuhr => 'Dhuhr',
        PrayerType.asr => 'Asr',
        PrayerType.maghrib => 'Maghrib',
        PrayerType.isha => 'Isha',
      };

  String localizedName(String languageCode) {
    const Map<String, Map<PrayerType, String>> values = {
      'de': {
        PrayerType.fajr: 'Fajr',
        PrayerType.dhuhr: 'Dhuhr',
        PrayerType.asr: 'Asr',
        PrayerType.maghrib: 'Maghrib',
        PrayerType.isha: 'Isha',
      },
      'en': {
        PrayerType.fajr: 'Fajr',
        PrayerType.dhuhr: 'Dhuhr',
        PrayerType.asr: 'Asr',
        PrayerType.maghrib: 'Maghrib',
        PrayerType.isha: 'Isha',
      },
      'ar': {
        PrayerType.fajr: 'الفجر',
        PrayerType.dhuhr: 'الظهر',
        PrayerType.asr: 'العصر',
        PrayerType.maghrib: 'المغرب',
        PrayerType.isha: 'العشاء',
      },
    };
    return values[languageCode]?[this] ?? values['en']![this]!;
  }
}
