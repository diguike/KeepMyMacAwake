import XCTest
import IOKit.pwr_mgt
import AppKit
@testable import AwakeApp
import AwakeShared
import AwakeCore

final class NativeSessionTests: XCTestCase {
    private func ownAssertions() throws -> [[String: Any]] {
        var values: Unmanaged<CFDictionary>?
        XCTAssertEqual(IOPMCopyAssertionsByProcess(&values), kIOReturnSuccess)
        let assertions = try XCTUnwrap(values?.takeRetainedValue() as? [NSNumber: [[String: Any]]])
        return assertions[NSNumber(value: ProcessInfo.processInfo.processIdentifier)] ?? []
    }
    func testRealSystemAndDisplayAssertionsAreReleased() throws {
        let assertion = IdleAssertion()
        defer { try? assertion.stop() }
        try assertion.start(keepDisplay: true)
        let created = try ownAssertions().filter { ($0[kIOPMAssertionNameKey as String] as? String)?.hasPrefix("KeepMyMacAwake") == true }
        XCTAssertEqual(created.count, 2)
        XCTAssertEqual(Set(created.compactMap { $0[kIOPMAssertionTypeKey as String] as? String }),
                       Set(["PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep"]))
        try assertion.stop()
        XCTAssertTrue(try ownAssertions().filter { ($0[kIOPMAssertionNameKey as String] as? String)?.hasPrefix("KeepMyMacAwake") == true }.isEmpty)
    }
    func testLiveSleepDisabledFlagCanBeReadWithoutMutation() throws {
        XCTAssertNoThrow(try SleepState.readDisabled())
    }
    func testSystemOnlySessionDoesNotHoldDisplayAwake() throws {
        let assertion = IdleAssertion()
        defer { try? assertion.stop() }
        try assertion.start()
        let created = try ownAssertions().filter { ($0[kIOPMAssertionNameKey as String] as? String)?.hasPrefix("KeepMyMacAwake") == true }
        XCTAssertEqual(created.count, 1)
        XCTAssertEqual(created.first?[kIOPMAssertionTypeKey as String] as? String, "PreventUserIdleSystemSleep")
    }
    @MainActor func testUnlimitedAppSessionCanStopWithoutHelper() async throws {
        let model = AppModel(defaults: nil, sample: { PowerSample(onAC: true, batteryPercent: 80, thermal: .nominal) })
        model.onboarded = true; model.requireAC = false; model.durationMinutes = -1
        await model.start()
        XCTAssertTrue(model.active, model.message); XCTAssertTrue(model.unlimitedSession)
        await model.refresh()
        XCTAssertTrue(model.active, model.message)
        let stopped = await model.stop()
        XCTAssertTrue(stopped, model.message); XCTAssertFalse(model.hasSession)
    }
    @MainActor func testScenesConfigureExpectedConditions() {
        let model = AppModel(defaults: nil)
        model.chooseScene("夜间")
        XCTAssertTrue(model.nightMode); XCTAssertFalse(model.lidMode); XCTAssertEqual(model.durationMinutes, 480)
        model.chooseScene("接电合盖")
        XCTAssertTrue(model.lidMode); XCTAssertTrue(model.requireAC); XCTAssertEqual(model.durationMinutes, -1)
        model.chooseScene("有网时")
        XCTAssertTrue(model.lidMode); XCTAssertTrue(model.requireNetwork); XCTAssertFalse(model.requireAC)
        model.chooseScene("日常")
        XCTAssertFalse(model.lidMode); XCTAssertFalse(model.requireNetwork); XCTAssertFalse(model.nightMode)
    }
    @MainActor func testNightOverlayLeavesNoVisibleWindowsAfterStop() throws {
        guard !NSScreen.screens.isEmpty else { throw XCTSkip("No display attached to test host") }
        _ = NSApplication.shared
        let dimmer = NightDimmer()
        let before = Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber))
        dimmer.start(amount: 0.94)
        let overlays = NSApp.windows.filter { $0.isVisible && !before.contains($0.windowNumber) }
        XCTAssertEqual(overlays.count, NSScreen.screens.count)
        XCTAssertTrue(overlays.allSatisfy { $0.ignoresMouseEvents && $0.level.rawValue < NSWindow.Level.statusBar.rawValue })
        dimmer.stop()
        XCTAssertTrue(overlays.allSatisfy { !$0.isVisible })
    }
    @MainActor func testFiniteAppSessionExpiresAndReleasesRealAssertions() async throws {
        var time: Double = 0
        let model = AppModel(defaults: nil, sample: { PowerSample(onAC: true, batteryPercent: 80, thermal: .nominal) },
            clock: { ClockSample(wall: Date(timeIntervalSince1970: 1000 + time), continuous: time) })
        model.onboarded = true; model.durationMinutes = 0; model.customMinutes = 1
        await model.start(); XCTAssertTrue(model.active, model.message)
        time = 61; await model.refresh()
        XCTAssertFalse(model.hasSession); XCTAssertTrue(model.message.contains("设定时间已到"))
        XCTAssertTrue(try ownAssertions().filter { ($0[kIOPMAssertionNameKey as String] as? String)?.hasPrefix("KeepMyMacAwake") == true }.isEmpty)
    }
    @MainActor func testNetworkProtectionEndsRealSessionWithoutAutoRestart() async throws {
        var available = true
        let model = AppModel(defaults: nil, sample: { PowerSample(onAC: false, batteryPercent: 80, thermal: .nominal, networkAvailable: available) })
        model.onboarded = true; model.requireAC = false; model.requireNetwork = true; model.durationMinutes = -1
        await model.start(); XCTAssertTrue(model.active, model.message)
        available = false; await model.refresh(); XCTAssertFalse(model.hasSession)
        available = true; await model.refresh(); XCTAssertFalse(model.hasSession)
    }
    @MainActor func testExtensionCannotReviveExpiredOrdinarySession() async throws {
        var time: Double = 0
        let model = AppModel(defaults: nil, sample: { PowerSample(onAC: true, batteryPercent: 80, thermal: .nominal) },
            clock: { ClockSample(wall: Date(timeIntervalSince1970: 1000 + time), continuous: time) })
        model.onboarded = true; model.durationMinutes = 0; model.customMinutes = 1
        await model.start(); XCTAssertTrue(model.active, model.message)
        time = 61; await model.extendSession()
        XCTAssertFalse(model.hasSession); XCTAssertTrue(model.message.contains("设定时间已到"))
        XCTAssertTrue(try ownAssertions().filter { ($0[kIOPMAssertionNameKey as String] as? String)?.hasPrefix("KeepMyMacAwake") == true }.isEmpty)
    }
    @MainActor func testSavedPreferencesRestoreButNeverResumeSession() throws {
        let suite = "io.github.diguike.KeepMyMacAwake.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = AppModel(defaults: defaults)
        original.chooseScene("有网时"); original.durationMinutes = -1; original.screenMode = "保持常亮"
        original.minimumBattery = 35; original.acknowledge()
        let next = AppModel(defaults: defaults)
        XCTAssertEqual(next.scene, "有网时"); XCTAssertEqual(next.minimumBattery, 35)
        XCTAssertEqual(next.screenMode, "保持常亮"); XCTAssertTrue(next.requireNetwork)
        XCTAssertTrue(next.onboarded); XCTAssertFalse(next.hasSession)
    }

}
