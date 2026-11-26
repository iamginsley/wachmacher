import Foundation

public enum TimeHelpers {
    /// Today's end of work at `minutes` after midnight, or nil if it has already passed.
    public static func endOfWorkday(minutes: Int, now: Date, calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .minute, value: minutes, to: start), end > now else {
            return nil
        }
        return end
    }

    /// "noch 42 Min", "noch 1 Std 5 Min", "noch 2 Std".
    public static func remainingText(until end: Date, now: Date) -> String {
        let minutes = max(1, Int((end.timeIntervalSince(now) / 60).rounded(.up)))
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "noch \(rest) Min"
        case (_, 0): return "noch \(hours) Std"
        default: return "noch \(hours) Std \(rest) Min"
        }
    }

    /// "17:00"
    public static func clockText(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// Quantises a timer fraction for the menu bar icon; never 0 while running.
    public static func iconLevel(_ fraction: Double, steps: Int = 8) -> Double {
        let level = (fraction * Double(steps)).rounded(.up) / Double(steps)
        return min(1, max(1 / Double(steps), level))
    }
}
