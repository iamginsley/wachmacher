import AppKit
import WachmacherCore

/// Menu bar item: left click toggles, right click (or ⌃-click) opens the menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let controller: AwakeController
    private let openSettings: () -> Void
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    private static let durations: [(String, TimeInterval)] = [
        ("15 Minuten", 15 * 60),
        ("30 Minuten", 30 * 60),
        ("1 Stunde", 60 * 60),
        ("2 Stunden", 2 * 60 * 60),
        ("4 Stunden", 4 * 60 * 60),
    ]

    init(controller: AwakeController, openSettings: @escaping () -> Void) {
        self.controller = controller
        self.openSettings = openSettings
        super.init()
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        refresh()
    }

    func refresh() {
        guard let button = item.button else { return }
        let state = controller.state
        button.image = CupIcon.image(level: iconLevel(for: state))
        button.appearsDisabled = { if case .pausedForBattery = state { true } else { false } }()
        let status = statusText(for: state)
        button.toolTip = "Wachmacher – \(status)\nKlick: an/aus · Rechtsklick: Menü"
        button.setAccessibilityLabel("Wachmacher")
        button.setAccessibilityValue(status)
        button.setAccessibilityHelp("Klicken zum Ein- und Ausschalten, Rechtsklick für das Menü")
    }

    // MARK: Click handling

    @objc private func clicked() {
        guard let event = NSApp.currentEvent else { return }
        let wantsMenu = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if wantsMenu {
            item.menu = buildMenu()
            item.button?.performClick(nil)
        } else {
            controller.toggle()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        item.menu = nil
    }

    // MARK: Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        let state = controller.state

        let status = NSMenuItem(title: statusText(for: state), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let toggle = action("Mac wach halten", #selector(toggleAwake), key: "w")
        toggle.state = state.keepsAwake ? .on : .off
        menu.addItem(toggle)

        let timerItem = NSMenuItem(title: "Wach halten für", action: nil, keyEquivalent: "")
        let timerMenu = NSMenu()
        for (index, entry) in Self.durations.enumerated() {
            let entryItem = action(entry.0, #selector(startTimer(_:)))
            entryItem.tag = index
            timerMenu.addItem(entryItem)
        }
        timerMenu.addItem(.separator())
        let endMinutes = controller.preferences.workdayEndMinutes
        let workday = action("Bis Feierabend (\(TimeHelpers.clockText(minutes: endMinutes)))",
                             #selector(startUntilWorkdayEnd))
        workday.isEnabled = TimeHelpers.endOfWorkday(minutes: endMinutes, now: .now) != nil
        timerMenu.addItem(workday)
        timerMenu.addItem(action("Unbegrenzt", #selector(startUnlimited)))
        timerMenu.autoenablesItems = false
        timerItem.submenu = timerMenu
        menu.addItem(timerItem)

        menu.addItem(.separator())
        let mouse = action("Maus bewegen, wenn inaktiv", #selector(toggleMouse))
        mouse.state = controller.preferences.moveMouse ? .on : .off
        menu.addItem(mouse)
        menu.addItem(action("Einstellungen …", #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Wachmacher beenden",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    @objc private func toggleAwake() { controller.toggle() }

    @objc private func startTimer(_ sender: NSMenuItem) {
        controller.start(until: .now.addingTimeInterval(Self.durations[sender.tag].1))
    }

    @objc private func startUntilWorkdayEnd() {
        let minutes = controller.preferences.workdayEndMinutes
        if let end = TimeHelpers.endOfWorkday(minutes: minutes, now: .now) {
            controller.start(until: end)
        }
    }

    @objc private func startUnlimited() { controller.start(until: nil) }

    @objc private func toggleMouse() {
        controller.preferences.moveMouse.toggle()
        if controller.preferences.moveMouse { PowerService.requestAccessibility() }
    }

    @objc private func showSettings() { openSettings() }

    // MARK: Presentation

    private func iconLevel(for state: AwakeState) -> Double? {
        switch state {
        case .off, .pausedForBattery: nil
        case .app: 1
        case .manual(let session):
            session.fractionRemaining(at: .now).map { TimeHelpers.iconLevel($0) } ?? 1
        }
    }

    private func statusText(for state: AwakeState) -> String {
        switch state {
        case .off:
            return "Aus – der Mac darf schlafen 💤"
        case .manual(let session):
            if let end = session.end {
                let clock = end.formatted(date: .omitted, time: .shortened)
                return "Wach bis \(clock) Uhr · \(TimeHelpers.remainingText(until: end, now: .now))"
            }
            return "Wach seit \(session.start.formatted(date: .omitted, time: .shortened)) Uhr ☕️"
        case .app(let app):
            let condition = controller.preferences.triggerMode == .frontmost ? "im Vordergrund ist" : "geöffnet ist"
            return "Wach, weil \(app.name) \(condition)"
        case .pausedForBattery(let percent):
            return "Pausiert – Akku bei \(percent) % 🪫"
        }
    }
}
