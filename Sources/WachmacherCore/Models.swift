import Foundation

/// An app that automatically keeps the Mac awake.
public struct WatchedApp: Codable, Hashable, Identifiable, Sendable {
    public var bundleID: String
    public var name: String
    public var id: String { bundleID }

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

/// When a watched app counts as "active".
public enum TriggerMode: String, Codable, CaseIterable, Sendable {
    case running
    case frontmost
}

public struct BatteryStatus: Equatable, Sendable {
    public var percent: Int
    public var onBattery: Bool

    public init(percent: Int, onBattery: Bool) {
        self.percent = percent
        self.onBattery = onBattery
    }
}

public struct BatteryProtection: Equatable, Sendable {
    public var isEnabled: Bool
    public var threshold: Int

    public init(isEnabled: Bool, threshold: Int) {
        self.isEnabled = isEnabled
        self.threshold = threshold
    }

    /// True when running on battery at or below the threshold.
    public func blocks(_ battery: BatteryStatus?) -> Bool {
        guard isEnabled, let battery, battery.onBattery else { return false }
        return battery.percent <= threshold
    }
}

/// A manually started keep-awake period, optionally with an end time.
public struct ManualSession: Equatable, Sendable {
    public var start: Date
    public var end: Date?

    public init(start: Date, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    public func isExpired(at now: Date) -> Bool {
        guard let end else { return false }
        return now >= end
    }

    /// Remaining share of the timer in 0...1, or nil for an unlimited session.
    public func fractionRemaining(at now: Date) -> Double? {
        guard let end else { return nil }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return min(1, max(0, end.timeIntervalSince(now) / total))
    }
}
