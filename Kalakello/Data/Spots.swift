import Foundation
import CoreLocation

enum SpotKind: String, Decodable {
    case known, rapids, strait, shoal, water, other

    var title: String {
        switch self {
        case .known: return "Kalastuspaikka"
        case .rapids: return "Koski"
        case .strait: return "Salmi / kapea kohta"
        case .shoal: return "Matalikko"
        case .water: return "Vesistö"
        case .other: return "Paikka"
        }
    }

    var symbol: String {
        switch self {
        case .known: return "fish.fill"
        case .rapids: return "water.waves"
        case .strait: return "arrow.left.and.right"
        case .shoal: return "triangle.fill"
        case .water: return "drop.fill"
        case .other: return "mappin"
        }
    }

    /// Lower = more important when the map is crowded.
    var priority: Int {
        switch self {
        case .known: return 0
        case .rapids: return 1
        case .strait: return 2
        case .shoal: return 3
        case .water: return 4
        case .other: return 5
        }
    }
}

/// A fishing-relevant place from OpenStreetMap (© OpenStreetMap contributors, ODbL).
struct Spot: Identifiable, Decodable, Hashable {
    let id: Int
    let la: Double
    let lo: Double
    let k: SpotKind
    let n: String?
    let a: String?
    let w: String?

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: la, longitude: lo) }
    var kind: SpotKind { k }
    var displayName: String { n ?? k.title }

    var accessNote: String? {
        switch a {
        case "fee"?: return "Maksullinen"
        case "licence"?, "permit"?: return "Vaatii luvan"
        case "members_only"?: return "Vain jäsenille"
        default: return nil
        }
    }

    var websiteURL: URL? {
        guard let w = w, let url = URL(string: w), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }
}

enum SpotStore {
    static let all: [Spot] = {
        guard let url = Bundle.main.url(forResource: "spots", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let spots = try? JSONDecoder().decode([Spot].self, from: data) else { return [] }
        return spots
    }()

    static func within(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, limit: Int) -> [Spot] {
        let inside = all.filter { $0.la >= minLat && $0.la <= maxLat && $0.lo >= minLon && $0.lo <= maxLon }
        let sorted = inside.sorted { a, b in
            a.k.priority != b.k.priority ? a.k.priority < b.k.priority : a.id < b.id
        }
        return Array(sorted.prefix(limit))
    }

    static func search(_ text: String, limit: Int) -> [Spot] {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        let hits = all.filter { spot in
            guard let n = spot.n else { return false }
            return n.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        let sorted = hits.sorted { a, b in
            a.k.priority != b.k.priority ? a.k.priority < b.k.priority : (a.n ?? "") < (b.n ?? "")
        }
        return Array(sorted.prefix(limit))
    }
}
