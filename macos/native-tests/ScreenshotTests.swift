import XCTest
import SwiftUI
import AppKit
import AwakeCore
@testable import AwakeApp

/// Renders README/review screenshots offscreen with injected state.
/// Run: AWAKE_SCREENSHOTS=/path/to/dir swift test --filter ScreenshotTests
final class ScreenshotTests: XCTestCase {
    private let sample = PowerSample(onAC: true, batteryPercent: 86, thermal: .nominal, networkAvailable: true)
    private var calendarStart: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 23, minute: 10))!
    }

    @MainActor func testRenderScreenshots() async throws {
        guard let path = ProcessInfo.processInfo.environment["AWAKE_SCREENSHOTS"] else {
            throw XCTSkip("Set AWAKE_SCREENSHOTS to render screenshots")
        }
        let output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let suite = "io.github.diguike.KeepMyMacAwake.screenshots.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let previous = SessionResult(start: calendarStart.addingTimeInterval(-86400), end: calendarStart.addingTimeInterval(-86400 + 8 * 3600),
                                     reason: StopReason.expired.message)
        defaults.set(try JSONEncoder().encode(previous), forKey: "lastResult.v1")
        var time: Double = 0
        let sample = self.sample
        let base = calendarStart
        let model = AppModel(defaults: defaults, sample: { sample },
                             clock: { ClockSample(wall: base.addingTimeInterval(time), continuous: time) },
                             helperStatus: { .notRegistered }, startMonitoring: false)
        await model.refresh()

        try render(ControlPanel(model: model).frame(height: 886), "first-run", output)
        model.acknowledge()
        model.chooseScene("夜间")
        for appearance in ["light", "dark"] {
            try render(ControlPanel(model: model).frame(height: 886), "control-idle-\(appearance)", output, dark: appearance == "dark")
            try render(popover(MenuBarPanel(model: model)), "menubar-idle-\(appearance)", output, dark: appearance == "dark")
        }
        PanelRouter.shared.tab = .settings
        try render(ControlPanel(model: model).frame(height: 886), "settings-light", output)
        PanelRouter.shared.tab = .control

        // Start an ordinary session, then show it as the night scene without creating real dimming overlays.
        model.chooseScene("日常"); model.durationMinutes = 480
        await model.start()
        XCTAssertTrue(model.active, model.message)
        model.scene = "夜间"; model.screenMode = "夜间柔光"
        time = 92 * 60; await model.refresh()
        for appearance in ["light", "dark"] {
            try render(ControlPanel(model: model).frame(height: 886), "control-active-\(appearance)", output, dark: appearance == "dark")
            try render(popover(MenuBarPanel(model: model)), "menubar-active-\(appearance)", output, dark: appearance == "dark")
        }
        let stopped = await model.stop()
        XCTAssertTrue(stopped, model.message)
    }

    private func popover<V: View>(_ view: V) -> some View {
        view.background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(1).background(Color.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    @MainActor private func render<V: View>(_ view: V, _ name: String, _ output: URL, dark: Bool = false) throws {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let host = NSHostingView(rootView: view.environment(\.colorScheme, dark ? .dark : .light))
        host.appearance = appearance
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = appearance
        window.isOpaque = false; window.backgroundColor = .clear
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        appearance?.performAsCurrentDrawingAppearance { host.cacheDisplay(in: host.bounds, to: rep) }
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try data.write(to: output.appendingPathComponent("\(name).png"))
        window.orderOut(nil)
    }
}
