import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salah_focus/app/app_providers.dart';
import 'package:salah_focus/app/localization/app_strings.dart';
import 'package:salah_focus/app/router/app_router.dart';
import 'package:salah_focus/core/theme/app_theme.dart';
import 'package:salah_focus/features/settings/application/settings_controller.dart';

class SalahFocusApp extends ConsumerStatefulWidget {
  const SalahFocusApp({super.key});

  @override
  ConsumerState<SalahFocusApp> createState() => _SalahFocusAppState();
}

class _SalahFocusAppState extends ConsumerState<SalahFocusApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleLaunchPayload());
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(settingsControllerProvider);
    final GoRouter router = ref.watch(goRouterProvider);
    ref.listen<AsyncValue<String>>(notificationPayloadProvider, (_, AsyncValue<String> next) {
      next.whenData((String payload) => _routePayload(router, payload));
    });

    final ThemeMode themeMode = switch (preferences.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppStrings.of(context).t('appName'),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: Locale(preferences.localeCode),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }

  Future<void> _handleLaunchPayload() async {
    final service = ref.read(notificationServiceProvider);
    final String? payload = await service.takeInitialPayload();
    if (!mounted || payload == null) return;
    _routePayload(ref.read(goRouterProvider), payload);
  }

  void _routePayload(GoRouter router, String payload) {
    if (payload.startsWith('focus:')) {
      final String prayerId = payload.substring('focus:'.length);
      if (prayerId.isNotEmpty) {
        router.go('/focus/${Uri.encodeComponent(prayerId)}');
        return;
      }
    }
    router.go('/home');
  }
}
