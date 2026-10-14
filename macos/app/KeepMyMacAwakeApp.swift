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
            let host = NSHostingView(rootView: ControlPanel(model: .shared).padding(.top, 14))
            host.sizingOptions = []
            next.contentView = host
            next.contentMinSize = NSSize(width: 460, height: 560)
            next.contentMaxSize = NSSize(width: 460, height: 1400)
            next.center(); window = next
        }
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
}
