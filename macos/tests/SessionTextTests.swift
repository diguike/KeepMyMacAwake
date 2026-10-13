import Foundation
import XCTest
@testable import AwakeCore

final class SessionTextTests: XCTestCase {
    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return value
    }()
    private func date(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }
    func testEndTimeNamesTheNextDay() {
        XCTAssertEqual(SessionText.endTime(date(13, 7, 30), now: date(13, 6, 30), calendar: calendar), "预计 07:30 结束")
        XCTAssertEqual(SessionText.endTime(date(14, 7, 5), now: date(13, 23, 5), calendar: calendar), "预计明天 07:05 结束")
        XCTAssertEqual(SessionText.endTime(date(15, 0, 10), now: date(13, 23, 50), calendar: calendar), "预计 2 天后 00:10 结束")
    }
    func testDurationAndMenuBarText() {
        XCTAssertEqual(SessionText.duration(30), "不足 1 分钟")
        XCTAssertEqual(SessionText.duration(45 * 60), "45 分钟")
        XCTAssertEqual(SessionText.duration(8 * 3600), "8 小时")
        XCTAssertEqual(SessionText.duration(90 * 60 + 59), "1 小时 30 分钟")
        XCTAssertEqual(SessionText.menuBar(remaining: 44 * 60 + 1), "45m")
        XCTAssertEqual(SessionText.menuBar(remaining: 480 * 60), "8h00m")
        XCTAssertEqual(SessionText.menuBar(remaining: 425 * 60 - 30), "7h05m")
        XCTAssertEqual(SessionText.menuBar(remaining: -5), "0m")
    }
    func testLastResultKeepsTimesDurationAndReason() {
        XCTAssertEqual(SessionText.lastResult(start: date(13, 23, 10), end: date(14, 7, 10), reason: "设定时间已到", calendar: calendar),
                       "上次 23:10–07:10 · 运行 8 小时 · 设定时间已到")
    }
    func testSummaryAndCustomization() throws {
        var value = AwakePreferences()
        XCTAssertEqual(value.summary, "1 小时 · 开盖 · 仅接电 · 自动熄屏")
        XCTAssertFalse(value.isCustomized)
        value.durationMinutes = 0; value.customMinutes = 95
        XCTAssertEqual(value.durationText, "1 小时 35 分钟"); XCTAssertTrue(value.isCustomized)
        let network = try XCTUnwrap(ScenePreset.named("有网时"))
        value.scene = network.name; value.durationMinutes = -1; value.lidMode = true; value.requireAC = false; value.requireNetwork = true
        XCTAssertEqual(value.summary, "直到手动停止 · 合盖 · 允许电池 · 断网停止 · 自动熄屏")
    }
    func testEveryPresetIsValidPreferences() {
        for preset in ScenePreset.all {
            let value = preset.preferences
            XCTAssertTrue(value.isValid, preset.name); XCTAssertFalse(value.isCustomized, preset.name)
        }
    }
}
