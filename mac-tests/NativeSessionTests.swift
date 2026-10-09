import XCTest
import IOKit.pwr_mgt
import AppKit
@testable import AwakeApp
import AwakeShared

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
        let model = AppModel()
        model.onboarded = true; model.requireAC = false; model.durationMinutes = -1
        await model.start()
        XCTAssertTrue(model.active, model.message); XCTAssertTrue(model.unlimitedSession)
        await model.refresh()
        XCTAssertTrue(model.active, model.message)
        let stopped = await model.stop()
        XCTAssertTrue(stopped, model.message); XCTAssertFalse(model.hasSession)
    }
    @MainActor func testScenesConfigureExpectedConditions() {
        let model = AppModel()
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
}
