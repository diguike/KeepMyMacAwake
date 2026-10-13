import Foundation
import XCTest
@testable import AwakeCore

final class ContractTests: XCTestCase {
    private func rows(_ name: String) throws -> [[String: Any]] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("specs/\(name).json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }
    private final class Backend: SleepBackend {
        var disabled = false
        func readDisabled() throws -> Bool { disabled }
        func setDisabled(_ value: Bool) throws { disabled = value }
    }
    private final class Store: RecoveryStore {
        var record: RecoveryRecord?
        func load() throws -> RecoveryRecord? { record }
        func save(_ value: RecoveryRecord) throws { record = value }
        func clear() throws { record = nil }
    }
    func testSharedScenarios() throws {
        for row in try rows("scenarios") {
            let engine = LeaseEngine(backend: Backend(), store: Store())
            let owner = UUID(), epoch = Date(timeIntervalSince1970: 0)
            // Renew every 10 seconds so the helper's independent heartbeat does not
            // mask the app timer/safety contract exercised by the Windows controller.
            let minutes = try XCTUnwrap(row["durationMinutes"] as? Double)
            let policy = SafetyPolicy(requireAC: true, requireNetwork: try XCTUnwrap(row["requireNetwork"] as? Bool))
            let good = PowerSample(onAC: true, batteryPercent: 90, thermal: .nominal, networkAvailable: true)
            let id = try engine.acquire(owner: owner, duration: minutes * 60, policy: policy, sample: good, now: ClockSample(wall: epoch, continuous: 0))
            let seconds = try XCTUnwrap(row["tickSeconds"] as? Double)
            if seconds > 10 {
                var point: Double = 10
                while point < seconds {
                    try engine.renew(id: id, owner: owner, sample: good, now: ClockSample(wall: epoch.addingTimeInterval(point), continuous: point))
                    point += 10
                }
            }
            let sample = PowerSample(onAC: row["onAC"] as? Bool, batteryPercent: 90,
                                     thermal: try XCTUnwrap(ThermalLevel(rawValue: try XCTUnwrap(row["thermal"] as? String))),
                                     networkAvailable: row["network"] as? Bool)
            let now = ClockSample(wall: epoch.addingTimeInterval(try XCTUnwrap(row["wallSeconds"] as? Double)), continuous: seconds)
            engine.tick(sample: sample, now: now)
            let status = engine.status(now: now)
            XCTAssertEqual(status.stopReason?.rawValue, row["reason"] as? String, row["name"] as? String ?? "")
            XCTAssertEqual(status.phase == .active, row["reason"] is NSNull)
        }
    }
    func testSharedSceneValuesAreValidMacPreferences() throws {
        for row in try rows("scenes") {
            var preferences = AwakePreferences()
            preferences.scene = try XCTUnwrap(row["macName"] as? String)
            preferences.durationMinutes = try XCTUnwrap(row["durationMinutes"] as? Int)
            preferences.screenMode = try XCTUnwrap(row["macScreenMode"] as? String)
            preferences.lidMode = try XCTUnwrap(row["lidMode"] as? Bool)
            preferences.requireAC = try XCTUnwrap(row["requireAC"] as? Bool)
            preferences.requireNetwork = try XCTUnwrap(row["requireNetwork"] as? Bool)
            XCTAssertTrue(preferences.isValid)
            // The app applies ScenePreset on selection; it must match the shared rules.
            let preset = try XCTUnwrap(ScenePreset.named(preferences.scene))
            XCTAssertEqual([preset.durationMinutes], [preferences.durationMinutes], preset.name)
            XCTAssertEqual(preset.screenMode, preferences.screenMode, preset.name)
            XCTAssertEqual([preset.lidMode, preset.requireAC, preset.requireNetwork],
                           [preferences.lidMode, preferences.requireAC, preferences.requireNetwork], preset.name)
        }
        XCTAssertEqual(ScenePreset.all.count, try rows("scenes").count)
    }
}
