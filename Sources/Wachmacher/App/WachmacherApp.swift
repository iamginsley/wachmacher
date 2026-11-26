import AppKit

@main
enum WachmacherApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AwakeController?
    private var statusItem: StatusItemController?
    private var settings: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = AwakeController(preferences: Preferences())
        let settings = SettingsWindowController(controller: controller)
        let statusItem = StatusItemController(controller: controller) { settings.show() }
        controller.onUpdate = { [weak statusItem] in statusItem?.refresh() }
        self.controller = controller
        self.settings = settings
        self.statusItem = statusItem
    }

    /// Opening the app again (Finder, Spotlight) shows the settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings?.show()
        return false
    }
}
