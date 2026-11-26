import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let controller: AwakeController
    private let updates: UpdateService
    private var window: NSWindow?

    init(controller: AwakeController, updates: UpdateService) {
        self.controller = controller
        self.updates = updates
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(preferences: controller.preferences, controller: controller, updates: updates)
            )
            let window = NSWindow(contentViewController: hosting)
            window.title = "Wachmacher – Einstellungen"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
