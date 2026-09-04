import 'dart:convert';

import 'package:salah_focus/features/prayer_times/domain/prayer_settings.dart';
import 'package:salah_focus/features/prayer_times/domain/user_location.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  const AppPreferences({
    required this.prayerSettings,
    required this.localeCode,
    required this.themeMode,
    required this.onboardingComplete,
    this.location,
  });

  final PrayerSettings prayerSettings;
  final UserLocation? location;
  final String localeCode;
  final String themeMode;
  final bool onboardingComplete;

  AppPreferences copyWith({
    PrayerSettings? prayerSettings,
    UserLocation? location,
    bool clearLocation = false,
    String? localeCode,
    String? themeMode,
    bool? onboardingComplete,
  }) {
    return AppPreferences(
      prayerSettings: prayerSettings ?? this.prayerSettings,
      location: clearLocation ? null : location ?? this.location,
      localeCode: localeCode ?? this.localeCode,
      themeMode: themeMode ?? this.themeMode,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }
}

class SettingsRepository {
  static const String _prayerSettingsKey = 'prayer_settings_v1';
  static const String _locationKey = 'user_location_v1';
  static const String _localeKey = 'locale_code';
  static const String _themeKey = 'theme_mode';
  static const String _onboardingKey = 'onboarding_complete';

  Future<AppPreferences> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    PrayerSettings prayerSettings = const PrayerSettings();
    final String? settingsJson = prefs.getString(_prayerSettingsKey);
    if (settingsJson != null) {
      try {
        final Object? decoded = jsonDecode(settingsJson);
        if (decoded is Map) {
          prayerSettings = PrayerSettings.fromJson(
            Map<String, Object?>.from(decoded),
          );
        }
      } on Object {
        // Stored preferences must never prevent the app from starting after an
        // update or a partially corrupted write.
        prayerSettings = const PrayerSettings();
      }
    }

    UserLocation? location;
    final String? locationJson = prefs.getString(_locationKey);
    if (locationJson != null) {
      try {
        final Object? decoded = jsonDecode(locationJson);
        if (decoded is Map) {
          location = UserLocation.fromJson(
            Map<String, Object?>.from(decoded),
          );
        }
      } on Object {
        location = null;
      }
    }

    final String storedLocale = prefs.getString(_localeKey) ?? 'de';
    final String storedTheme = prefs.getString(_themeKey) ?? 'system';
    return AppPreferences(
      prayerSettings: prayerSettings,
      location: location,
      localeCode: <String>{'de', 'en', 'ar'}.contains(storedLocale)
          ? storedLocale
          : 'de',
      themeMode: <String>{'system', 'light', 'dark'}.contains(storedTheme)
          ? storedTheme
          : 'system',
      onboardingComplete: prefs.getBool(_onboardingKey) ?? false,
    );
  }

  Future<void> savePrayerSettings(PrayerSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prayerSettingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> saveLocation(UserLocation location) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationKey, jsonEncode(location.toJson()));
  }

  Future<void> saveLocale(String localeCode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, localeCode);
  }

  Future<void> saveThemeMode(String mode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }

  Future<void> markOnboardingComplete() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }
}
