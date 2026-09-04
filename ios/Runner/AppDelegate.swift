import Flutter
import UIKit
import UserNotifications
import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var prayerFocusBridge: PrayerFocusBridge?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
        GeneratedPluginRegistrant.register(with: self)

        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: "com.salahfocus/prayer_focus",
                binaryMessenger: controller.binaryMessenger
            )
            let bridge = PrayerFocusBridge(presenter: controller)
            prayerFocusBridge = bridge
            channel.setMethodCallHandler { [weak bridge] call, result in
                bridge?.handle(call: call, result: result)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

@available(iOS 16.0, *)
private struct PrayerAppPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: FamilyActivitySelection
    let onDone: (FamilyActivitySelection?) -> Void

    init(selection: FamilyActivitySelection, onDone: @escaping (FamilyActivitySelection?) -> Void) {
        _selection = State(initialValue: selection)
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Prayer Focus")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            onDone(nil)
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onDone(selection)
                            dismiss()
                        }
                    }
                }
        }
    }
}

private final class PrayerFocusBridge {
    private weak var presenter: UIViewController?
    private let appGroup = "group.com.salahfocus.app"
    private let selectionKey = "prayerFocusSelection"
    private let storeName = ManagedSettingsStore.Name("prayerFocus")
    private let liveActivityName = DeviceActivityName("salahFocus.live")

    init(presenter: UIViewController) {
        self.presenter = presenter
    }

    func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.0, *) else {
            handleUnsupported(call: call, result: result)
            return
        }

        switch call.method {
        case "capabilities":
            result([
                "appShieldingSupported": true,
                "backgroundSchedulingSupported": true,
                "appSelectionSupported": true,
                "reason": "Uses Apple FamilyControls, ManagedSettings and DeviceActivity. Family Controls entitlement is required."
            ])

        case "requestAuthorization":
            Task { @MainActor in
                do {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    result(true)
                } catch {
                    result(false)
                }
            }

        case "selectBlockedApps":
            presentPicker(result: result)

        case "startFocus":
            guard let arguments = call.arguments as? [String: Any],
                  let endText = arguments["maximumEndUtc"] as? String,
                  let endDate = Self.isoFormatter.date(from: endText) else {
                result(FlutterError(code: "bad_arguments", message: "Missing maximumEndUtc", details: nil))
                return
            }
            let applied = applyShield()
            if applied {
                schedule(name: liveActivityName, start: Date(), end: endDate)
            }
            result(applied)

        case "stopFocus":
            DeviceActivityCenter().stopMonitoring([liveActivityName])
            clearShield()
            result(nil)

        case "scheduleFocus":
            guard let arguments = call.arguments as? [String: Any],
                  let identifier = arguments["identifier"] as? String,
                  let startText = arguments["startUtc"] as? String,
                  let endText = arguments["endUtc"] as? String,
                  let start = Self.isoFormatter.date(from: startText),
                  let end = Self.isoFormatter.date(from: endText) else {
                result(FlutterError(code: "bad_arguments", message: "Invalid focus schedule", details: nil))
                return
            }
            schedule(name: Self.activityName(identifier), start: start, end: end)
            result(nil)

        case "cancelScheduledFocus":
            guard let arguments = call.arguments as? [String: Any],
                  let identifier = arguments["identifier"] as? String else {
                result(nil)
                return
            }
            DeviceActivityCenter().stopMonitoring([Self.activityName(identifier)])
            result(nil)

        case "cancelAllScheduledFocus":
            cancelAllPrayerMonitoring()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleUnsupported(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "capabilities":
            result([
                "appShieldingSupported": false,
                "backgroundSchedulingSupported": false,
                "appSelectionSupported": false,
                "reason": "Individual Screen Time authorization requires iOS 16 or later."
            ])
        case "requestAuthorization", "selectBlockedApps", "startFocus":
            result(false)
        case "stopFocus", "scheduleFocus", "cancelScheduledFocus", "cancelAllScheduledFocus":
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 16.0, *)
    private func presentPicker(result: @escaping FlutterResult) {
        guard let presenter else {
            result(false)
            return
        }
        let current = loadSelection() ?? FamilyActivitySelection(includeEntireCategory: false)
        let view = PrayerAppPickerView(selection: current) { [weak self] selected in
            guard let self, let selected else {
                result(false)
                return
            }
            result(self.saveSelection(selected))
        }
        let host = UIHostingController(rootView: view)
        host.isModalInPresentation = true
        presenter.present(host, animated: true)
    }

    @available(iOS 16.0, *)
    private func applyShield() -> Bool {
        guard let selection = loadSelection() else { return false }
        let store = ManagedSettingsStore(named: storeName)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        // Category shields are intentionally ignored. Shielding only explicit app
        // tokens reduces the risk of accidentally covering an essential app.
        store.shield.applicationCategories = nil
        return !selection.applicationTokens.isEmpty
    }

    private func clearShield() {
        ManagedSettingsStore(named: storeName).clearAllSettings()
    }

    @available(iOS 16.0, *)
    private func cancelAllPrayerMonitoring() {
        let center = DeviceActivityCenter()
        let scheduledPrayerActivities = center.activities.filter { activity in
            activity.rawValue != liveActivityName.rawValue &&
                activity.rawValue.hasPrefix("salahFocus.")
        }
        if !scheduledPrayerActivities.isEmpty {
            center.stopMonitoring(scheduledPrayerActivities)
        }
    }

    @available(iOS 16.0, *)
    private func saveSelection(_ selection: FamilyActivitySelection) -> Bool {
        guard let data = try? PropertyListEncoder().encode(selection) else { return false }
        guard let defaults = UserDefaults(suiteName: appGroup) else { return false }
        defaults.set(data, forKey: selectionKey)
        return true
    }

    @available(iOS 16.0, *)
    private func loadSelection() -> FamilyActivitySelection? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: selectionKey) else { return nil }
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    @available(iOS 16.0, *)
    private func schedule(name: DeviceActivityName, start: Date, end: Date) {
        guard end > start else { return }
        let calendar = Calendar.autoupdatingCurrent
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: end)
        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false,
            warningTime: nil
        )
        do {
            DeviceActivityCenter().stopMonitoring([name])
            try DeviceActivityCenter().startMonitoring(name, during: schedule)
        } catch {
            // Flutter still has the safe in-app focus fallback.
        }
    }

    private static func activityName(_ identifier: String) -> DeviceActivityName {
        let safe = identifier.replacingOccurrences(of: ":", with: ".")
        return DeviceActivityName("salahFocus.\(safe)")
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
