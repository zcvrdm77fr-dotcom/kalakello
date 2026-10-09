import Foundation

/// How much light there is. Replaces the web app's fixed "prime hours = before 09 / after 18",
/// which is wrong in Finland (midsummer nights are bright, December days last five hours).
enum LightPhase: String, Codable {
    case day, twilight, night
}

struct Conditions {
    var temp: Double
    var pressure: Double
    var pressure6hAgo: Double?
    var wind: Double
    var cloud: Double
    var hour: Int
    /// nil = use the original fixed-hour rule (kept for parity tests and polar edge cases).
    var light: LightPhase?

    var pressureDelta: Double? {
        guard let p = pressure6hAgo else { return nil }
        return pressure - p
    }
}

enum ScoreBand: String {
    case exceptional, veryGood, good, fair, poor

    var title: String {
        switch self {
        case .exceptional: return "Poikkeuksellisen hyvä"
        case .veryGood: return "Erittäin hyvä"
        case .good: return "Hyvä"
        case .fair: return "Kohtalainen"
        case .poor: return "Heikko"
        }
    }
}

enum FishingScore {
    /// Heuristic raw score 0…100 (before calibration). Returns nil for invalid input.
    static func rawScore(_ c: Conditions, species: Species) -> Int? {
        guard c.temp.isFinite, c.pressure.isFinite, c.wind.isFinite, c.cloud.isFinite else { return nil }
        guard c.wind >= 0, c.cloud >= 0, c.cloud <= 100, c.pressure > 0, c.hour >= 0, c.hour < 24 else { return nil }

        let delta = c.pressureDelta ?? 0
        var raw = 48
        let lowLight: Bool

        switch c.light {
        case nil:
            lowLight = c.hour <= 8 || c.hour >= 18
            if lowLight { raw += 10 }
        case .twilight?:
            lowLight = true
            raw += 10
        case .night?:
            lowLight = true
            raw += 4
        case .day?:
            lowLight = false
        }

        if c.wind >= 1.5 && c.wind <= 6.5 { raw += 10 } else if c.wind > 10 { raw -= 12 }
        if c.cloud >= 35 && c.cloud <= 90 { raw += 7 }
        if delta <= -0.5 && delta >= -4 { raw += 8 } else if delta > 2.5 { raw -= 5 }
        if c.temp >= 6 && c.temp <= 22 { raw += 5 } else if c.temp > 27 || c.temp < -2 { raw -= 10 }

        raw += species.bonus(temp: c.temp, wind: c.wind, cloud: c.cloud, lowLight: lowLight)
        return min(100, max(0, raw))
    }

    /// Squeezes the extremes so that 90+ stays genuinely rare (same calibration as the web app).
    static func calibrate(_ raw: Int) -> Int {
        let r = Double(min(100, max(0, raw)))
        let calibrated = r <= 50 ? 50 - (50 - r) * 0.90 : 50 + (r - 50) * 0.82
        return min(94, max(0, Int(calibrated.rounded())))
    }

    static func score(_ c: Conditions, species: Species) -> Int? {
        guard let raw = rawScore(c, species: species) else { return nil }
        return calibrate(raw)
    }

    static func band(_ score: Int) -> ScoreBand {
        let v = min(100, max(0, score))
        if v >= 86 { return .exceptional }
        if v >= 72 { return .veryGood }
        if v >= 56 { return .good }
        if v >= 40 { return .fair }
        return .poor
    }
}
