import Foundation
import CoreLocation
import Observation

enum AppTab: Hashable { case today, map, log, about }

struct Place: Codable, Equatable, Hashable {
    var name: String
    var lat: Double
    var lon: Double

    static let helsinki = Place(name: "Helsinki", lat: 60.1699, lon: 24.9384)
    var cacheKey: String { String(format: "%.4f,%.4f", lat, lon) }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}

enum LoadStatus: Equatable {
    case idle, loading, ready, failed(String)
}

private struct CacheEntry: Codable {
    let key: String
    let forecast: Forecast
}

@MainActor
@Observable
final class AppState {
    private enum Key {
        static let place = "kk.place"
        static let species = "kk.species"
        static let hours = "kk.windowHours"
        static let period = "kk.period"
        static let notify = "kk.notify"
        static let threshold = "kk.threshold"
        static let cache = "kk.cache"
    }

    var tab: AppTab = .today

    private(set) var place: Place
    private(set) var species: Species
    private(set) var windowHours: Int
    private(set) var period: DayPeriod
    private(set) var notificationsEnabled: Bool
    private(set) var notifyThreshold: Int

    private(set) var forecast: Forecast?
    private(set) var isStale = false
    private(set) var status: LoadStatus = .idle
    private(set) var now = Date()

    @ObservationIgnored private var cache: [CacheEntry] = []
    @ObservationIgnored private var loadVersion = 0
    let locationService = LocationService()

