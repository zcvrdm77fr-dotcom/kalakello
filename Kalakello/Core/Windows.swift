import Foundation

enum DayPeriod: String, CaseIterable, Identifiable {
    case all, morning, day, evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Koko vuorokausi"
        case .morning: return "Aamu"
        case .day: return "Päivä"
        case .evening: return "Ilta"
        }
    }

    func contains(hour: Int) -> Bool {
        switch self {
        case .all: return true
        case .morning: return hour >= 5 && hour < 12
        case .day: return hour >= 12 && hour < 18
        case .evening: return hour >= 18 && hour < 24
        }
    }
}

struct ScoredHour: Identifiable {
    let point: HourPoint
    let score: Int?
    var id: Date { point.timestamp }
}

struct RankedWindow: Identifiable {
    let start: Date
    let end: Date
    let average: Double
    let score: Int
    let hours: [ScoredHour]
    var id: Date { start }

    var avgTemp: Double { hours.map { $0.point.temp }.reduce(0, +) / Double(max(1, hours.count)) }
    var avgWind: Double { hours.map { $0.point.wind }.reduce(0, +) / Double(max(1, hours.count)) }
}

enum WindowRanker {
    /// Best non-overlapping runs of consecutive hours. Port of `rankFishingWindows`.
    static func rank(_ hours: [HourPoint], species: Species, windowHours: Int,
                     limit: Int = 3, period: DayPeriod = .all) -> [RankedWindow] {
        guard windowHours >= 1, windowHours <= 12, limit >= 1 else { return [] }
        let scored = hours
            .sorted { $0.timestamp < $1.timestamp }
            .map { ScoredHour(point: $0, score: FishingScore.score($0.conditions, species: species)) }
        guard scored.count >= windowHours else { return [] }

        var candidates: [RankedWindow] = []
        for i in 0...(scored.count - windowHours) {
            let items = Array(scored[i..<(i + windowHours)])
            var valid = true
            for (index, item) in items.enumerated() {
                if item.score == nil || !period.contains(hour: item.point.hour) { valid = false; break }
                if index > 0 {
                    let gap = item.point.timestamp.timeIntervalSince(items[index - 1].point.timestamp)
                    if gap != 3600 { valid = false; break }
                }
            }
            if !valid { continue }
            let total = items.reduce(0.0) { $0 + Double($1.score ?? 0) }
            let average = total / Double(windowHours)
            let start = items[0].point.timestamp
            candidates.append(RankedWindow(start: start,
                                           end: items[items.count - 1].point.timestamp.addingTimeInterval(3600),
                                           average: average, score: Int(average.rounded()), hours: items))
        }

        candidates.sort { a, b in
            a.average != b.average ? a.average > b.average : a.start < b.start
        }

        var selected: [RankedWindow] = []
        for c in candidates {
            if selected.allSatisfy({ c.end <= $0.start || c.start >= $0.end }) { selected.append(c) }
            if selected.count == limit { break }
        }
        return selected
    }
}
