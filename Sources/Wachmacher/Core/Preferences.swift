import Foundation
import Observation
import ServiceManagement
import WachmacherCore

/// User settings, persisted in UserDefaults.
@MainActor
@Observable
final class Preferences {
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults = UserDefaults.standard

    var moveMouse: Bool { didSet { save(moveMouse, "moveMouse") } }
    var batteryProtectionEnabled: Bool { didSet { save(batteryProtectionEnabled, "batteryProtectionEnabled") } }
    var batteryThreshold: Int { didSet { save(batteryThreshold, "batteryThreshold") } }
    /// Minutes after midnight.
    var workdayEndMinutes: Int { didSet { save(workdayEndMinutes, "workdayEndMinutes") } }
    var triggerMode: TriggerMode { didSet { save(triggerMode.rawValue, "triggerMode") } }
    var watchedApps: [WatchedApp] {
        didSet { save(try? JSONEncoder().encode(watchedApps), "watchedApps") }
    }

    var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Launch at login failed: \(error)")
            }
        }
    }

    var batteryProtection: BatteryProtection {
        BatteryProtection(isEnabled: batteryProtectionEnabled, threshold: batteryThreshold)
    }

    init() {
        defaults.register(defaults: [
            "batteryProtectionEnabled": true,
            "batteryThreshold": 20,
            "workdayEndMinutes": 17 * 60,
            "triggerMode": TriggerMode.running.rawValue,
        ])
        moveMouse = defaults.bool(forKey: "moveMouse")
        batteryProtectionEnabled = defaults.bool(forKey: "batteryProtectionEnabled")
        batteryThreshold = defaults.integer(forKey: "batteryThreshold")
        workdayEndMinutes = defaults.integer(forKey: "workdayEndMinutes")
        triggerMode = TriggerMode(rawValue: defaults.string(forKey: "triggerMode") ?? "") ?? .running
        watchedApps = defaults.data(forKey: "watchedApps")
            .flatMap { try? JSONDecoder().decode([WatchedApp].self, from: $0) } ?? []
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func save(_ value: Any?, _ key: String) {
        defaults.set(value, forKey: key)
        onChange?()
    }
}
