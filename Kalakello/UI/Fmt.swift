import Foundation

/// Formatting helpers. All clock times are shown in the *forecast location's* time zone.
enum Fmt {
    private static let lock = NSLock()
    private static var formatters: [String: DateFormatter] = [:]

    private static func formatter(_ format: String, _ tz: TimeZone) -> DateFormatter {
        let key = format + "|" + tz.identifier
        lock.lock()
        defer { lock.unlock() }
        if let f = formatters[key] { return f }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fi_FI")
        f.timeZone = tz
        f.dateFormat = format
        formatters[key] = f
        return f
    }

    static func hm(_ date: Date, _ tz: TimeZone) -> String {
        formatter("HH:mm", tz).string(from: date)
    }

    static func range(_ start: Date, _ end: Date, _ tz: TimeZone) -> String {
        "\(hm(start, tz))–\(hm(end, tz))"
    }

    static func dayLabel(_ date: Date, _ tz: TimeZone, now: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        if cal.isDate(date, inSameDayAs: now) { return "Tänään" }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(date, inSameDayAs: tomorrow) { return "Huomenna" }
        return formatter("EEE d.M.", tz).string(from: date).capitalized
    }

    static func dateTime(_ date: Date) -> String {
        formatter("d.M.yyyy 'klo' HH:mm", .current).string(from: date)
    }

    static func num(_ value: Double, _ digits: Int = 0) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "fi_FI")))
    }

    static func signed(_ value: Double, _ digits: Int = 1) -> String {
        let s = num(abs(value), digits)
        if value < 0 { return "−" + s }
        if value > 0 { return "+" + s }
        return s
    }
}
