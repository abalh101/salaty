import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:salah_focus/app/app_providers.dart';
import 'package:salah_focus/app/localization/app_strings.dart';
import 'package:salah_focus/core/time/timezone_service.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_entry.dart';
import 'package:salah_focus/features/prayer_times/domain/prayer_status.dart';
import 'package:salah_focus/features/settings/application/settings_controller.dart';
import 'package:salah_focus/shared/errors/user_error_message.dart';

class TrackerData {
  const TrackerData({
    required this.entries,
    required this.localNow,
  });

  final List<PrayerEntry> entries;
  final DateTime localNow;
}

final trackerDataProvider = FutureProvider<TrackerData>((Ref ref) async {
  final prefs = ref.watch(settingsControllerProvider);
  final DateTime nowUtc = ref.watch(clockServiceProvider).nowUtc();
  if (prefs.location == null) {
    return TrackerData(entries: const <PrayerEntry>[], localNow: nowUtc);
  }

  final day = await ref.watch(todayPrayerDayProvider.future);
  final String timezoneId = day?.timezoneId ?? prefs.location!.timezoneId;
  final DateTime localNow = TimezoneService.toLocal(nowUtc, timezoneId);
  final DateTime first = DateTime(localNow.year, localNow.month, 1);
  final DateTime last = DateTime(localNow.year, localNow.month + 1, 0);
  final List<PrayerEntry> entries = await ref.watch(prayerCoordinatorProvider).entriesBetween(
        _iso(first),
        _iso(last),
      );

  return TrackerData(entries: entries, localNow: localNow);
});

class TrackerScreen extends ConsumerWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings s = AppStrings.of(context);
    final AsyncValue<TrackerData> tracker = ref.watch(trackerDataProvider);

    Future<void> refresh() async {
      ref.invalidate(todayPrayerDayProvider);
      ref.invalidate(trackerDataProvider);
      await ref.read(trackerDataProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('tracker')),
        actions: <Widget>[
          IconButton(
            tooltip: s.t('refresh'),
            onPressed: () => refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: tracker.when(
        data: (TrackerData data) => _TrackerContent(
          entries: data.entries,
          localNow: data.localNow,
          onRefresh: refresh,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline_rounded, size: 50),
                const SizedBox(height: 12),
                Text(userErrorMessage(context, error), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => refresh(),
                  child: Text(s.t('retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackerContent extends StatelessWidget {
  const _TrackerContent({
    required this.entries,
    required this.localNow,
    required this.onRefresh,
  });

  final List<PrayerEntry> entries;
  final DateTime localNow;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    if (entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
            Center(child: Text(s.t('noData'))),
          ],
        ),
      );
    }

    final DateTime now = localNow;
    final String today = _iso(now);
    final Map<String, List<PrayerEntry>> byDay = <String, List<PrayerEntry>>{};
    for (final PrayerEntry entry in entries) {
      byDay.putIfAbsent(entry.localDate, () => <PrayerEntry>[]).add(entry);
    }

    final int prayed = entries.where((PrayerEntry entry) => entry.status == PrayerStatus.prayed).length;
    final int resolved = entries.where((PrayerEntry entry) => entry.status.isFinal).length;
    final double ratio = resolved == 0 ? 0 : prayed / resolved;
    final DateTime weekStart = DateTime(now.year, now.month, now.day).subtract(
      Duration(days: now.weekday - 1),
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: <Widget>[
          _StatsCard(prayed: prayed, resolved: resolved, ratio: ratio),
          const SizedBox(height: 22),
          Text(
            s.t('today'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _DayCard(date: today, entries: byDay[today] ?? const <PrayerEntry>[]),
          const SizedBox(height: 24),
          Text(
            s.t('week'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < 7; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DayCard(
                date: _iso(weekStart.add(Duration(days: i))),
                entries: byDay[_iso(weekStart.add(Duration(days: i)))] ?? const <PrayerEntry>[],
                compact: true,
              ),
            ),
          const SizedBox(height: 18),
          Text(
            s.t('month'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _MonthGrid(month: DateTime(now.year, now.month), byDay: byDay),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.prayed,
    required this.resolved,
    required this.ratio,
  });

  final int prayed;
  final int resolved;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: ratio,
                strokeWidth: 7,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    s.t('confirmedPrayers'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text('$prayed / $resolved'),
                  Text(
                    '${(ratio * 100).round()} %',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.date,
    required this.entries,
    this.compact = false,
  });

  final String date;
  final List<PrayerEntry> entries;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final DateTime parsed = DateTime.parse(date);
    final String locale = Localizations.localeOf(context).languageCode;
    final int prayed = entries.where((PrayerEntry entry) => entry.status == PrayerStatus.prayed).length;
    final String title = DateFormat(compact ? 'EEE, dd.MM.' : 'EEEE, dd.MM.yyyy', locale).format(parsed);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 13 : 15),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('$prayed/5', style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            if (!compact) ...<Widget>[
              const SizedBox(height: 10),
              for (final PrayerEntry entry in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: <Widget>[
                      _StatusIcon(status: entry.status),
                      const SizedBox(width: 10),
                      Expanded(child: Text(entry.type.localizedName(locale))),
                      Text(_statusLabel(context, entry.status)),
                    ],
                  ),
                ),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(AppStrings.of(context).t('noData')),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.byDay});

  final DateTime month;
  final Map<String, List<PrayerEntry>> byDay;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final int days = DateTime(month.year, month.month + 1, 0).day;
    final int prefix = DateTime(month.year, month.month, 1).weekday - 1;
    final int total = prefix + days;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: total,
          itemBuilder: (BuildContext context, int index) {
            if (index < prefix) return const SizedBox.shrink();
            final int day = index - prefix + 1;
            final String key = _iso(DateTime(month.year, month.month, day));
            final List<PrayerEntry> values = byDay[key] ?? const <PrayerEntry>[];
            final int prayed = values.where((PrayerEntry entry) => entry.status == PrayerStatus.prayed).length;
            return Semantics(
              label: '$day, $prayed/5 ${s.t('confirmedPrayers')}',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: prayed == 5
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('$day', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('$prayed/5', style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final PrayerStatus status;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (status) {
      PrayerStatus.prayed => (Icons.check_circle_rounded, Theme.of(context).colorScheme.primary),
      PrayerStatus.skipped => (Icons.remove_circle_outline_rounded, Theme.of(context).colorScheme.outline),
      PrayerStatus.missed => (Icons.help_outline_rounded, Theme.of(context).colorScheme.error),
      PrayerStatus.snoozed => (Icons.snooze_rounded, Theme.of(context).colorScheme.tertiary),
      _ => (Icons.circle_outlined, Theme.of(context).colorScheme.outline),
    };
    return Icon(icon, color: color, size: 20);
  }
}

String _statusLabel(BuildContext context, PrayerStatus status) {
  final AppStrings s = AppStrings.of(context);
  return switch (status) {
    PrayerStatus.prayed => s.t('prayed'),
    PrayerStatus.skipped => s.t('skipped'),
    PrayerStatus.missed => s.t('missed'),
    PrayerStatus.snoozed => s.t('snoozed'),
    PrayerStatus.pending => s.t('pending'),
    PrayerStatus.active => s.t('active'),
    PrayerStatus.upcoming => s.t('upcoming'),
  };
}

String _iso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
