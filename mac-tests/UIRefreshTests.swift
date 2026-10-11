import XCTest
import Combine
import AppKit
import ServiceManagement
import AwakeCore
import AwakeShared
@testable import AwakeApp

final class UIRefreshTests: XCTestCase {
    private let sample = PowerSample(onAC: true, batteryPercent: 80, thermal: .nominal, networkAvailable: true)

    @MainActor func testFiveMinutesOfUnchangedIdleSamplesDoNotPublishUIChanges() async {
        var time: Double = 0
        let sample = self.sample
        let model = AppModel(defaults: nil, sample: { sample },
            clock: { ClockSample(wall: Date(timeIntervalSince1970: 1000 + time), continuous: time) },
            helperStatus: { .notRegistered }, startMonitoring: false)
        await model.refresh()
        var changes = 0
        let observation = model.objectWillChange.sink { changes += 1 }
        for second in 1...300 { time = Double(second); await model.refresh() }
        XCTAssertEqual(changes, 0)
        XCTAssertFalse(model.busy)
        withExtendedLifetime(observation) {}
    }

    @MainActor func testUnchangedHelperPollsDoNotPublishUIChanges() async {
        var time: Double = 0
        var requests = 0
        let sample = self.sample
        let model = AppModel(defaults: nil, sample: { sample },
            clock: { ClockSample(wall: Date(timeIntervalSince1970: 1000 + time), continuous: time) },
            helperStatus: { .enabled }, helperRequest: { _ in
                requests += 1
                return HelperReply(status: SessionStatus(), sample: sample)
            }, startMonitoring: false)
        await model.refresh()
        var changes = 0
        let observation = model.objectWillChange.sink { changes += 1 }
        for second in 1...300 { time = Double(second); await model.refresh() }
        XCTAssertEqual(requests, 61, "Independent monitoring must continue every five seconds")
        XCTAssertEqual(changes, 0)
        XCTAssertTrue(model.helperConnected)
        withExtendedLifetime(observation) {}
    }

    @MainActor func testUnlimitedOrdinarySessionDoesNotPublishUnchangedCountdown() async {
        let sample = self.sample
        let model = AppModel(defaults: nil, sample: { sample }, helperStatus: { .notRegistered }, startMonitoring: false)
        model.onboarded = true; model.durationMinutes = -1
        await model.start()
        XCTAssertTrue(model.active, model.message)
        var changes = 0
        let observation = model.objectWillChange.sink { changes += 1 }
        for _ in 0..<30 { await model.refresh() }
        XCTAssertEqual(changes, 0)
        XCTAssertTrue(model.active)
        let stopped = await model.stop()
        XCTAssertTrue(stopped, model.message)
        withExtendedLifetime(observation) {}
    }

    @MainActor func testPendingPollAllowsStartAndItsLateOffReplyCannotClearNewSession() async throws {
        let sample = self.sample
        var pending: CheckedContinuation<HelperReply, Error>?
        let model = AppModel(defaults: nil, sample: { sample }, helperStatus: { .enabled },
            helperRequest: { _ in try await withCheckedThrowingContinuation { pending = $0 } },
            startMonitoring: false)
        model.onboarded = true; model.durationMinutes = -1
        let poll = Task { await model.refresh() }
        for _ in 0..<1000 { if pending != nil { break }; await Task.yield() }
        let reply = try XCTUnwrap(pending)
        XCTAssertFalse(model.busy, "A background poll must not disable user controls")
        await model.start()
        let wasActive = model.active
        reply.resume(returning: HelperReply(status: SessionStatus(), sample: sample))
        await poll.value
        XCTAssertTrue(wasActive)
        XCTAssertTrue(model.active, "An older off reply must not stop the new ordinary session")
        XCTAssertTrue(model.hasSession)
        let stopped = await model.stop()
        XCTAssertTrue(stopped, model.message)
    }

    @MainActor func testLateRenewReplyCannotResurrectStoppedHelperSession() async throws {
        let sample = self.sample
        let id = UUID()
        var time: Double = 0
        var pending: CheckedContinuation<HelperReply, Error>?
        let model = AppModel(defaults: nil, sample: { sample },
            clock: { ClockSample(wall: Date(timeIntervalSince1970: 1000 + time), continuous: time) },
            helperStatus: { .enabled }, helperRequest: { request in
                switch request.operation {
                case .acquire: return HelperReply(status: SessionStatus(phase: .active, leaseID: id, remainingSeconds: 60), sample: sample)
                case .renew: return try await withCheckedThrowingContinuation { pending = $0 }
                default: return HelperReply(status: SessionStatus(), sample: sample)
                }
            }, startMonitoring: false)
        model.onboarded = true; model.lidMode = true
        await model.start(); XCTAssertTrue(model.active, model.message)
        time = 5
        let poll = Task { await model.refresh() }
        for _ in 0..<1000 { if pending != nil { break }; await Task.yield() }
        let reply = try XCTUnwrap(pending)
        XCTAssertFalse(model.busy)
        let stopped = await model.stop()
        reply.resume(returning: HelperReply(status: SessionStatus(phase: .active, leaseID: id, remainingSeconds: 55), sample: sample))
        await poll.value
        XCTAssertTrue(stopped, model.message)
        XCTAssertFalse(model.hasSession)
        XCTAssertFalse(model.active)
        XCTAssertEqual(model.remaining, 0)
        XCTAssertEqual(model.message, "已停止本应用保活，设置已恢复")
    }

    @MainActor func testRepeatedScreenNotificationsAndDimAdjustmentReuseVisibleOverlays() async throws {
        guard !NSScreen.screens.isEmpty else { throw XCTSkip("No display attached to test host") }
        _ = NSApplication.shared
        let before = Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber))
        let dimmer = NightDimmer()
        defer { dimmer.stop() }
        dimmer.start(amount: 0.94)
        let overlays = NSApp.windows.filter { $0.isVisible && !before.contains($0.windowNumber) }
        let original = Set(overlays.map(\.windowNumber))
        XCTAssertEqual(original.count, NSScreen.screens.count)
        for _ in 0..<30 {
            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
            await Task.yield()
        }
        dimmer.start(amount: 0.90)
        let current = Set(NSApp.windows.filter { $0.isVisible && !before.contains($0.windowNumber) }.map(\.windowNumber))
        XCTAssertEqual(current, original, "Repeated notifications must not replace and flash overlays")
        XCTAssertTrue(overlays.allSatisfy { $0.isVisible && abs($0.backgroundColor.alphaComponent - 0.90) < 0.001 })
    }

    @MainActor func testQueuedScreenNotificationCannotRecreateOverlaysAfterStop() async throws {
        guard !NSScreen.screens.isEmpty else { throw XCTSkip("No display attached to test host") }
        _ = NSApplication.shared
        let before = Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber))
        let dimmer = NightDimmer()
        defer { dimmer.stop() }
        dimmer.start(amount: 0.94)
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
        dimmer.stop()
        for _ in 0..<30 { await Task.yield() }
        let after = Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber))
        XCTAssertEqual(after, before, "Queued work must respect a session that has already stopped")
    }
}
