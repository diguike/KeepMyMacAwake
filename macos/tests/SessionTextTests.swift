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
                       "上次 2026/10/13 23:10–2026/10/14 07:10 · 运行 8 小时 · 设定时间已到")
    }
    func testSummaryAndCustomization() throws {
        var value = AwakePreferences()
        XCTAssertEqual(value.summary, "1 小时 · 需开盖 · 仅接电 · 允许熄屏")
        XCTAssertFalse(value.isCustomized)
        value.durationMinutes = 0; value.customMinutes = 95
        XCTAssertEqual(value.durationText, "1 小时 35 分钟"); XCTAssertTrue(value.isCustomized)
        let network = try XCTUnwrap(ScenePreset.named("有网时"))
        value.scene = network.name; value.durationMinutes = -1; value.lidMode = true; value.requireAC = false; value.requireNetwork = true
        XCTAssertEqual(value.summary, "直到手动停止 · 可合盖 · 可用电池 · 断网停止 · 允许熄屏")
    }
    func testScreenModeNamesKeepStoredIdentifiers() {
        XCTAssertEqual(["自动熄屏", "保持常亮", "夜间柔光"].map(SessionText.screenMode), ["允许熄屏", "屏幕常亮", "调暗常亮"])
        XCTAssertEqual(SessionText.screenMode("unknown"), "unknown")
        var value = AwakePreferences(); value.screenMode = "夜间柔光"
        XCTAssertTrue(value.isValid, "Display names must not replace saved identifiers")
    }
    func testSpanAndTimerText() {
        XCTAssertEqual(SessionText.span(start: date(13, 23, 10), end: date(14, 7, 10), calendar: calendar), "10/13 23:10 – 10/14 07:10")
        XCTAssertEqual(SessionText.span(start: date(14, 1, 10), end: date(14, 2, 5), calendar: calendar), "10/14 01:10 – 02:05")
        XCTAssertEqual(SessionText.timer(3 * 3600 + 5 * 60 + 9.9), "03:05:09")
        XCTAssertEqual(SessionText.timer(-3), "00:00:00")
        XCTAssertEqual(Set(ScenePreset.all.map(\.tagline)).count, ScenePreset.all.count)
    }
    func testEveryPresetIsValidPreferences() {
        for preset in ScenePreset.all {
            let value = preset.preferences
            XCTAssertTrue(value.isValid, preset.name); XCTAssertFalse(value.isCustomized, preset.name)
        }
    }
}
