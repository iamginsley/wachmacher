import AppKit
import Observation
import Sparkle

/// Automatic updates via Sparkle. The feed URL and public key live in Info.plist (scripts/build.sh).
@MainActor
@Observable
final class UpdateService: NSObject, SPUStandardUserDriverDelegate {
    @ObservationIgnored private var controller: SPUStandardUpdaterController!

    var automaticallyChecks: Bool {
        get {
            access(keyPath: \.automaticallyChecks)
            return controller.updater.automaticallyChecksForUpdates
        }
        set {
            withMutation(keyPath: \.automaticallyChecks) {
                controller.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    var canCheck: Bool { controller.updater.canCheckForUpdates }

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self
        )
    }

    func checkForUpdates() {
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    // MARK: SPUStandardUserDriverDelegate

    // Menu bar apps have no Dock icon, so scheduled update alerts would show up behind other
    // windows. Gentle reminders let Sparkle show them without stealing focus; bring the app
    // forward only when the user is about to see the update window.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        guard handleShowingUpdate else { return }
        MainActor.assumeIsolated { NSApp.activate() }
    }
}