    init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: Key.place), let p = try? JSONDecoder().decode(Place.self, from: data) {
            place = p
        } else {
            place = .helsinki
        }
        species = Species(rawValue: d.string(forKey: Key.species) ?? "") ?? .kuha
        let hours = d.integer(forKey: Key.hours)
        windowHours = (1...4).contains(hours) ? hours : 2
        period = DayPeriod(rawValue: d.string(forKey: Key.period) ?? "") ?? .all
        notificationsEnabled = d.bool(forKey: Key.notify)
        let threshold = d.integer(forKey: Key.threshold)
        notifyThreshold = threshold == 0 ? 70 : threshold
        if let data = d.data(forKey: Key.cache), let c = try? JSONDecoder().decode([CacheEntry].self, from: data) {
            cache = c
        }
    }

    // MARK: Derived data

    var timeZone: TimeZone { forecast?.timeZone ?? TimeZone(identifier: "Europe/Helsinki") ?? .current }

    var currentHour: HourPoint? {
        guard let f = forecast else { return nil }
        let inside = f.hours.first { $0.timestamp <= now && now < $0.timestamp.addingTimeInterval(3600) }
        return inside ?? f.hours.first { $0.timestamp >= now }
    }

    var currentScore: Int? {
        guard let c = currentHour else { return nil }
        return FishingScore.score(c.conditions, species: species)
    }

    /// Whole future hours inside the next 48 h (a trip must not start in the past).
    var upcomingHours: [HourPoint] {
        guard let f = forecast else { return [] }
        let limit = now.addingTimeInterval(48 * 3600)
        return f.hours.filter { $0.timestamp >= now && $0.timestamp.addingTimeInterval(3600) <= limit }
    }

    var windows: [RankedWindow] {
        WindowRanker.rank(upcomingHours, species: species, windowHours: windowHours, limit: 3, period: period)
    }

    var chartHours: [ScoredHour] {
        guard let f = forecast, let start = currentHour?.timestamp else { return [] }
        let end = start.addingTimeInterval(48 * 3600)
        return f.hours
            .filter { $0.timestamp >= start && $0.timestamp < end }
            .map { ScoredHour(point: $0, score: FishingScore.score($0.conditions, species: species)) }
    }

    // MARK: Settings

    func setSpecies(_ s: Species) {
        species = s
        UserDefaults.standard.set(s.rawValue, forKey: Key.species)
        rescheduleNotifications()
    }

    func setWindowHours(_ n: Int) {
        windowHours = min(4, max(1, n))
        UserDefaults.standard.set(windowHours, forKey: Key.hours)
        rescheduleNotifications()
    }

    func setPeriod(_ p: DayPeriod) {
        period = p
        UserDefaults.standard.set(p.rawValue, forKey: Key.period)
    }

    func setThreshold(_ value: Int) {
        notifyThreshold = min(95, max(40, value))
        UserDefaults.standard.set(notifyThreshold, forKey: Key.threshold)
        rescheduleNotifications()
    }

    func setNotifications(_ on: Bool) async -> Bool {
        if on {
            guard await Notifier.requestAuthorization() else { return false }
            notificationsEnabled = true
        } else {
            notificationsEnabled = false
            Notifier.clear()
        }
        UserDefaults.standard.set(notificationsEnabled, forKey: Key.notify)
        rescheduleNotifications()
        return true
    }

    func setPlace(_ p: Place) {
        guard p != place else { return }
        place = p
        if let data = try? JSONEncoder().encode(p) { UserDefaults.standard.set(data, forKey: Key.place) }
        forecast = nil
        status = .loading
        Task { await load() }
    }

    func useCurrentLocation() async -> String? {
        guard let loc = await locationService.requestOnce() else {
            return "Sijaintia ei saatu. Tarkista sijaintilupa asetuksista tai hae paikka nimellä."
        }
        var name = "Oma sijainti"
        if let marks = try? await CLGeocoder().reverseGeocodeLocation(loc), let m = marks.first {
            name = m.locality ?? m.subLocality ?? m.name ?? name
        }
        let lat = (loc.coordinate.latitude * 10_000).rounded() / 10_000
        let lon = (loc.coordinate.longitude * 10_000).rounded() / 10_000
        setPlace(Place(name: name, lat: lat, lon: lon))
        return nil
    }

    func tick() { now = Date() }

    // MARK: Loading

    func load(force: Bool = false) async {
        now = Date()
        let requested = place
        let key = requested.cacheKey

        if !force, let entry = cache.first(where: { $0.key == key }),
           now.timeIntervalSince(entry.forecast.fetchedAt) < 15 * 60, hasUpcoming(entry.forecast) {
            apply(entry.forecast, stale: false)
            return
        }

        loadVersion += 1
        let version = loadVersion
        if forecast == nil { status = .loading }

        do {
            let fresh = try await ForecastService.fetch(lat: requested.lat, lon: requested.lon)
            guard version == loadVersion, requested == place else { return }
            remember(fresh, key: key)
            apply(fresh, stale: false)
        } catch {
            if Task.isCancelled { return }
            guard version == loadVersion, requested == place else { return }
            if let entry = cache.first(where: { $0.key == key }),
               Date().timeIntervalSince(entry.forecast.fetchedAt) <= 6 * 3600, hasUpcoming(entry.forecast) {
                apply(entry.forecast, stale: true)
            } else if forecast == nil {
                status = .failed("Säätietoa ei saatu. Tarkista verkkoyhteys ja vedä alas yrittääksesi uudelleen.")
            } else {
                isStale = true
            }
        }
    }

    /// Weather for a moment in the (recent) past, used when logging a catch.
    func snapshot(lat: Double, lon: Double, date: Date) async -> HourPoint? {
        if date > Date().addingTimeInterval(3600) { return nil }
        if let f = forecast, abs(place.lat - lat) < 0.001, abs(place.lon - lon) < 0.001,
           let p = f.point(containing: date) {
            return p
        }
        let days = Int((Date().timeIntervalSince(date) / 86400).rounded(.up)) + 1
        guard days <= 92 else { return nil }
        guard let f = try? await ForecastService.fetch(lat: lat, lon: lon, pastDays: days, forecastDays: 1) else { return nil }
        return f.point(containing: date)
    }

    private func hasUpcoming(_ f: Forecast) -> Bool {
        f.hours.contains { $0.timestamp >= now }
    }

    private func remember(_ f: Forecast, key: String) {
        cache.removeAll { $0.key == key }
        cache.append(CacheEntry(key: key, forecast: f))
        if cache.count > 6 { cache.removeFirst(cache.count - 6) }
        if let data = try? JSONEncoder().encode(cache) { UserDefaults.standard.set(data, forKey: Key.cache) }
    }

    private func apply(_ f: Forecast, stale: Bool) {
        forecast = f
        isStale = stale
        status = .ready
        rescheduleNotifications()
    }

    private func rescheduleNotifications() {
        guard notificationsEnabled else { return }
        guard forecast != nil else { return }
        let list = WindowRanker.rank(upcomingHours, species: species, windowHours: windowHours, limit: 3, period: .all)
        Notifier.schedule(windows: list, species: species, place: place, timeZone: timeZone,
                          threshold: notifyThreshold, now: Date())
    }
}
