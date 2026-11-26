import Foundation

/// What Wachmacher is currently doing.
public enum AwakeState: Equatable, Sendable {
    case off
    case manual(ManualSession)
    case app(WatchedApp)
    case pausedForBattery(percent: Int)

    public var keepsAwake: Bool {
        switch self {
        case .manual, .app: true
        case .off, .pausedForBattery: false
        }
    }
}

/// The user's intent (manual session, override of app triggers) and the rules
/// that turn it plus the environment into an `AwakeState`.
public struct AwakeEngine: Equatable, Sendable {
    public private(set) var manual: ManualSession?
    /// Set when the user switches off while a watched app is active; cleared once
    /// no watched app is active anymore, so the next launch triggers again.
    public private(set) var appOverride = false

    public init(manual: ManualSession? = nil, appOverride: Bool = false) {
        self.manual = manual
        self.appOverride = appOverride
    }

    public func state(
        at now: Date,
        activeApp: WatchedApp?,
        battery: BatteryStatus?,
        protection: BatteryProtection
    ) -> AwakeState {
        let wanted: AwakeState
        if let manual, !manual.isExpired(at: now) {
            wanted = .manual(manual)
        } else if let activeApp, !appOverride {
            wanted = .app(activeApp)
        } else {
            return .off
        }
        if protection.blocks(battery), let battery {
            return .pausedForBattery(percent: battery.percent)
        }
        return wanted
    }

    /// Expires finished timers and resets the app override when it no longer applies.
    public mutating func refresh(at now: Date, activeApp: WatchedApp?) {
        if let manual, manual.isExpired(at: now) { self.manual = nil }
        if activeApp == nil { appOverride = false }
    }

    public mutating func start(at now: Date, until end: Date? = nil) {
        manual = ManualSession(start: now, end: end)
        appOverride = false
    }

    public mutating func stop(activeApp: WatchedApp?) {
        manual = nil
        appOverride = activeApp != nil
    }

    /// Click on the menu bar icon: on ↔ off.
    public mutating func toggle(at now: Date, activeApp: WatchedApp?, current: AwakeState) {
        switch current {
        case .off: start(at: now)
        case .manual, .app, .pausedForBattery: stop(activeApp: activeApp)
        }
    }
}
