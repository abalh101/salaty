import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salah_focus/core/api/api_client.dart';
import 'package:salah_focus/core/database/app_database.dart';
import 'package:salah_focus/core/location/location_service.dart';
import 'package:salah_focus/core/location/location_service_impl.dart';
import 'package:salah_focus/core/notifications/local_notification_service.dart';
import 'package:salah_focus/core/notifications/notification_service.dart';
import 'package:salah_focus/core/time/clock_service.dart';
import 'package:salah_focus/features/prayer_focus/data/platform_prayer_focus_service.dart';
import 'package:salah_focus/features/prayer_focus/domain/prayer_focus_service.dart';
import 'package:salah_focus/features/prayer_times/application/prayer_coordinator.dart';
import 'package:salah_focus/features/prayer_times/data/aladhan_prayer_times_provider.dart';
import 'package:salah_focus/features/prayer_times/data/prayer_times_provider.dart';
import 'package:salah_focus/features/prayer_times/data/prayer_times_repository_impl.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_day.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:salah_focus/features/settings/application/settings_controller.dart';

final Provider<String> deviceTimezoneIdProvider =
    Provider<String>((Ref ref) => 'UTC');

final Provider<AppDatabase> appDatabaseProvider =
    Provider<AppDatabase>((Ref ref) => AppDatabase());

final Provider<ApiClient> apiClientProvider =
    Provider<ApiClient>((Ref ref) => ApiClient());

final Provider<PrayerTimesProvider> prayerTimesProvider =
    Provider<PrayerTimesProvider>(
  (Ref ref) => AlAdhanPrayerTimesProvider(ref.watch(apiClientProvider)),
);

final Provider<PrayerTimesRepository> prayerTimesRepositoryProvider =
    Provider<PrayerTimesRepository>(
  (Ref ref) => PrayerTimesRepositoryImpl(
    ref.watch(appDatabaseProvider),
    ref.watch(prayerTimesProvider),
  ),
);

final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>((Ref ref) => LocationServiceImpl());

final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>((Ref ref) => LocalNotificationService());


final notificationPayloadProvider = StreamProvider<String>(
  (Ref ref) => ref.watch(notificationServiceProvider).payloads,
);

final Provider<PrayerFocusService> prayerFocusServiceProvider =
    Provider<PrayerFocusService>((Ref ref) => PlatformPrayerFocusService());

final Provider<ClockService> clockServiceProvider =
    Provider<ClockService>((Ref ref) => const SystemClockService());

final Provider<PrayerCoordinator> prayerCoordinatorProvider =
    Provider<PrayerCoordinator>(
  (Ref ref) => PrayerCoordinator(
    repository: ref.watch(prayerTimesRepositoryProvider),
    database: ref.watch(appDatabaseProvider),
    notifications: ref.watch(notificationServiceProvider),
    focusService: ref.watch(prayerFocusServiceProvider),
    clock: ref.watch(clockServiceProvider),
  ),
);

final FutureProvider<PrayerDay?> todayPrayerDayProvider =
    FutureProvider<PrayerDay?>((Ref ref) async {
  final prefs = ref.watch(settingsControllerProvider);
  final location = prefs.location;
  if (location == null) {
    return null;
  }
  return ref.watch(prayerCoordinatorProvider).loadToday(
        location: location,
        settings: prefs.prayerSettings,
        languageCode: prefs.localeCode,
      );
});

final prayerByIdProvider = FutureProvider.family<PrayerEntry?, String>(
  (Ref ref, String id) => ref.watch(prayerCoordinatorProvider).prayerById(id),
);
