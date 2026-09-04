import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salah_focus/app/app_providers.dart';
import 'package:salah_focus/app/localization/app_strings.dart';
import 'package:salah_focus/features/prayer_focus/domain/prayer_focus_service.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_settings.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_type.dart';
import 'package:salah_focus/features/prayer_times/domain/user_location.dart';
import 'package:salah_focus/features/settings/application/settings_controller.dart';
import 'package:salah_focus/shared/errors/user_error_message.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  PrayerFocusCapabilities? _capabilities;
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final prefs = ref.watch(settingsControllerProvider);
    final PrayerSettings settings = prefs.prayerSettings;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _SectionTitle(title: s.t('prayerTimes'), icon: Icons.schedule_rounded),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(s.t('location')),
                  subtitle: Text(prefs.location?.label ?? s.t('needLocation')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _working ? null : _changeLocation,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: Text(s.t('calculationMethod')),
                  subtitle: Text(_calculationMethodName(settings.calculationMethodId)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _chooseCalculationMethod(settings),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.balance_rounded),
                  title: Text(s.t('madhhab')),
                  subtitle: Text(settings.madhhab == AsrMadhhab.hanafi ? s.t('hanafi') : s.t('standard')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _chooseMadhhab(settings),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.public_rounded),
                  title: Text(s.t('highLatitude')),
                  subtitle: Text(_highLatitudeName(settings.highLatitudeRule)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _chooseHighLatitude(settings),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: Text(s.t('manualAdjustments')),
                  subtitle: Text(_adjustmentsSummary(settings)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editAdjustments(settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: s.t('permissions'), icon: Icons.notifications_active_outlined),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(s.t('notificationPermission')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _working ? null : _requestNotifications,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.alarm_rounded),
                  title: Text(s.t('exactAlarmPermission')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _working ? null : _requestExactAlarms,
                ),
                const Divider(height: 1),
                _SliderTile(
                  title: s.t('gracePeriod'),
                  valueLabel: '${settings.gracePeriodMinutes} min',
                  value: settings.gracePeriodMinutes.toDouble(),
                  min: 0,
                  max: 120,
                  divisions: 24,
                  onChanged: (double value) => _savePrayerSettings(
                    settings.copyWith(gracePeriodMinutes: value.round()),
                  ),
                ),
                const Divider(height: 1),
                _SliderTile(
                  title: s.t('snoozeDuration'),
                  valueLabel: '${settings.snoozeMinutes} min',
                  value: settings.snoozeMinutes.toDouble(),
                  min: 5,
                  max: 30,
                  divisions: 5,
                  onChanged: (double value) => _savePrayerSettings(
                    settings.copyWith(snoozeMinutes: value.round()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(s.t('maxSnoozes')),
                  subtitle: Text(settings.maxSnoozes?.toString() ?? s.t('unlimited')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _chooseMaxSnoozes(settings),
                ),
                SwitchListTile(
                  title: Text(s.t('softReminder')),
                  value: settings.softReminderAfterSkip,
                  onChanged: (bool value) => _savePrayerSettings(settings.copyWith(softReminderAfterSkip: value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: s.t('focusMode'), icon: Icons.shield_outlined),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  secondary: const Icon(Icons.shield_rounded),
                  title: Text(s.t('focusMode')),
                  subtitle: Text(
                    _capabilities?.appShieldingSupported == false
                        ? s.t('focusFallback')
                        : s.t('focusExplain'),
                  ),
                  value: settings.focusEnabled,
                  onChanged: _working
                      ? null
                      : (bool value) async {
                          if (value) {
                            await _authorizeFocus();
                          } else {
                            await ref.read(prayerCoordinatorProvider).disableFocus();
                          }
                          await _savePrayerSettings(
                            settings.copyWith(focusEnabled: value),
                          );
                        },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(s.t('focusAuthorization')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _working ? null : _authorizeFocus,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.apps_rounded),
                  title: Text(s.t('selectApps')),
                  subtitle: Text(
                    _capabilities?.appSelectionSupported == false
                        ? s.t('focusFallback')
                        : s.t('individualAppsOnly'),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _working ? null : _selectApps,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: s.t('confirmationText'), icon: Icons.check_circle_outline_rounded),
          Card(
            child: ListTile(
              title: Text(s.t('confirmationText')),
              subtitle: Text(settings.confirmationText),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editConfirmationText(settings),
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: s.t('theme'), icon: Icons.palette_outlined),
          Card(
            child: Column(
              children: <Widget>[
                _RadioLikeTile(
                  title: s.t('system'),
                  selected: prefs.themeMode == ThemeMode.system.name,
                  onTap: () => ref.read(settingsControllerProvider.notifier).setThemeMode(ThemeMode.system),
                ),
                _RadioLikeTile(
                  title: s.t('light'),
                  selected: prefs.themeMode == ThemeMode.light.name,
                  onTap: () => ref.read(settingsControllerProvider.notifier).setThemeMode(ThemeMode.light),
                ),
                _RadioLikeTile(
                  title: s.t('dark'),
                  selected: prefs.themeMode == ThemeMode.dark.name,
                  onTap: () => ref.read(settingsControllerProvider.notifier).setThemeMode(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: s.t('language'), icon: Icons.language_rounded),
          Card(
            child: Column(
              children: <Widget>[
                _RadioLikeTile(title: s.t('german'), selected: prefs.localeCode == 'de', onTap: () => ref.read(settingsControllerProvider.notifier).setLocale('de')),
                _RadioLikeTile(title: s.t('english'), selected: prefs.localeCode == 'en', onTap: () => ref.read(settingsControllerProvider.notifier).setLocale('en')),
                _RadioLikeTile(title: s.t('arabic'), selected: prefs.localeCode == 'ar', onTap: () => ref.read(settingsControllerProvider.notifier).setLocale('ar')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeLocation() async {
    final AppStrings s = AppStrings.of(context);
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(leading: const Icon(Icons.my_location_rounded), title: Text(s.t('useLocation')), onTap: () => Navigator.of(context).pop('gps')),
            ListTile(leading: const Icon(Icons.location_city_rounded), title: Text(s.t('chooseCity')), onTap: () => Navigator.of(context).pop('manual')),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'gps') {
      await _run(() async {
        final UserLocation location = await ref.read(locationServiceProvider).currentLocation(ref.read(deviceTimezoneIdProvider));
        await ref.read(settingsControllerProvider.notifier).setLocation(location);
        ref.invalidate(todayPrayerDayProvider);
      });
      return;
    }
    await _manualLocationDialog();
  }

  Future<void> _manualLocationDialog() async {
    final AppStrings s = AppStrings.of(context);
    final TextEditingController city = TextEditingController();
    final TextEditingController country = TextEditingController();
    final bool accepted = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(s.t('chooseCity')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(controller: city, decoration: InputDecoration(labelText: s.t('city'))),
                const SizedBox(height: 10),
                TextField(controller: country, decoration: InputDecoration(labelText: s.t('country'))),
              ],
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s.t('cancel'))),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s.t('save'))),
            ],
          ),
        ) ??
        false;
    final String cityValue = city.text.trim();
    final String countryValue = country.text.trim();
    city.dispose();
    country.dispose();
    if (!accepted || cityValue.isEmpty || countryValue.isEmpty) return;
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

  Future<void> _chooseCalculationMethod(PrayerSettings current) async {
    const Map<int, String> methods = <int, String>{
      3: 'Muslim World League',
      2: 'ISNA',
      4: 'Umm Al-Qura, Makkah',
      5: 'Egyptian General Authority',
      1: 'University of Karachi',
      13: 'Diyanet İşleri Başkanlığı',
    };
    final int? selected = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text(AppStrings.of(context).t('calculationMethod')),
        children: methods.entries
            .map((MapEntry<int, String> entry) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(entry.key),
                  child: _DialogChoice(
                    selected: entry.key == current.calculationMethodId,
                    label: entry.value,
                  ),
                ))
            .toList(),
      ),
    );
    if (selected != null) await _savePrayerSettings(current.copyWith(calculationMethodId: selected));
  }

  Future<void> _chooseMadhhab(PrayerSettings current) async {
    final AppStrings s = AppStrings.of(context);
    final AsrMadhhab? selected = await showDialog<AsrMadhhab>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text(s.t('madhhab')),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(AsrMadhhab.standard),
            child: _DialogChoice(
              selected: current.madhhab == AsrMadhhab.standard,
              label: s.t('standard'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(AsrMadhhab.hanafi),
            child: _DialogChoice(
              selected: current.madhhab == AsrMadhhab.hanafi,
              label: s.t('hanafi'),
            ),
          ),
        ],
      ),
    );
    if (selected != null) await _savePrayerSettings(current.copyWith(madhhab: selected));
  }

  Future<void> _chooseHighLatitude(PrayerSettings current) async {
    final HighLatitudeRule? selected = await showDialog<HighLatitudeRule>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text(AppStrings.of(context).t('highLatitude')),
        children: HighLatitudeRule.values
            .map((HighLatitudeRule rule) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(rule),
                  child: _DialogChoice(
                    selected: rule == current.highLatitudeRule,
                    label: _highLatitudeName(rule),
                  ),
                ))
            .toList(),
      ),
    );
    if (selected != null) await _savePrayerSettings(current.copyWith(highLatitudeRule: selected));
  }

  Future<void> _editAdjustments(PrayerSettings current) async {
    final Map<PrayerType, int> values = <PrayerType, int>{for (final PrayerType type in PrayerType.values) type: current.adjustmentFor(type)};
    final bool accepted = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
              title: Text(AppStrings.of(context).t('manualAdjustments')),
              content: SizedBox(
                width: 420,
                child: ListView(
                  shrinkWrap: true,
                  children: PrayerType.values
                      .map((PrayerType type) => Row(
                            children: <Widget>[
                              Expanded(child: Text(type.localizedName(Localizations.localeOf(context).languageCode))),
                              IconButton(
                                onPressed: (values[type] ?? 0) <= -60
                                    ? null
                                    : () => setDialogState(
                                          () => values[type] = (values[type] ?? 0) - 1,
                                        ),
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              SizedBox(
                                width: 64,
                                child: Text(
                                  '${values[type] ?? 0} min',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                onPressed: (values[type] ?? 0) >= 60
                                    ? null
                                    : () => setDialogState(
                                          () => values[type] = (values[type] ?? 0) + 1,
                                        ),
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ))
                      .toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppStrings.of(context).t('cancel'))),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppStrings.of(context).t('save'))),
              ],
            ),
          ),
        ) ??
        false;
    if (accepted) await _savePrayerSettings(current.copyWith(adjustments: values));
  }

  Future<void> _chooseMaxSnoozes(PrayerSettings current) async {
    final int? value = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text(AppStrings.of(context).t('maxSnoozes')),
        children: <Widget>[
          SimpleDialogOption(onPressed: () => Navigator.of(context).pop(-1), child: Text(AppStrings.of(context).t('unlimited'))),
          for (int count = 1; count <= 5; count++) SimpleDialogOption(onPressed: () => Navigator.of(context).pop(count), child: Text('$count')),
        ],
      ),
    );
    if (value == null) return;
    if (value == -1) {
      await _savePrayerSettings(current.copyWith(clearMaxSnoozes: true));
    } else {
      await _savePrayerSettings(current.copyWith(maxSnoozes: value));
    }
  }

  Future<void> _editConfirmationText(PrayerSettings current) async {
    final TextEditingController controller = TextEditingController(text: current.confirmationText);
    final bool accepted = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(AppStrings.of(context).t('confirmationText')),
            content: TextField(controller: controller, maxLength: 80, decoration: InputDecoration(hintText: AppStrings.of(context).t('confirmPrayer'))),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppStrings.of(context).t('cancel'))),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppStrings.of(context).t('save'))),
            ],
          ),
        ) ??
        false;
    final String text = controller.text.trim();
    controller.dispose();
    if (accepted && text.isNotEmpty) await _savePrayerSettings(current.copyWith(confirmationText: text));
  }

  Future<void> _requestNotifications() async => _run(() async {
        final service = ref.read(notificationServiceProvider);
        await service.initialize();
        await service.requestPermission();
      });

  Future<void> _requestExactAlarms() async => _run(() async {
        final service = ref.read(notificationServiceProvider);
        await service.initialize();
        await service.requestExactAlarmPermission();
      });

  Future<void> _authorizeFocus() async => _run(() async {
        final PrayerFocusService focus = ref.read(prayerFocusServiceProvider);
        _capabilities = await focus.capabilities();
        if (_capabilities!.appShieldingSupported) await focus.requestAuthorization();
        if (mounted) setState(() {});
      });

  Future<void> _selectApps() async => _run(() async {
        final PrayerFocusService focus = ref.read(prayerFocusServiceProvider);
        _capabilities ??= await focus.capabilities();
        if (_capabilities!.appSelectionSupported) {
          final bool authorized = !_capabilities!.appShieldingSupported ||
              await focus.requestAuthorization();
          if (authorized) await focus.selectBlockedApps();
        }
        if (mounted) setState(() {});
      });

  Future<void> _savePrayerSettings(PrayerSettings settings) async {
    await ref.read(settingsControllerProvider.notifier).setPrayerSettings(settings);
    ref.invalidate(todayPrayerDayProvider);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userErrorMessage(context, error))));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _calculationMethodName(int id) => switch (id) {
        1 => 'University of Karachi',
        2 => 'ISNA',
        4 => 'Umm Al-Qura, Makkah',
        5 => 'Egyptian General Authority',
        13 => 'Diyanet İşleri Başkanlığı',
        _ => 'Muslim World League',
      };

  String _highLatitudeName(HighLatitudeRule rule) => switch (rule) {
        HighLatitudeRule.middleOfNight => 'Middle of the Night',
        HighLatitudeRule.oneSeventh => 'One Seventh',
        HighLatitudeRule.angleBased => 'Angle Based',
      };

  String _adjustmentsSummary(PrayerSettings settings) => PrayerType.values
      .where((PrayerType type) => settings.adjustmentFor(type) != 0)
      .map((PrayerType type) => '${type.name} ${settings.adjustmentFor(type) >= 0 ? '+' : ''}${settings.adjustmentFor(type)}')
      .join(' · ')
      .trim()
      .isEmpty
      ? '0 min'
      : PrayerType.values
          .where((PrayerType type) => settings.adjustmentFor(type) != 0)
          .map((PrayerType type) => '${type.name} ${settings.adjustmentFor(type) >= 0 ? '+' : ''}${settings.adjustmentFor(type)}')
          .join(' · ');
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Row(children: <Widget>[Icon(icon, size: 20), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))]),
      );
}

class _DialogChoice extends StatelessWidget {
  const _DialogChoice({required this.selected, required this.label});

  final bool selected;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      );
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({required this.title, required this.valueLabel, required this.value, required this.min, required this.max, required this.divisions, required this.onChanged});
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[Expanded(child: Text(title)), Text(valueLabel, style: const TextStyle(fontWeight: FontWeight.w800))]),
            Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, divisions: divisions, label: valueLabel, onChanged: onChanged),
          ],
        ),
      );
}

class _RadioLikeTile extends StatelessWidget {
  const _RadioLikeTile({required this.title, required this.selected, required this.onTap});
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title),
        leading: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: selected ? Theme.of(context).colorScheme.primary : null),
        onTap: onTap,
      );
}
