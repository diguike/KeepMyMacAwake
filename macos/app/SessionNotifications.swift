import Foundation
import UserNotifications
import AwakeCore

@MainActor final class SessionNotifications {
    func enable() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
    func send(_ result: SessionResult) {
        let content = UNMutableNotificationContent()
        content.title = "保持唤醒已结束"
        content.body = result.text
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        // Notification delivery is independent of stopping and restoring power.
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
