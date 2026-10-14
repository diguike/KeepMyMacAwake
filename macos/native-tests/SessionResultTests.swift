import XCTest
import ServiceManagement
@testable import AwakeApp
import AwakeCore

final class SessionResultTests: XCTestCase {
    @MainActor func testCompletedResultSurvivesRestartWithoutResumingOrNotifying() async throws {
        let suite = "io.github.diguike.KeepMyMacAwake.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var time: Double = 0
        var notifications = 0
        func model() -> AppModel {
            AppModel(defaults: defaults, sample: { PowerSample(onAC: true, batteryPercent: 90, thermal: .nominal) },
                     clock: { ClockSample(wall: Date(timeIntervalSince1970: 1_792_000_000 + time), continuous: time) },
                     helperStatus: { .notRegistered }, notifyEnd: { _ in notifications += 1 },
                     enableNotifications: { true }, startMonitoring: false)
        }
        let original = model(); original.acknowledge(); original.durationMinutes = 1
        await original.setNotifications(true); await original.start()
        time = 60; await original.refresh(); await original.refresh()
        XCTAssertEqual(notifications, 1)
        let next = model()
        XCTAssertEqual(next.lastResult, original.lastResult)
        XCTAssertEqual(next.lastSession?.reason, StopReason.expired.message)
        XCTAssertFalse(next.hasSession); XCTAssertEqual(notifications, 1)
        next.chooseScene("有网时")
        XCTAssertEqual(next.sceneDisplayName, "外出合盖"); XCTAssertEqual(next.scene, "有网时")
    }
    @MainActor func testDefaultAndDeniedNotificationsNeverSend() async throws {
        var sent = 0
        let model = AppModel(defaults: nil, sample: { PowerSample(onAC: true, batteryPercent: 90, thermal: .nominal) },
                             helperStatus: { .notRegistered }, notifyEnd: { _ in sent += 1 },
                             enableNotifications: { false }, startMonitoring: false)
        model.onboarded = true
        XCTAssertFalse(model.notifyOnEnd)
        await model.setNotifications(true); XCTAssertFalse(model.notifyOnEnd)
        await model.start(); let stopped = await model.stop()
        XCTAssertTrue(stopped); XCTAssertEqual(sent, 0)
    }
    @MainActor func testCorruptHistoryDoesNotRestoreSession() throws {
        let suite = "io.github.diguike.KeepMyMacAwake.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("invalid".utf8), forKey: "lastResult.v1")
        let model = AppModel(defaults: defaults, helperStatus: { .notRegistered }, startMonitoring: false)
        XCTAssertNil(model.lastResult); XCTAssertFalse(model.hasSession)
    }
    @MainActor func testUnknownPowerIsNotReady() async {
        let model = AppModel(defaults: nil, sample: { PowerSample(onAC: nil, batteryPercent: nil, thermal: .unknown) },
                             helperStatus: { .notRegistered }, startMonitoring: false)
        // Refresh uses the injected monitor, rather than a fabricated ready state.
        await model.refresh()
        XCTAssertNotEqual(model.readinessTitle, "未开启")
        XCTAssertEqual(model.readinessTitle, StopReason.telemetryUnknown.message)
        // Unknown values stay visibly unknown in the menu bar panel.
        XCTAssertEqual(model.powerText, "未知"); XCTAssertEqual(model.networkText, "未知"); XCTAssertEqual(model.thermalDescription, "未知")
    }
    @MainActor func testMenuBarInfoFollowsSessionPhase() async throws {
        let suite = "io.github.diguike.KeepMyMacAwake.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var time: Double = 0
        let model = AppModel(defaults: defaults, sample: { PowerSample(onAC: false, batteryPercent: 64, thermal: .fair, networkAvailable: true) },
                             clock: { ClockSample(wall: Date(timeIntervalSince1970: 1_792_000_000 + time), continuous: time) },
                             helperStatus: { .notRegistered }, startMonitoring: false)
        model.acknowledge(); model.requireAC = false; model.durationMinutes = 30
        await model.refresh()
        XCTAssertEqual(model.phase, .off); XCTAssertEqual(model.phaseText, "未开启"); XCTAssertNil(model.elapsedSeconds)
        XCTAssertEqual(model.powerText, "电池 64%"); XCTAssertEqual(model.networkText, "已连接"); XCTAssertEqual(model.thermalDescription, "略高")
        await model.start()
        XCTAssertEqual(model.phase, .on, model.message); XCTAssertEqual(model.phaseText, "保持唤醒中")
        time = 600; await model.refresh()
        XCTAssertEqual(model.elapsedSeconds, 600); XCTAssertEqual(model.statusTitle, "00:20:00")
        let stopped = await model.stop()
        XCTAssertTrue(stopped, model.message); XCTAssertEqual(model.phase, .off)
        XCTAssertEqual(model.lastSession?.reason, StopReason.manual.message)
        XCTAssertEqual(AppModel(defaults: defaults, helperStatus: { .notRegistered }, startMonitoring: false).lastSession, model.lastSession)
    }
    @MainActor func testAdHocPreviewStopsWithoutQueryingInstalledHelper() async {
        var requests = 0
        let model = AppModel(defaults: nil, helperRequest: { _ in requests += 1; throw AwakeError.backend("must not contact helper") }, startMonitoring: false)
        XCTAssertFalse(model.helperBuildEnabled)
        await model.refresh()
        let stopped = await model.stop()
        XCTAssertTrue(stopped, model.message); XCTAssertEqual(requests, 0)
    }
}
