import Foundation

struct MoonPhase {
    let fraction: Double      // 0 = new, 0.5 = full
    let name: String
    let symbol: String        // SF Symbol
    var illumination: Double { (1 - cos(2 * .pi * fraction)) / 2 }
}

/// Plain astronomical moon phase. Shown for context only — it is NOT part of the score.
enum Moon {
    private static let synodic = 29.530588853
    private static let newMoonEpoch = 947182440.0   // 2000-01-06 18:14 UTC

    static func phase(at date: Date) -> MoonPhase {
        var age = ((date.timeIntervalSince1970 - newMoonEpoch) / 86400).truncatingRemainder(dividingBy: synodic)
        if age < 0 { age += synodic }
        let fraction = age / synodic
        let index = Int((fraction * 8).rounded()) % 8
        let names = ["Uusikuu", "Kasvava sirppi", "Ensimmäinen neljännes", "Kasvava kuu",
                     "Täysikuu", "Vähenevä kuu", "Viimeinen neljännes", "Vähenevä sirppi"]
        let symbols = ["moonphase.new.moon", "moonphase.waxing.crescent", "moonphase.first.quarter",
                       "moonphase.waxing.gibbous", "moonphase.full.moon", "moonphase.waning.gibbous",
                       "moonphase.last.quarter", "moonphase.waning.crescent"]
        return MoonPhase(fraction: fraction, name: names[index], symbol: symbols[index])
    }
}
