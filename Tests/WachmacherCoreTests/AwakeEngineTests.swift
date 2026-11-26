import Foundation
import Testing
@testable import WachmacherCore

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private let teams = WatchedApp(bundleID: "com.microsoft.teams2", name: "Teams")
private let protectionOn = BatteryProtection(isEnabled: true, threshold: 20)
private let protectionOff = BatteryProtection(isEnabled: false, threshold: 20)

@Suite("AwakeEngine")
struct AwakeEngineTests {
    @Test func offByDefault() {
        let engine = AwakeEngine()
        #expect(engine.state(at: t0, activeApp: nil, battery: nil, protection: protectionOn) == .off)
    }

    @Test func manualUnlimited() {
        var engine = AwakeEngine()
        engine.start(at: t0)
        let state = engine.state(at: t0 + 86_400, activeApp: nil, battery: nil, protection: protectionOn)
        #expect(state == .manual(ManualSession(start: t0)))
    }

    @Test func timerExpires() {
        var engine = AwakeEngine()
        engine.start(at: t0, until: t0 + 1800)
        #expect(engine.state(at: t0 + 1799, activeApp: nil, battery: nil, protection: protectionOn).keepsAwake)
        #expect(engine.state(at: t0 + 1800, activeApp: nil, battery: nil, protection: protectionOn) == .off)
        engine.refresh(at: t0 + 1800, activeApp: nil)
        #expect(engine.manual == nil)
    }

    @Test func watchedAppKeepsAwake() {
        let engine = AwakeEngine()
        #expect(engine.state(at: t0, activeApp: teams, battery: nil, protection: protectionOn) == .app(teams))
    }

    @Test func manualWinsOverApp() {
        var engine = AwakeEngine()
        engine.start(at: t0)
        let state = engine.state(at: t0, activeApp: teams, battery: nil, protection: protectionOn)
        #expect(state == .manual(ManualSession(start: t0)))
    }

    @Test func timerEndingFallsBackToApp() {
        var engine = AwakeEngine()
        engine.start(at: t0, until: t0 + 60)
        #expect(engine.state(at: t0 + 61, activeApp: teams, battery: nil, protection: protectionOn) == .app(teams))
    }

    @Test func lowBatteryPauses() {
        var engine = AwakeEngine()
        engine.start(at: t0)
        let low = BatteryStatus(percent: 20, onBattery: true)
        #expect(engine.state(at: t0, activeApp: nil, battery: low, protection: protectionOn)
                == .pausedForBattery(percent: 20))
        #expect(engine.state(at: t0, activeApp: teams, battery: low, protection: protectionOn)
                == .pausedForBattery(percent: 20))
    }

    @Test func lowBatteryIgnoredWhenChargingOrDisabled() {
        var engine = AwakeEngine()
        engine.start(at: t0)
        let charging = BatteryStatus(percent: 5, onBattery: false)
        let low = BatteryStatus(percent: 5, onBattery: true)
        #expect(engine.state(at: t0, activeApp: nil, battery: charging, protection: protectionOn).keepsAwake)
        #expect(engine.state(at: t0, activeApp: nil, battery: low, protection: protectionOff).keepsAwake)
    }

    @Test func batteryAboveThresholdKeepsAwake() {
        var engine = AwakeEngine()
        engine.start(at: t0)
        let ok = BatteryStatus(percent: 21, onBattery: true)
        #expect(engine.state(at: t0, activeApp: nil, battery: ok, protection: protectionOn).keepsAwake)
    }

    @Test func lowBatteryWhileOffStaysOff() {
        let engine = AwakeEngine()
        let low = BatteryStatus(percent: 5, onBattery: true)
        #expect(engine.state(at: t0, activeApp: nil, battery: low, protection: protectionOn) == .off)
    }

    @Test func toggleOnAndOff() {
        var engine = AwakeEngine()
        engine.toggle(at: t0, activeApp: nil, current: .off)
        let on = engine.state(at: t0, activeApp: nil, battery: nil, protection: protectionOn)
        #expect(on.keepsAwake)
        engine.toggle(at: t0, activeApp: nil, current: on)
        #expect(engine.state(at: t0, activeApp: nil, battery: nil, protection: protectionOn) == .off)
    }

    @Test func toggleOffOverridesAppUntilItCloses() {
        var engine = AwakeEngine()
        engine.toggle(at: t0, activeApp: teams, current: .app(teams))
        #expect(engine.state(at: t0, activeApp: teams, battery: nil, protection: protectionOn) == .off)

        // Still open → stays overridden.
        engine.refresh(at: t0 + 60, activeApp: teams)
        #expect(engine.state(at: t0 + 60, activeApp: teams, battery: nil, protection: protectionOn) == .off)

        // App closed and reopened → triggers again.
        engine.refresh(at: t0 + 120, activeApp: nil)
        #expect(engine.state(at: t0 + 180, activeApp: teams, battery: nil, protection: protectionOn) == .app(teams))
    }

    @Test func startingManuallyClearsOverride() {
        var engine = AwakeEngine()
        engine.stop(activeApp: teams)
        engine.start(at: t0, until: t0 + 60)
        engine.refresh(at: t0 + 61, activeApp: teams)
        #expect(engine.state(at: t0 + 61, activeApp: teams, battery: nil, protection: protectionOn) == .app(teams))
    }
}

@Suite("ManualSession")
struct ManualSessionTests {
    @Test func fractionRemaining() {
        let session = ManualSession(start: t0, end: t0 + 1000)
        #expect(session.fractionRemaining(at: t0) == 1)
        #expect(session.fractionRemaining(at: t0 + 250) == 0.75)
        #expect(session.fractionRemaining(at: t0 + 2000) == 0)
        #expect(ManualSession(start: t0).fractionRemaining(at: t0) == nil)
    }
}

@Suite("TimeHelpers")
struct TimeHelpersTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna")!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: hour, minute: minute))!
    }

    @Test func endOfWorkdayLaterToday() {
        #expect(TimeHelpers.endOfWorkday(minutes: 17 * 60, now: date(9, 0), calendar: calendar) == date(17, 0))
    }

    @Test func endOfWorkdayAlreadyPassed() {
        #expect(TimeHelpers.endOfWorkday(minutes: 17 * 60, now: date(17, 0), calendar: calendar) == nil)
        #expect(TimeHelpers.endOfWorkday(minutes: 17 * 60, now: date(18, 30), calendar: calendar) == nil)
    }

    @Test func remainingText() {
        #expect(TimeHelpers.remainingText(until: t0 + 42 * 60, now: t0) == "noch 42 Min")
        #expect(TimeHelpers.remainingText(until: t0 + 65 * 60, now: t0) == "noch 1 Std 5 Min")
        #expect(TimeHelpers.remainingText(until: t0 + 120 * 60, now: t0) == "noch 2 Std")
        #expect(TimeHelpers.remainingText(until: t0 + 10, now: t0) == "noch 1 Min")
    }

    @Test func clockText() {
        #expect(TimeHelpers.clockText(minutes: 17 * 60) == "17:00")
        #expect(TimeHelpers.clockText(minutes: 8 * 60 + 5) == "08:05")
    }

    @Test func iconLevel() {
        #expect(TimeHelpers.iconLevel(1) == 1)
        #expect(TimeHelpers.iconLevel(0.5) == 0.5)
        #expect(TimeHelpers.iconLevel(0.51) == 0.625)
        #expect(TimeHelpers.iconLevel(0) == 0.125)
    }
}
