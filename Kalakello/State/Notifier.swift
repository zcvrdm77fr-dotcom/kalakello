import Foundation
import UserNotifications

/// Local "good window coming up" reminders. Scheduled whenever the forecast refreshes
/// (i.e. while/after the app is used) — no server, no push.
enum Notifier {
    private static let ids = ["kk.window.0", "kk.window.1", "kk.window.2"]

    static func requestAuthorization() async -> Bool {
        let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        return granted ?? false
    }

    static func clear() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func schedule(windows: [RankedWindow], species: Species, place: Place,
                         timeZone: TimeZone, threshold: Int, now: Date) {
        clear()
        let center = UNUserNotificationCenter.current()
        var slot = 0
        for w in windows where w.score >= threshold && w.start > now.addingTimeInterval(10 * 60) && slot < ids.count {
            let fire = max(now.addingTimeInterval(30), w.start.addingTimeInterval(-45 * 60))
            let content = UNMutableNotificationContent()
            content.title = "Kalakeli: hyvä ikkuna alkaa pian"
            content.body = "\(species.name) · \(Fmt.range(w.start, w.end, timeZone)) · pisteet \(w.score) (\(place.name))"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(5, fire.timeIntervalSince(now)), repeats: false)
            center.add(UNNotificationRequest(identifier: ids[slot], content: content, trigger: trigger))
            slot += 1
        }
    }
}
