import Foundation

/// The four target species of the original FastFishing web app.
enum Species: String, CaseIterable, Identifiable, Codable {
    case kuha, hauki, ahven, taimen

    var id: String { rawValue }

    var name: String {
        switch self {
        case .kuha: return "Kuha"
        case .hauki: return "Hauki"
        case .ahven: return "Ahven"
        case .taimen: return "Taimen"
        }
    }

    var lure: String {
        switch self {
        case .kuha: return "10–14 cm jigi tai kapea vaappu"
        case .hauki: return "spinnerbait, lusikka tai 12–20 cm shad"
        case .ahven: return "5–10 cm jigi, blade tai pieni lippa"
        case .taimen: return "lusikka, vaappu tai streamer"
        }
    }

    /// Species-specific score bonus. Ported 1:1 from `fishing-advice.js`.
    /// `lowLight` replaces the web app's fixed "prime hours" rule (see FishingScore).
    func bonus(temp: Double, wind: Double, cloud: Double, lowLight: Bool) -> Int {
        var b = 0
        switch self {
        case .kuha:
            if cloud >= 50 { b += 12 }
            if lowLight { b += 10 }
        case .hauki:
            if cloud >= 40 { b += 8 }
            if wind >= 2 && wind <= 7 { b += 6 }
            if temp > 24 { b -= 10 }
        case .ahven:
            if wind >= 1 && wind <= 5 { b += 8 }
            if cloud >= 30 { b += 5 }
        case .taimen:
            if temp >= 4 && temp <= 14 { b += 12 }
            if wind >= 2 && wind <= 8 { b += 6 }
            if temp > 19 { b -= 14 }
        }
        return b
    }

    func depth(temp: Double, hour: Int) -> String {
        switch self {
        case .kuha:
            if hour >= 20 || hour <= 6 { return "2–5 m reunat ja matalan vierus" }
            return temp > 18 ? "6–10 m penkat" : "4–8 m penkat"
        case .hauki:
            return temp > 20 ? "4–8 m viileämmät reunat" : "1–5 m kasvustot ja penkat"
        case .ahven:
            return (temp >= 10 && temp <= 20) ? "2–7 m parvet ja penkat" : "4–10 m syvemmät reunat"
        case .taimen:
            return temp > 16 ? "syvempi, viileä vesi ja virtapaikat" : "pintakerros–4 m, virrat ja tuulenpuoleiset rannat"
        }
    }

    func advice(for c: Conditions) -> Advice {
        let color = c.cloud < 35 ? "luonnollinen / hopea" : "tumma, UV tai kontrastiväri"
        let technique: String
        if c.wind > 7 {
            technique = "kalasta suojan puolta ja pidä viehe hallittavana"
        } else if c.hour >= 18 || c.hour <= 8 {
            technique = "hidasta hieman ja käy reunat järjestelmällisesti"
        } else {
            technique = "etsi aktiivista kalaa liikkuen"
        }
        return Advice(lure: lure, depth: depth(temp: c.temp, hour: c.hour), color: color, technique: technique)
    }
}

struct Advice {
    let lure: String
    let depth: String
    let color: String
    let technique: String
}
