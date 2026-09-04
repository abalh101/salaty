import 'package:flutter/services.dart';
import 'package:salah_focus/features/prayer_focus/domain/prayer_focus_service.dart';

class PlatformPrayerFocusService implements PrayerFocusService {
  PlatformPrayerFocusService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.salahfocus/prayer_focus');

  final MethodChannel _channel;

  @override
  Future<PrayerFocusCapabilities> capabilities() async {
    try {
      final Map<Object?, Object?>? raw =
          await _channel.invokeMapMethod<Object?, Object?>('capabilities');
      return PrayerFocusCapabilities(
        appShieldingSupported: raw?['appShieldingSupported'] == true,
        backgroundSchedulingSupported:
            raw?['backgroundSchedulingSupported'] == true,
        appSelectionSupported: raw?['appSelectionSupported'] == true,
        reason: raw?['reason'] as String?,
      );
    } on PlatformException catch (error) {
      return PrayerFocusCapabilities(
        appShieldingSupported: false,
        backgroundSchedulingSupported: false,
        appSelectionSupported: false,
        reason: error.message,
      );
    } on MissingPluginException {
      return const PrayerFocusCapabilities(
        appShieldingSupported: false,
        backgroundSchedulingSupported: false,
        appSelectionSupported: false,
        reason: 'Native Prayer Focus is not installed on this build.',
      );
    }
  }

  @override
  Future<bool> requestAuthorization() => _boolCall('requestAuthorization');

  @override
  Future<bool> selectBlockedApps() => _boolCall('selectBlockedApps');

  @override
  Future<bool> startFocus({required DateTime maximumEndUtc}) => _boolCall(
        'startFocus',
        <String, Object?>{
          'maximumEndUtc': maximumEndUtc.toUtc().toIso8601String(),
        },
      );

  @override
  Future<void> stopFocus() async {
    try {
      await _channel.invokeMethod<void>('stopFocus');
    } on PlatformException {
      // Fail-open by design.
    } on MissingPluginException {
      // Basic in-app Prayer Focus still works without native shielding.
    }
  }

  @override
  Future<void> scheduleFocus({
    required String identifier,
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    try {
      await _channel.invokeMethod<void>(
        'scheduleFocus',
        <String, Object?>{
          'identifier': identifier,
          'startUtc': startUtc.toUtc().toIso8601String(),
          'endUtc': endUtc.toUtc().toIso8601String(),
        },
      );
    } on PlatformException {
      // Notifications remain the legal fallback.
    } on MissingPluginException {
      // Notifications remain the legal fallback.
    }
  }

  @override
  Future<void> cancelScheduledFocus(String identifier) async {
    try {
      await _channel.invokeMethod<void>(
        'cancelScheduledFocus',
        <String, Object?>{'identifier': identifier},
      );
    } on PlatformException {
      // Fail-open.
    } on MissingPluginException {
      // Fail-open.
    }
  }

  @override
  Future<void> cancelAllScheduledFocus() async {
    try {
      await _channel.invokeMethod<void>('cancelAllScheduledFocus');
    } on PlatformException {
      // Fail-open.
    } on MissingPluginException {
      // Fail-open.
    }
  }

  Future<bool> _boolCall(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
