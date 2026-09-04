import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salah_focus/app/app_providers.dart';
import 'package:salah_focus/app/localization/app_strings.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_status.dart';
import 'package:salah_focus/features/settings/application/settings_controller.dart';
import 'package:salah_focus/shared/errors/user_error_message.dart';

class PrayerFocusScreen extends ConsumerStatefulWidget {
  const PrayerFocusScreen({required this.prayerId, super.key});

  final String prayerId;

  @override
  ConsumerState<PrayerFocusScreen> createState() => _PrayerFocusScreenState();
}

class _PrayerFocusScreenState extends ConsumerState<PrayerFocusScreen> {
  bool _startingFocus = false;
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PrayerEntry?> prayerAsync =
        ref.watch(prayerByIdProvider(widget.prayerId));
    return Scaffold(
      body: SafeArea(
        child: prayerAsync.when(
          data: (PrayerEntry? prayer) {
            if (prayer == null) {
              return _MissingPrayer(onClose: () => context.go('/home'));
            }
            _startFocusIfNeeded(prayer);
            if (prayer.status.isFinal) {
              return _ResolvedPrayerContent(
                prayer: prayer,
                working: _working,
                onConfirm: () => _confirm(prayer),
                onClose: () => context.go('/home'),
              );
            }
            return _FocusContent(
              prayer: prayer,
              working: _working,
              onConfirm: () => _confirm(prayer),
              onSnooze: () => _snooze(prayer),
              onSkip: () => _skip(prayer),
              onEmergency: () => _emergency(prayer),
            );
          },
          error: (Object error, StackTrace stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.error_outline_rounded, size: 52),
                  const SizedBox(height: 12),
                  Text(userErrorMessage(context, error), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => context.go('/home'),
                    child: Text(AppStrings.of(context).t('home')),
                  ),
                ],
              ),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  void _startFocusIfNeeded(PrayerEntry prayer) {
    final bool enabled =
        ref.read(settingsControllerProvider).prayerSettings.focusEnabled;
    if (_startingFocus || !enabled || prayer.status != PrayerStatus.pending) {
      return;
    }
    _startingFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(prayerCoordinatorProvider).startFocus(prayer);
    });
  }

  Future<void> _confirm(PrayerEntry prayer) async {
    await _run(() async {
      await ref.read(prayerCoordinatorProvider).confirm(prayer);
      if (!mounted) return;
      ref.invalidate(todayPrayerDayProvider);
      ref.invalidate(prayerByIdProvider(widget.prayerId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).t('accepted'))),
      );
      context.go('/home');
    });
  }

  Future<void> _snooze(PrayerEntry prayer) async {
    final settings = ref.read(settingsControllerProvider).prayerSettings;
    final String prayerName = prayer.type.localizedName(
      Localizations.localeOf(context).languageCode,
    );
    await _run(() async {
      try {
        await ref.read(prayerCoordinatorProvider).snooze(
              prayer,
              settings,
              prayerName,
              Localizations.localeOf(context).languageCode,
            );
        if (!mounted) return;
        ref.invalidate(todayPrayerDayProvider);
        ref.invalidate(prayerByIdProvider(widget.prayerId));
        context.go('/home');
      } on StateError {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).t('snoozeUnavailable'))),
        );
      }
    });
  }

  Future<void> _skip(PrayerEntry prayer) async {
    final AppStrings s = AppStrings.of(context);
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(s.t('skipConfirmTitle')),
            content: Text(s.t('skipConfirmBody')),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(s.t('noPrayLater')),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(s.t('yesEnd')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final settings = ref.read(settingsControllerProvider).prayerSettings;
    final String prayerName = prayer.type.localizedName(
      Localizations.localeOf(context).languageCode,
    );
    await _run(() async {
      await ref.read(prayerCoordinatorProvider).skip(
            prayer,
            settings,
            prayerName,
            Localizations.localeOf(context).languageCode,
          );
      if (!mounted) return;
      ref.invalidate(todayPrayerDayProvider);
      ref.invalidate(prayerByIdProvider(widget.prayerId));
      context.go('/home');
    });
  }

  Future<void> _emergency(PrayerEntry prayer) async {
    final AppStrings s = AppStrings.of(context);
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(s.t('emergencyUnlock')),
            content: Text(s.t('emergencyBody')),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(s.t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(s.t('emergencyUnlock')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await _run(() async {
      await ref.read(prayerCoordinatorProvider).emergencyUnlock(prayer);
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

class _ResolvedPrayerContent extends ConsumerWidget {
  const _ResolvedPrayerContent({
    required this.prayer,
    required this.working,
    required this.onConfirm,
    required this.onClose,
  });

  final PrayerEntry prayer;
  final bool working;
  final VoidCallback onConfirm;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings s = AppStrings.of(context);
    final String status = switch (prayer.status) {
      PrayerStatus.prayed => s.t('prayed'),
      PrayerStatus.skipped => s.t('skipped'),
      PrayerStatus.missed => s.t('missed'),
      _ => s.t('pending'),
    };
    final settings = ref.watch(settingsControllerProvider).prayerSettings;
    final String confirmText = settings.confirmationText.trim().isEmpty
        ? s.t('confirmPrayer')
        : settings.confirmationText.trim();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                prayer.status == PrayerStatus.prayed
                    ? Icons.check_circle_rounded
                    : Icons.history_rounded,
                size: 74,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                prayer.type.localizedName(Localizations.localeOf(context).languageCode),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(status, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              if (prayer.status != PrayerStatus.prayed) ...<Widget>[
                FilledButton.icon(
                  onPressed: working ? null : onConfirm,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(confirmText, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton(
                onPressed: working ? null : onClose,
                child: Text(s.t('home')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusContent extends StatelessWidget {
  const _FocusContent({
    required this.prayer,
    required this.working,
    required this.onConfirm,
    required this.onSnooze,
    required this.onSkip,
    required this.onEmergency,
  });

  final PrayerEntry prayer;
  final bool working;
  final VoidCallback onConfirm;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;
  final VoidCallback onEmergency;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final String language = Localizations.localeOf(context).languageCode;
    final String prayerName = prayer.type.localizedName(language);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
        child: Column(
          children: <Widget>[
            const Spacer(),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.nightlight_round,
                size: 40,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 26),
            Text(
              s.t('focusTitle', params: <String, String>{'prayer': prayerName}),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                s.t('focusBody'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ),
            const Spacer(),
            _FocusActions(
              prayer: prayer,
              working: working,
              onConfirm: onConfirm,
              onSnooze: onSnooze,
              onSkip: onSkip,
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: working ? null : onEmergency,
              icon: const Icon(Icons.lock_open_rounded),
              label: Text(s.t('emergencyUnlock')),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusActions extends ConsumerWidget {
  const _FocusActions({
    required this.prayer,
    required this.working,
    required this.onConfirm,
    required this.onSnooze,
    required this.onSkip,
  });

  final PrayerEntry prayer;
  final bool working;
  final VoidCallback onConfirm;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings s = AppStrings.of(context);
    final settings = ref.watch(settingsControllerProvider).prayerSettings;
    final String confirmText = settings.confirmationText.trim().isEmpty
        ? s.t('confirmPrayer')
        : settings.confirmationText.trim();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        children: <Widget>[
          FilledButton.icon(
            onPressed: working ? null : onConfirm,
            icon: const Icon(Icons.check_rounded),
            label: Text(confirmText, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: working ? null : onSnooze,
            icon: const Icon(Icons.snooze_rounded),
            label: Text(
              s.t('snoozeIn', params: <String, String>{'minutes': '${settings.snoozeMinutes}'}),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: working ? null : onSkip,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.remove_circle_outline_rounded),
            label: Text(s.t('skipToday')),
          ),
        ],
      ),
    );
  }
}

class _MissingPrayer extends StatelessWidget {
  const _MissingPrayer({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton.tonal(
          onPressed: onClose,
          child: Text(AppStrings.of(context).t('home')),
        ),
      );
}
