import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:salah_focus/app/app_providers.dart';
import 'package:salah_focus/app/localization/app_strings.dart';
import 'package:salah_focus/core/location/location_service.dart';
import 'package:salah_focus/core/notifications/notification_service.dart';
import 'package:salah_focus/core/time/timezone_service.dart';
import 'package:salah_focus/features/prayer_focus/domain/prayer_focus_service.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_day.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_settings.dart';
import 'package:salah_focus/features/prayer_times/domain/user_location.dart';
import 'package:salah_focus/features/settings/application/settings_controller.dart';
import 'package:salah_focus/shared/errors/user_error_message.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;
  bool _working = false;
  PrayerFocusCapabilities? _focusCapabilities;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final prefs = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(s.t('appName')),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Center(child: Text('${_page + 1}/7')),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          LinearProgressIndicator(value: (_page + 1) / 7),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                _WelcomePage(onContinue: _next),
                _LocationPage(
                  location: prefs.location,
                  working: _working,
                  onAutomatic: _useAutomaticLocation,
                  onManual: _chooseManualLocation,
                ),
                _PrayerPreviewPage(
                  prayerDay: ref.watch(todayPrayerDayProvider),
                  onRefresh: () => ref.invalidate(todayPrayerDayProvider),
                ),
                _GracePage(
                  minutes: prefs.prayerSettings.gracePeriodMinutes,
                  onChanged: _setGracePeriod,
                ),
                _DistractionPage(
                  capabilities: _focusCapabilities,
                  working: _working,
                  onSelectApps: _selectApps,
                ),
                _FocusExplainPage(
                  capabilities: _focusCapabilities,
                  working: _working,
                  onEnable: _enableFocus,
                ),
                _PermissionsPage(
                  working: _working,
                  onNotifications: _requestNotifications,
                  onExactAlarms: _requestExactAlarms,
                  onFinish: _finish,
                ),
              ],
            ),
          ),
          if (_page > 0 && _page < 6)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                child: Row(
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: _working ? null : _back,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(s.t('back')),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _canContinue(prefs.location) && !_working
                          ? _next
                          : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(s.t('continue')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _canContinue(UserLocation? location) {
    if (_page == 1 || _page == 2) return location != null;
    return true;
  }

  void _next() {
    if (_page >= 6) return;
    setState(() => _page += 1);
    _pageController.animateToPage(
      _page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_page <= 0) return;
    setState(() => _page -= 1);
    _pageController.animateToPage(
      _page,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _useAutomaticLocation() async {
    await _run(() async {
      final LocationService service = ref.read(locationServiceProvider);
      final UserLocation location = await service.currentLocation(
        ref.read(deviceTimezoneIdProvider),
      );
      await ref.read(settingsControllerProvider.notifier).setLocation(location);
      ref.invalidate(todayPrayerDayProvider);
    });
  }

  Future<void> _chooseManualLocation() async {
    final AppStrings s = AppStrings.of(context);
    final TextEditingController city = TextEditingController();
    final TextEditingController country = TextEditingController();
    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(s.t('chooseCity')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: city,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: s.t('city')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: country,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: s.t('country')),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.t('save')),
          ),
        ],
      ),
    );
    if (submit != true || !mounted) {
      city.dispose();
      country.dispose();
      return;
    }
    final String cityValue = city.text.trim();
    final String countryValue = country.text.trim();
    city.dispose();
    country.dispose();
    if (cityValue.isEmpty || countryValue.isEmpty) return;

    await _run(() async {
      final UserLocation location = await ref.read(locationServiceProvider).geocodeManual(
            city: cityValue,
            country: countryValue,
            deviceTimezoneId: ref.read(deviceTimezoneIdProvider),
          );
      await ref.read(settingsControllerProvider.notifier).setLocation(location);
      ref.invalidate(todayPrayerDayProvider);
    });
  }

  Future<void> _setGracePeriod(int minutes) async {
    final PrayerSettings current = ref.read(settingsControllerProvider).prayerSettings;
    await ref
        .read(settingsControllerProvider.notifier)
        .setPrayerSettings(current.copyWith(gracePeriodMinutes: minutes));
    ref.invalidate(todayPrayerDayProvider);
  }

  Future<void> _selectApps() async {
    await _run(() async {
      final PrayerFocusService focus = ref.read(prayerFocusServiceProvider);
      _focusCapabilities ??= await focus.capabilities();
      if (_focusCapabilities!.appSelectionSupported) {
        final bool authorized = !_focusCapabilities!.appShieldingSupported ||
            await focus.requestAuthorization();
        if (authorized) {
          await focus.selectBlockedApps();
        }
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _enableFocus() async {
    await _run(() async {
      final PrayerFocusService focus = ref.read(prayerFocusServiceProvider);
      _focusCapabilities ??= await focus.capabilities();
      bool enabled = true;
      if (_focusCapabilities!.appShieldingSupported) {
        enabled = await focus.requestAuthorization();
      }
      final PrayerSettings current = ref.read(settingsControllerProvider).prayerSettings;
      await ref.read(settingsControllerProvider.notifier).setPrayerSettings(
            current.copyWith(focusEnabled: enabled),
          );
      if (mounted) setState(() {});
    });
  }

  Future<void> _requestNotifications() async {
    await _run(() async {
      final NotificationService service = ref.read(notificationServiceProvider);
      await service.initialize();
      await service.requestPermission();
    });
  }

  Future<void> _requestExactAlarms() async {
    await _run(() async {
      final NotificationService service = ref.read(notificationServiceProvider);
      await service.initialize();
      await service.requestExactAlarmPermission();
    });
  }

  Future<void> _finish() async {
    if (ref.read(settingsControllerProvider).location == null) return;
    await _run(() async {
      await ref.read(settingsControllerProvider.notifier).completeOnboarding();
      ref.invalidate(todayPrayerDayProvider);
      if (mounted) context.go('/home');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userErrorMessage(context, error))),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return _CenteredPage(
      icon: Icons.nightlight_round,
      title: s.t('tagline'),
      body: s.t('prayerFirst'),
      child: FilledButton.icon(
        onPressed: onContinue,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text(s.t('getStarted')),
      ),
    );
  }
}

class _LocationPage extends StatelessWidget {
  const _LocationPage({
    required this.location,
    required this.working,
    required this.onAutomatic,
    required this.onManual,
  });

  final UserLocation? location;
  final bool working;
  final VoidCallback onAutomatic;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return _CenteredPage(
      icon: Icons.location_on_outlined,
      title: s.t('location'),
      body: location?.label ?? s.t('needLocation'),
      child: Column(
        children: <Widget>[
          FilledButton.icon(
            onPressed: working ? null : onAutomatic,
            icon: const Icon(Icons.my_location_rounded),
            label: Text(s.t('useLocation')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: working ? null : onManual,
            icon: const Icon(Icons.location_city_rounded),
            label: Text(s.t('chooseCity')),
          ),
        ],
      ),
    );
  }
}

class _PrayerPreviewPage extends StatelessWidget {
  const _PrayerPreviewPage({required this.prayerDay, required this.onRefresh});

  final AsyncValue<PrayerDay?> prayerDay;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 12),
          Icon(Icons.schedule_rounded, size: 58, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(s.t('prayerTimes'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(s.t('timesQuestion'), textAlign: TextAlign.center),
          const SizedBox(height: 22),
          Expanded(
            child: prayerDay.when(
              data: (PrayerDay? day) {
                if (day == null) return Center(child: Text(s.t('noData')));
                return ListView.separated(
                  itemCount: day.entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final entry = day.entries[index];
                    final DateTime local = TimezoneService.toLocal(entry.scheduledAtUtc, day.timezoneId);
                    return ListTile(
                      leading: const Icon(Icons.nightlight_outlined),
                      title: Text(entry.type.localizedName(Localizations.localeOf(context).languageCode)),
                      trailing: Text(DateFormat.Hm(Localizations.localeOf(context).languageCode).format(local)),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(userErrorMessage(context, error), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: onRefresh, child: Text(s.t('retry'))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GracePage extends StatelessWidget {
  const _GracePage({required this.minutes, required this.onChanged});
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    const List<int> options = <int>[0, 15, 30, 45, 60, 90];
    return _CenteredPage(
      icon: Icons.timer_outlined,
      title: s.t('graceQuestion'),
      body: '$minutes ${s.t('minutesAfter')}',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: options
            .map((int value) => ChoiceChip(
                  label: Text('$value min'),
                  selected: minutes == value,
                  onSelected: (_) => onChanged(value),
                ))
            .toList(),
      ),
    );
  }
}

class _DistractionPage extends StatelessWidget {
  const _DistractionPage({required this.capabilities, required this.working, required this.onSelectApps});
  final PrayerFocusCapabilities? capabilities;
  final bool working;
  final VoidCallback onSelectApps;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return _CenteredPage(
      icon: Icons.apps_rounded,
      title: s.t('distractions'),
      body: capabilities?.appSelectionSupported == false
          ? s.t('focusFallback')
          : s.t('individualAppsOnly'),
      child: OutlinedButton.icon(
        onPressed: working ? null : onSelectApps,
        icon: const Icon(Icons.checklist_rounded),
        label: Text(s.t('selectApps')),
      ),
    );
  }
}

class _FocusExplainPage extends StatelessWidget {
  const _FocusExplainPage({required this.capabilities, required this.working, required this.onEnable});
  final PrayerFocusCapabilities? capabilities;
  final bool working;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return _CenteredPage(
      icon: Icons.shield_outlined,
      title: s.t('focusMode'),
      body: capabilities?.appShieldingSupported == false
          ? s.t('focusFallback')
          : s.t('focusExplain'),
      child: FilledButton.icon(
        onPressed: working ? null : onEnable,
        icon: const Icon(Icons.shield_rounded),
        label: Text(s.t('enableFocus')),
      ),
    );
  }
}

class _PermissionsPage extends StatelessWidget {
  const _PermissionsPage({required this.working, required this.onNotifications, required this.onExactAlarms, required this.onFinish});
  final bool working;
  final VoidCallback onNotifications;
  final VoidCallback onExactAlarms;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.notifications_active_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(s.t('permissions'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(s.t('permissionExplain'), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(onPressed: working ? null : onNotifications, icon: const Icon(Icons.notifications_rounded), label: Text(s.t('notificationPermission'))),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: working ? null : onExactAlarms, icon: const Icon(Icons.alarm_rounded), label: Text(s.t('exactAlarmPermission'))),
          const SizedBox(height: 26),
          FilledButton.icon(onPressed: working ? null : onFinish, icon: const Icon(Icons.check_rounded), label: Text(s.t('finish'))),
        ],
      ),
    );
  }
}

class _CenteredPage extends StatelessWidget {
  const _CenteredPage({required this.icon, required this.title, required this.body, required this.child});
  final IconData icon;
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: <Widget>[
                Icon(icon, size: 74, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
                const SizedBox(height: 30),
                child,
              ],
            ),
          ),
        ),
      );
}
