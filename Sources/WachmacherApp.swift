import SwiftUI
import IOKit.pwr_mgt
import ServiceManagement
import ApplicationServices

/// Keeps the Mac awake: holds a display-sleep assertion, periodically declares
/// user activity (resets the idle timer, no permissions needed) and optionally
/// nudges the mouse by one pixel when the user is idle.
@MainActor
@Observable
final class Waker {
    private(set) var isActive = false
    private(set) var since: Date?

    var moveMouse: Bool = UserDefaults.standard.bool(forKey: "moveMouse") {
        didSet {
            UserDefaults.standard.set(moveMouse, forKey: "moveMouse")
            if moveMouse { Self.requestAccessibility() }
        }
    }

    var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Launch at login failed: \(error)")
            }
        }
    }

    private var displayAssertion: IOPMAssertionID = 0
    private var activityAssertion: IOPMAssertionID = 0
    private var loop: Task<Void, Never>?

    private static let interval: Duration = .seconds(30)
    private static let idleThreshold: TimeInterval = 25

    init() {
        setActive(true)
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        active ? start() : stop()
    }

    private func start() {
        since = .now
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Wachmacher hält den Mac wach" as CFString,
            &displayAssertion
        )
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: Self.interval)
            }
        }
    }

    private func stop() {
        since = nil
        loop?.cancel()
        loop = nil
        if displayAssertion != 0 {
            IOPMAssertionRelease(displayAssertion)
            displayAssertion = 0
        }
        if activityAssertion != 0 {
            IOPMAssertionRelease(activityAssertion)
            activityAssertion = 0
        }
    }

    private func tick() {
        // Resets the system idle timer (prevents screen saver / lock).
        IOPMAssertionDeclareUserActivity(
            "Wachmacher" as CFString,
            kIOPMUserActiveLocal,
            &activityAssertion
        )
        if moveMouse && AXIsProcessTrusted() && Self.userIdleSeconds() >= Self.idleThreshold {
            Self.jiggleMouse()
        }
    }

    private static func userIdleSeconds() -> TimeInterval {
        let anyInput = CGEventType(rawValue: ~0)!
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    private static func jiggleMouse() {
        guard let origin = CGEvent(source: nil)?.location else { return }
        let nudged = CGPoint(x: origin.x + 1, y: origin.y + 1)
        for point in [nudged, origin] {
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                    mouseCursorPosition: point, mouseButton: .left)?
                .post(tap: .cghidEventTap)
        }
    }

    private static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

@main
struct WachmacherApp: App {
    @State private var waker = Waker()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(waker: waker)
        } label: {
            Image(systemName: waker.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                .accessibilityLabel(waker.isActive ? "Wachmacher aktiv" : "Wachmacher pausiert")
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    @Bindable var waker: Waker

    var body: some View {
        Toggle("Mac wach halten", isOn: Binding(
            get: { waker.isActive },
            set: { waker.setActive($0) }
        ))
        .keyboardShortcut("w")

        if let since = waker.since {
            Text("Wach seit \(since.formatted(date: .omitted, time: .shortened)) Uhr ☕️")
        } else {
            Text("Pausiert – der Mac darf schlafen 💤")
        }

        Divider()

        Toggle("Maus bewegen, wenn inaktiv", isOn: $waker.moveMouse)
        Toggle("Beim Anmelden starten", isOn: $waker.launchAtLogin)

        Divider()

        Button("Beenden") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
