import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salah_focus/app/app.dart';
import 'package:salah_focus/app/app_providers.dart';
import 'package:salah_focus/core/time/timezone_service.dart';
import 'package:salah_focus/features/settings/application/settings_controller.dart';
import 'package:salah_focus/features/settings/data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final String timezoneId = await TimezoneService.initialize();
  final SettingsRepository settingsRepository = SettingsRepository();
  final AppPreferences preferences = await settingsRepository.load();

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        initialPreferencesProvider.overrideWithValue(preferences),
        deviceTimezoneIdProvider.overrideWithValue(timezoneId),
      ],
      child: const SalahFocusApp(),
    ),
  );
}
