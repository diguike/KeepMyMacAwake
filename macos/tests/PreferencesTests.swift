import XCTest
@testable import AwakeCore

final class PreferencesTests: XCTestCase {
    func testInvalidStoredPreferencesAreRejected() {
        var p = AwakePreferences(); XCTAssertTrue(p.isValid)
        p.durationMinutes = 1441; XCTAssertFalse(p.isValid)
        p.durationMinutes = -1; XCTAssertTrue(p.isValid)
        p.dimAmount = .nan; XCTAssertFalse(p.isValid)
        p.dimAmount = 0.94; p.minimumBattery = 0; XCTAssertFalse(p.isValid)
        p.minimumBattery = 20; p.screenMode = "unsupported"; XCTAssertFalse(p.isValid)
    }
    func testPreferencesRoundTripRetainsConditionsWithoutRuntimeSession() throws {
        var p = AwakePreferences()
        p.scene = "有网时"; p.requireNetwork = true; p.requireAC = false; p.lidMode = true
        p.durationMinutes = -1; p.screenMode = "夜间柔光"
        let data = try JSONEncoder().encode(p)
        XCTAssertEqual(p, try JSONDecoder().decode(AwakePreferences.self, from: data))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("leaseID"))
    }
}
