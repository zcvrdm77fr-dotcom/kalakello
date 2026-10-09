import Foundation

/// Weather at the moment a catch was logged.
struct CatchSample {
    let temp: Double
    let wind: Double
    let cloud: Double
    let pressureDelta: Double?
    let hour: Int
    let score: Int?
}

/// "What does YOUR fishing look like?" — learned only from the user's own catch log.
struct PersonalInsights {
    struct Stat { let mean: Double; let sd: Double }

    let count: Int
    let avgScore: Int?
    let windLow: Double
    let windHigh: Double
    let tempMean: Double
    let fallingShare: Double?        // share of catches made while pressure was falling
    let partOfDay: String
    let partOfDayShare: Double

    private let wind: Stat
    private let temp: Stat
    private let cloud: Stat
    private let delta: Stat?

    static let minForSimilarity = 5

    static func make(from samples: [CatchSample]) -> PersonalInsights? {
        guard samples.count >= 3 else { return nil }

        let winds = samples.map { $0.wind }
        let temps = samples.map { $0.temp }
        let clouds = samples.map { $0.cloud }
        let deltas = samples.compactMap { $0.pressureDelta }
        let scores = samples.compactMap { $0.score }

        var buckets: [String: Int] = [:]
        for s in samples {
            let key: String
            switch s.hour {
            case 5..<12: key = "aamulla"
            case 12..<18: key = "päivällä"
            case 18..<24: key = "illalla"
            default: key = "yöllä"
            }
            buckets[key, default: 0] += 1
        }
        let top = buckets.max { a, b in a.value != b.value ? a.value < b.value : a.key > b.key }
        let falling: Double? = deltas.isEmpty ? nil : Double(deltas.filter { $0 < -0.5 }.count) / Double(deltas.count)

        return PersonalInsights(
            count: samples.count,
            avgScore: scores.isEmpty ? nil : Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded()),
            windLow: percentile(winds, 0.25),
            windHigh: percentile(winds, 0.75),
            tempMean: temps.reduce(0, +) / Double(temps.count),
            fallingShare: falling,
            partOfDay: top?.key ?? "",
            partOfDayShare: Double(top?.value ?? 0) / Double(samples.count),
            wind: stat(winds, floor: 1.5),
            temp: stat(temps, floor: 3),
            cloud: stat(clouds, floor: 20),
            delta: deltas.count >= 3 ? stat(deltas, floor: 1.2) : nil)
    }

    /// 0…1 — how closely the given conditions match the conditions of the user's own catches.
    func similarity(to c: Conditions) -> Double? {
        guard count >= Self.minForSimilarity else { return nil }
        var zs: [Double] = [
            (c.wind - wind.mean) / wind.sd,
            (c.temp - temp.mean) / temp.sd,
            (c.cloud - cloud.mean) / cloud.sd
        ]
        if let d = delta, let now = c.pressureDelta { zs.append((now - d.mean) / d.sd) }
        let meanSquare = zs.map { $0 * $0 }.reduce(0, +) / Double(zs.count)
        return min(1, max(0, exp(-0.5 * meanSquare)))
    }

    private static func stat(_ xs: [Double], floor: Double) -> Stat {
        let mean = xs.reduce(0, +) / Double(xs.count)
        let variance = xs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(xs.count)
        return Stat(mean: mean, sd: max(variance.squareRoot(), floor))
    }

    private static func percentile(_ xs: [Double], _ p: Double) -> Double {
        let s = xs.sorted()
        let pos = p * Double(s.count - 1)
        let lo = Int(pos.rounded(.down))
        let hi = min(s.count - 1, lo + 1)
        return s[lo] + (s[hi] - s[lo]) * (pos - Double(lo))
    }
}
