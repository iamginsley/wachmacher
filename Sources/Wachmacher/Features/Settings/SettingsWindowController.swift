import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let controller: AwakeController
    private var window: NSWindow?

    init(controller: AwakeController) {
        self.controller = controller
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(preferences: controller.preferences, controller: controller)
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
