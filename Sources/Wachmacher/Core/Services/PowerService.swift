import AppKit
import ApplicationServices
import IOKit.ps
import IOKit.pwr_mgt
import WachmacherCore

/// Talks to IOKit: display-sleep assertion, user-activity pings, battery state
/// and the optional mouse nudge.
@MainActor
final class PowerService {
    private var displayAssertion: IOPMAssertionID = 0
    private var activityAssertion: IOPMAssertionID = 0

    var isHoldingDisplay: Bool { displayAssertion != 0 }

    func holdDisplay(_ hold: Bool) {
        if hold, displayAssertion == 0 {
            IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Wachmacher hält den Mac wach" as CFString,
                &displayAssertion
            )
        } else if !hold {
            release(&displayAssertion)
            release(&activityAssertion)
        }
    }

    /// Resets the system idle timer (prevents screen saver and lock).
    func declareUserActivity() {
        IOPMAssertionDeclareUserActivity("Wachmacher" as CFString, kIOPMUserActiveLocal, &activityAssertion)
    }

    private func release(_ id: inout IOPMAssertionID) {
        if id != 0 {
            IOPMAssertionRelease(id)
            id = 0
        }
    }

    // MARK: Battery

    /// Internal battery state, or nil on Macs without a battery.
    static func battery() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = desc[kIOPSCurrentCapacityKey] as? Int,
                  let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            let onBattery = desc[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue
            return BatteryStatus(percent: current * 100 / max, onBattery: onBattery)
        }
        return nil
    }

    // MARK: Mouse

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func userIdleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    /// Moves the pointer one pixel and back – looks like real input to other apps.
    static func nudgeMouse() {
        guard let origin = CGEvent(source: nil)?.location else { return }
        for point in [CGPoint(x: origin.x + 1, y: origin.y + 1), origin] {
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                    mouseCursorPosition: point, mouseButton: .left)?
                .post(tap: .cghidEventTap)
        }
    }
}
