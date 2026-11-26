import AppKit
import Observation
import WachmacherCore

/// Ties the engine to the real world: clock, battery, running apps, power assertions.
@MainActor
@Observable
final class AwakeController {
    let preferences: Preferences
    private(set) var state: AwakeState = .off
    private(set) var battery: BatteryStatus?

    @ObservationIgnored var onUpdate: (() -> Void)?
    @ObservationIgnored private var engine = AwakeEngine()
    @ObservationIgnored private let power = PowerService()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private static let tickInterval: Duration = .seconds(15)
    private static let mouseIdleThreshold: TimeInterval = 25

    init(preferences: Preferences) {
        self.preferences = preferences
        preferences.onChange = { [weak self] in self?.evaluate() }
        observeWorkspace()
        engine.start(at: .now)
        evaluate()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tickInterval)
                self?.tick()
            }
        }
    }

    // MARK: Actions

    func toggle() {
        engine.toggle(at: .now, activeApp: activeWatchedApp(), current: state)
        evaluate()
    }

    func start(until end: Date?) {
        engine.start(at: .now, until: end)
        evaluate()
    }

    func stop() {
        engine.stop(activeApp: activeWatchedApp())
        evaluate()
    }

    // MARK: Evaluation

    func evaluate() {
        let now = Date.now
        let app = activeWatchedApp()
        battery = PowerService.battery()
        engine.refresh(at: now, activeApp: app)
        let newState = engine.state(
            at: now, activeApp: app, battery: battery, protection: preferences.batteryProtection
        )
        let wasAwake = state.keepsAwake
        state = newState
        power.holdDisplay(newState.keepsAwake)
        if newState.keepsAwake && !wasAwake { power.declareUserActivity() }
        onUpdate?()
    }

    private func tick() {
        evaluate()
        guard state.keepsAwake else { return }
        power.declareUserActivity()
        if preferences.moveMouse, PowerService.hasAccessibility,
           PowerService.userIdleSeconds() >= Self.mouseIdleThreshold {
            PowerService.nudgeMouse()
        }
    }

    // MARK: Watched apps

    func activeWatchedApp() -> WatchedApp? {
        let watched = preferences.watchedApps
        guard !watched.isEmpty else { return nil }
        let workspace = NSWorkspace.shared
        switch preferences.triggerMode {
        case .frontmost:
            guard let id = workspace.frontmostApplication?.bundleIdentifier else { return nil }
            return watched.first { $0.bundleID == id }
        case .running:
            let running = Set(workspace.runningApplications.compactMap(\.bundleIdentifier))
            return watched.first { running.contains($0.bundleID) }
        }
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didWakeNotification,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            }
        }
    }
}
