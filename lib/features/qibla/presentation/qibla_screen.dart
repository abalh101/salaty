import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salah_focus/app/localization/app_strings.dart';
import 'package:salah_focus/features/qibla/domain/qibla_calculator.dart';
import 'package:salah_focus/features/settings/application/settings_controller.dart';

class QiblaScreen extends ConsumerWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings s = AppStrings.of(context);
    final location = ref.watch(settingsControllerProvider).location;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('qibla'))),
      body: location == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.location_off_outlined, size: 58),
                    const SizedBox(height: 16),
                    Text(s.t('needLocation'), textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : _QiblaCompass(
              latitude: location.latitude,
              longitude: location.longitude,
              locationLabel: location.label,
            ),
    );
  }
}

class _QiblaCompass extends StatelessWidget {
  const _QiblaCompass({required this.latitude, required this.longitude, required this.locationLabel});

  final double latitude;
  final double longitude;
  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final double bearing = QiblaCalculator.bearing(latitude: latitude, longitude: longitude);
    final Stream<CompassEvent>? events = FlutterCompass.events;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: <Widget>[
        Text(s.t('qiblaDirection'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(locationLabel, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 28),
        if (events == null)
          _BearingOnly(bearing: bearing)
        else
          StreamBuilder<CompassEvent>(
            stream: events,
            builder: (BuildContext context, AsyncSnapshot<CompassEvent> snapshot) {
              final double? heading = snapshot.data?.heading;
              if (heading == null) return _BearingOnly(bearing: bearing);
              final double relative = QiblaCalculator.relativeAngle(qiblaBearing: bearing, heading: heading);
              return _CompassFace(bearing: bearing, heading: heading, relative: relative);
            },
          ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.info_outline_rounded),
                const SizedBox(width: 12),
                Expanded(child: Text(s.t('calibrate'))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompassFace extends StatelessWidget {
  const _CompassFace({required this.bearing, required this.heading, required this.relative});
  final double bearing;
  final double heading;
  final double relative;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Semantics(
            label: 'Qibla ${bearing.round()} degrees',
            child: Container(
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  const Positioned(top: 16, child: Text('N', style: TextStyle(fontWeight: FontWeight.w900))),
                  const Positioned(bottom: 16, child: Text('S', style: TextStyle(fontWeight: FontWeight.w900))),
                  const Positioned(left: 16, child: Text('W', style: TextStyle(fontWeight: FontWeight.w900))),
                  const Positioned(right: 16, child: Text('E', style: TextStyle(fontWeight: FontWeight.w900))),
                  Transform.rotate(
                    angle: relative * math.pi / 180,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.navigation_rounded, size: 105, color: Theme.of(context).colorScheme.primary),
                        const Text('🕋', style: TextStyle(fontSize: 32)),
                      ],
                    ),
                  ),
                  Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('${bearing.toStringAsFixed(1)}°', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
          Text('${AppStrings.of(context).t('heading')} ${heading.toStringAsFixed(0)}°', style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
}

class _BearingOnly extends StatelessWidget {
  const _BearingOnly({required this.bearing});
  final double bearing;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Column(
      children: <Widget>[
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: Transform.rotate(
            angle: bearing * math.pi / 180,
            child: Icon(Icons.navigation_rounded, size: 112, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: 18),
        Text('${bearing.toStringAsFixed(1)}°', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(s.t('noCompass'), textAlign: TextAlign.center),
      ],
    );
  }
}
