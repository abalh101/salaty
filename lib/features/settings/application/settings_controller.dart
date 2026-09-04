import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_settings.dart';
import 'package:salah_focus/features/prayer_times/domain/user_location.dart';
import 'package:salah_focus/features/settings/data/settings_repository.dart';

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((Ref ref) => SettingsRepository());

final Provider<AppPreferences> initialPreferencesProvider =
    Provider<AppPreferences>(
  (Ref ref) => const AppPreferences(
    prayerSettings: PrayerSettings(),
    localeCode: 'de',
    themeMode: 'system',
    onboardingComplete: false,
  ),
);

final NotifierProvider<SettingsController, AppPreferences>
    settingsControllerProvider =
    NotifierProvider<SettingsController, AppPreferences>(SettingsController.new);

class SettingsController extends Notifier<AppPreferences> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  AppPreferences build() => ref.read(initialPreferencesProvider);

  Future<void> setLocation(UserLocation location) async {
    state = state.copyWith(location: location);
    await _repository.saveLocation(location);
  }

  Future<void> setPrayerSettings(PrayerSettings settings) async {
    state = state.copyWith(prayerSettings: settings);
    await _repository.savePrayerSettings(settings);
  }

  Future<void> setLocale(String localeCode) async {
    state = state.copyWith(localeCode: localeCode);
    await _repository.saveLocale(localeCode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode.name);
    await _repository.saveThemeMode(mode.name);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingComplete: true);
    await _repository.markOnboardingComplete();
  }

  ThemeMode get themeMode => switch (state.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
