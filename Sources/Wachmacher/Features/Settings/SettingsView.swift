import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WachmacherCore

struct SettingsView: View {
    @Bindable var preferences: Preferences
    let controller: AwakeController
    @State private var hasAccessibility = PowerService.hasAccessibility

    /// Common call and presentation apps offered as one-click suggestions when installed.
    private static let suggestions: [WatchedApp] = [
        WatchedApp(bundleID: "com.microsoft.teams2", name: "Microsoft Teams"),
        WatchedApp(bundleID: "us.zoom.xos", name: "Zoom"),
        WatchedApp(bundleID: "com.cisco.webexmeetingsapp", name: "Webex"),
        WatchedApp(bundleID: "com.apple.iWork.Keynote", name: "Keynote"),
        WatchedApp(bundleID: "com.microsoft.Powerpoint", name: "PowerPoint"),
        WatchedApp(bundleID: "com.apple.FaceTime", name: "FaceTime"),
        WatchedApp(bundleID: "com.apple.QuickTimePlayerX", name: "QuickTime Player"),
    ]

    var body: some View {
        Form {
            generalSection
            batterySection
            appsSection
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .frame(minHeight: 560)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibility = PowerService.hasAccessibility
        }
    }

    // MARK: General

    private var generalSection: some View {
        Section {
            Toggle("Beim Anmelden starten", isOn: $preferences.launchAtLogin)

            Toggle(isOn: $preferences.moveMouse) {
                Text("Maus bewegen, wenn inaktiv")
                Text("Hält auch den Status in Teams, Slack & Co. auf „Verfügbar“.")
            }
            .onChange(of: preferences.moveMouse) { _, isOn in
                if isOn { PowerService.requestAccessibility() }
            }

            if preferences.moveMouse && !hasAccessibility {
                LabeledContent {
                    Button("Freigabe öffnen") { PowerService.openAccessibilitySettings() }
                } label: {
                    Label("Wachmacher braucht die Freigabe unter Bedienungshilfen.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            DatePicker("Feierabend", selection: workdayEnd, displayedComponents: .hourAndMinute)
        } header: {
            Text("Allgemein")
        } footer: {
            Text("Die Feierabend-Zeit nutzt der Timer „Bis Feierabend“ im Menü.")
        }
    }

    private var workdayEnd: Binding<Date> {
        Binding {
            Calendar.current.date(byAdding: .minute, value: preferences.workdayEndMinutes,
                                  to: Calendar.current.startOfDay(for: .now)) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            preferences.workdayEndMinutes = (parts.hour ?? 17) * 60 + (parts.minute ?? 0)
        }
    }

    // MARK: Battery

    private var batterySection: some View {
        Section {
            if let battery = controller.battery {
                Toggle("Bei niedrigem Akku pausieren", isOn: $preferences.batteryProtectionEnabled)
                Stepper(value: $preferences.batteryThreshold, in: 5...50, step: 5) {
                    LabeledContent("Pausieren ab", value: "\(preferences.batteryThreshold) %")
                        .monospacedDigit()
                }
                .disabled(!preferences.batteryProtectionEnabled)
                LabeledContent("Aktuell") {
                    Text("\(battery.percent) % · \(battery.onBattery ? "Akku" : "Netzteil")")
                        .monospacedDigit()
                }
            } else {
                Label("Dieser Mac hat keinen Akku.", systemImage: "powerplug")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Akku")
        } footer: {
            if controller.battery != nil {
                Text("Am Netzteil bleibt Wachmacher immer aktiv.")
            }
        }
    }

    // MARK: Apps

    private var appsSection: some View {
        Section {
            Picker("Automatisch wach, wenn eine App …", selection: $preferences.triggerMode) {
                Text("geöffnet ist").tag(TriggerMode.running)
                Text("im Vordergrund ist").tag(TriggerMode.frontmost)
            }

            if preferences.watchedApps.isEmpty {
                Text("Noch keine Apps. Füge z. B. Teams, Zoom oder Keynote hinzu.")
                    .foregroundStyle(.secondary)
            }
            ForEach(preferences.watchedApps) { app in
                HStack {
                    AppIconView(bundleID: app.bundleID)
                    Text(app.name)
                    Spacer()
                    Button {
                        preferences.watchedApps.removeAll { $0.id == app.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(app.name) entfernen")
                }
            }

            addMenu
        } header: {
            Text("Apps")
        } footer: {
            Text("Ein Klick auf die Tasse schaltet trotzdem aus – bis die App wieder geschlossen wird.")
        }
    }

    private var addMenu: some View {
        Menu("App hinzufügen …") {
            let suggested = installedSuggestions
            if !suggested.isEmpty {
                Section("Vorschläge") {
                    ForEach(suggested) { app in
                        Button(app.name) { add(app) }
                    }
                }
            }
            let running = runningApps
            if !running.isEmpty {
                Section("Geöffnete Apps") {
                    ForEach(running) { app in
                        Button(app.name) { add(app) }
                    }
                }
            }
            Divider()
            Button("Andere App auswählen …", action: chooseApp)
        }
        .fixedSize()
    }

    private var installedSuggestions: [WatchedApp] {
        Self.suggestions.filter { app in
            !isWatched(app.bundleID)
                && NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) != nil
        }
    }

    private var runningApps: [WatchedApp] {
        let ownID = Bundle.main.bundleIdentifier
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> WatchedApp? in
            guard app.activationPolicy == .regular,
                  let id = app.bundleIdentifier, id != ownID, !isWatched(id),
                  let name = app.localizedName
            else { return nil }
            return WatchedApp(bundleID: id, name: name)
        }
        return Array(Set(apps)).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func isWatched(_ bundleID: String) -> Bool {
        preferences.watchedApps.contains { $0.bundleID == bundleID }
    }

    private func add(_ app: WatchedApp) {
        guard !isWatched(app.bundleID) else { return }
        preferences.watchedApps.append(app)
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "Hinzufügen"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { continue }
            let name = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            add(WatchedApp(bundleID: id, name: name))
        }
    }
}

private struct AppIconView: View {
    let bundleID: String

    var body: some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}
