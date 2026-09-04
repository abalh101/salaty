import DeviceActivity
import FamilyControls
import ManagedSettings

/// Add this file to an iOS Device Activity Monitor Extension target.
/// It is intentionally tiny because DeviceActivity extensions have a tight
/// memory budget. The extension guarantees that scheduled shields are applied
/// and cleared even when the Flutter process is not running.
final class PrayerDeviceActivityMonitor: DeviceActivityMonitor {
    private let appGroup = "group.com.salahfocus.app"
    private let selectionKey = "prayerFocusSelection"
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("prayerFocus"))

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let selection = loadSelection() else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        // Category shields are intentionally ignored. Shielding only explicit app
        // tokens reduces the risk of accidentally covering an essential app.
        store.shield.applicationCategories = nil
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.clearAllSettings()
    }

    private func loadSelection() -> FamilyActivitySelection? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: selectionKey) else { return nil }
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}
