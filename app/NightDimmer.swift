import AppKit

/// Temporary visual dimming. No hardware brightness or persistent preferences change.
@MainActor final class NightDimmer {
    private var windows: [NSWindow] = []
    private var observer: NSObjectProtocol?
    private var amount: Double = 0.94
    func start(amount: Double) {
        self.amount = min(0.98, max(0.5, amount))
        rebuild()
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.rebuild() }
            }
        }
    }
    private func rebuild() {
        windows.forEach { $0.orderOut(nil) }; windows.removeAll()
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.backgroundColor = NSColor.black.withAlphaComponent(amount)
            window.isOpaque = false; window.hasShadow = false; window.ignoresMouseEvents = true
            // Keep the menu bar and its controls accessible above the dimming layer.
            window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isReleasedWhenClosed = false
            window.orderFrontRegardless(); windows.append(window)
        }
    }
    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        windows.forEach { $0.orderOut(nil) }; windows.removeAll()
    }
}
