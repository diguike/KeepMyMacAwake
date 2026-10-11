import AppKit

/// Temporary visual dimming. No hardware brightness or persistent preferences change.
@MainActor final class NightDimmer {
    private enum ScreenID: Hashable {
        case display(Int)
        case object(ObjectIdentifier)
    }
    private var windows: [ScreenID: NSWindow] = [:]
    private var observer: NSObjectProtocol?
    private var amount: Double = 0.94
    private var isActive = false
    func start(amount: Double) {
        isActive = true
        self.amount = min(0.98, max(0.5, amount))
        synchronizeScreens()
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                object: nil, queue: .main) { [weak self] _ in
                guard let dimmer = self else { return }
                Task { @MainActor in dimmer.synchronizeScreens() }
            }
        }
    }
    private func synchronizeScreens() {
        // Notifications can repeat without a display change, or arrive after stop().
        guard isActive else { return }
        var attached: Set<ScreenID> = []
        let color = NSColor.black.withAlphaComponent(amount)
        for screen in NSScreen.screens {
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            let id = number.map { ScreenID.display($0.intValue) } ?? .object(ObjectIdentifier(screen))
            attached.insert(id)
            if let window = windows[id] {
                if window.frame != screen.frame { window.setFrame(screen.frame, display: true) }
                if window.backgroundColor != color { window.backgroundColor = color }
                continue
            }
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.backgroundColor = color
            window.isOpaque = false; window.hasShadow = false; window.ignoresMouseEvents = true
            // Keep the menu bar and its controls accessible above the dimming layer.
            window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isReleasedWhenClosed = false
            window.orderFrontRegardless(); windows[id] = window
        }
        // Create any new overlays before removing displays that have disappeared.
        for id in Set(windows.keys).subtracting(attached) {
            windows.removeValue(forKey: id)?.orderOut(nil)
        }
    }
    func stop() {
        isActive = false
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        windows.values.forEach { $0.orderOut(nil) }; windows.removeAll()
    }
}
