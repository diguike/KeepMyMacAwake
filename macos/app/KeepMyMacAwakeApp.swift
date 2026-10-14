import SwiftUI
import AppKit
import CoreServices
import AwakeCore

@main struct KeepMyMacAwakeApp: App {
    @NSApplicationDelegateAdaptor(AwakeAppDelegate.self) private var delegate
    @StateObject private var model = AppModel.shared
    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(model: model)
        } label: {
            MenuBarLabel(model: model)
        }.menuBarExtraStyle(.window)
    }
}

@MainActor final class AwakeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let properties = event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))
        let isLogin = event?.eventID == AEEventID(kAEOpenApplication) && properties?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
        if !isLogin { ControlWindow.shared.show() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        ControlWindow.shared.show(); return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if !AppModel.shared.hasSession { return .terminateNow }
        Task { let stopped = await AppModel.shared.stop(); sender.reply(toApplicationShouldTerminate: stopped) }
        return .terminateLater
    }
}

@MainActor final class ControlWindow {
    static let shared = ControlWindow()
    private(set) var window: NSWindow?
    func show(tab: PanelTab? = nil) {
        if let tab { PanelRouter.shared.tab = tab }
        if window == nil {
            // Fit the whole control page on most screens; smaller screens scroll.
            let available = NSScreen.main?.visibleFrame.height ?? 800
            let height = max(560, min(900, available - 40))
            let next = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: height),
                                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            next.title = "KeepMyMacAwake"
            next.titleVisibility = .hidden
            next.titlebarAppearsTransparent = true
            next.isReleasedWhenClosed = false
            // Assign first: the page asks the window to fit its content during the first layout.
            window = next
            let host = NSHostingView(rootView: ControlPanel(model: .shared).padding(.top, 14))
            host.sizingOptions = []
            next.contentView = host
            next.contentMinSize = NSSize(width: 460, height: 360)
            next.contentMaxSize = NSSize(width: 460, height: 1400)
            next.center()
        }
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private var contentHeight: CGFloat = 0
    private var viewportHeight: CGFloat = 0
    /// Called with the measured page and visible-area heights of the control window.
    func fit(content: CGFloat? = nil, viewport: CGFloat? = nil) {
        if let content { contentHeight = content }
        if let viewport { viewportHeight = viewport }
        guard contentHeight > 0, viewportHeight > 0 else { return }
        adjustHeight(by: contentHeight - viewportHeight)
    }
    /// Keeps the top edge in place and stays within the visible screen.
    private func adjustHeight(by delta: CGFloat) {
        guard let window, abs(delta) > 1 else { return }
        let available = (window.screen ?? NSScreen.main)?.visibleFrame ?? window.frame
        var frame = window.frame
        let height = min(max(frame.height + delta, 400), available.height - 20)
        guard abs(height - frame.height) > 1 else { return }
        frame.origin.y += frame.height - height
        frame.size.height = height
        if frame.minY < available.minY { frame.origin.y = available.minY }
        window.setFrame(frame, display: true)
    }
}
