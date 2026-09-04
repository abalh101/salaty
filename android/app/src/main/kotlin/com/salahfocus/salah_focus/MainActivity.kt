package com.salahfocus.salah_focus

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Android deliberately exposes a conservative Prayer Focus capability.
 *
 * A normal consumer app cannot suspend arbitrary third-party apps with the
 * public Android SDK. SalahFocus therefore does not use AccessibilityService,
 * overlays, device-owner APIs, or other mechanisms that could create a
 * lock-out or Play policy problem. Flutter provides the safe in-app focus UI.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.salahfocus/prayer_focus"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> result.success(
                    mapOf(
                        "appShieldingSupported" to false,
                        "backgroundSchedulingSupported" to false,
                        "appSelectionSupported" to false,
                        "reason" to "Android does not expose a public consumer API for suspending arbitrary apps. Safe in-app Prayer Focus is used instead.",
                    ),
                )
                "requestAuthorization", "selectBlockedApps", "startFocus" -> result.success(false)
                "stopFocus", "scheduleFocus", "cancelScheduledFocus", "cancelAllScheduledFocus" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }
}
