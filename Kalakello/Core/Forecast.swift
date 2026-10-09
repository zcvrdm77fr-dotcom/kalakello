import Foundation

struct SunDay: Codable, Hashable {
    let start: Date        // local midnight
    let sunrise: Date?     // nil during polar night / midnight sun
    let sunset: Date?
}

struct HourPoint: Identifiable, Codable, Hashable {
    let timestamp: Date
    let temp: Double
    let pressure: Double
    let wind: Double
    let cloud: Double
    let pressure6hAgo: Double?
    let hour: Int          // local hour at the forecast location
    let light: LightPhase?

    var id: TimeInterval { timestamp.timeIntervalSince1970 }
    var pressureDelta: Double? { pressure6hAgo.map { pressure - $0 } }
    var conditions: Conditions {
        Conditions(temp: temp, pressure: pressure, pressure6hAgo: pressure6hAgo,
                   wind: wind, cloud: cloud, hour: hour, light: light)
    }
}

struct Forecast: Codable {
    let timezoneID: String
    let hours: [HourPoint]
    let sun: [SunDay]
    let fetchedAt: Date

    var timeZone: TimeZone { TimeZone(identifier: timezoneID) ?? .current }

    func point(containing date: Date) -> HourPoint? {
        hours.first { $0.timestamp <= date && date < $0.timestamp.addingTimeInterval(3600) }
    }
}

enum ForecastError: LocalizedError {
    case invalidLocation, unavailable, invalidData

    var errorDescription: String? {
        switch self {
        case .invalidLocation: return "Virheellinen sijainti."
        case .unavailable: return "Sääpalvelu ei vastannut."
        case .invalidData: return "Säädata oli virheellistä."
        }
    }
}

func isValidCoordinate(_ lat: Double, _ lon: Double) -> Bool {
    lat.isFinite && lon.isFinite && abs(lat) <= 90 && abs(lon) <= 180
}

// MARK: - Parsing (Open-Meteo, timeformat=unixtime)

private struct OpenMeteoResponse: Decodable {
    struct Hourly: Decodable {
        let time: [Double]
        let temperature_2m: [Double?]
        let pressure_msl: [Double?]
        let wind_speed_10m: [Double?]
        let cloud_cover: [Double?]
    }
    struct Daily: Decodable {
        let time: [Double]
        let sunrise: [Double?]?
        let sunset: [Double?]?
    }
    let timezone: String
    let hourly: Hourly
    let daily: Daily?
}

enum ForecastParser {
    /// Mirrors `normalizeForecast` from the web app: an hour with ANY missing value is dropped,
    /// so a null never turns into calm wind or zero degrees.
    static func parse(_ data: Data, fetchedAt: Date = Date()) throws -> Forecast {
        guard let r = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data),
              let tz = TimeZone(identifier: r.timezone) else { throw ForecastError.invalidData }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        func value(_ array: [Double?], _ i: Int) -> Double? {
            guard i >= 0, i < array.count else { return nil }
            return array[i]
        }
        func date(_ array: [Double?]?, _ i: Int) -> Date? {
            guard let array = array, i < array.count, let v = array[i], v.isFinite else { return nil }
            return Date(timeIntervalSince1970: v)
        }

        var sunDays: [SunDay] = []
        if let d = r.daily {
            for (i, t) in d.time.enumerated() where t.isFinite {
                sunDays.append(SunDay(start: Date(timeIntervalSince1970: t),
                                      sunrise: date(d.sunrise, i),
                                      sunset: date(d.sunset, i)))
            }
            sunDays.sort { $0.start < $1.start }
        }

        let times = r.hourly.time
        var points: [HourPoint] = []
        for (i, seconds) in times.enumerated() {
            guard seconds.isFinite,
                  let temp = value(r.hourly.temperature_2m, i), temp.isFinite,
                  let pressure = value(r.hourly.pressure_msl, i), pressure.isFinite,
                  let wind = value(r.hourly.wind_speed_10m, i), wind.isFinite,
                  let cloud = value(r.hourly.cloud_cover, i), cloud.isFinite else { continue }
            guard wind >= 0, cloud >= 0, cloud <= 100, pressure > 0 else { continue }

            var previous: Double? = nil
            if i >= 6, times[i - 6] == seconds - 21600,
               let p = value(r.hourly.pressure_msl, i - 6), p.isFinite, p > 0 {
                previous = p
            }

            let stamp = Date(timeIntervalSince1970: seconds)
            points.append(HourPoint(timestamp: stamp, temp: temp, pressure: pressure, wind: wind,
                                    cloud: cloud, pressure6hAgo: previous,
                                    hour: cal.component(.hour, from: stamp),
                                    light: lightPhase(at: stamp, days: sunDays)))
        }
        points.sort { $0.timestamp < $1.timestamp }
        guard !points.isEmpty else { throw ForecastError.invalidData }
        return Forecast(timezoneID: r.timezone, hours: points, sun: sunDays, fetchedAt: fetchedAt)
    }

    /// Twilight = 1 h before … 2 h after sunrise, and 2 h before … 1 h after sunset.
    /// Returns nil when the day has no sunrise/sunset (polar night, midnight sun).
    static func lightPhase(at hourStart: Date, days: [SunDay]) -> LightPhase? {
        let mid = hourStart.addingTimeInterval(1800)
        guard let day = days.last(where: { $0.start <= mid }),
              let rise = day.sunrise, let sunsetDate = day.sunset else { return nil }

        for d in days {
            if let sr = d.sunrise, mid >= sr.addingTimeInterval(-3600), mid <= sr.addingTimeInterval(7200) { return .twilight }
            if let ss = d.sunset, mid >= ss.addingTimeInterval(-7200), mid <= ss.addingTimeInterval(3600) { return .twilight }
        }
        return (mid >= rise && mid < sunsetDate) ? .day : .night
    }
}

// MARK: - Network

enum ForecastService {
    static func fetch(lat: Double, lon: Double, pastDays: Int = 1, forecastDays: Int = 3,
                      session: URLSession = .shared) async throws -> Forecast {
        guard isValidCoordinate(lat, lon) else { throw ForecastError.invalidLocation }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "hourly", value: "temperature_2m,pressure_msl,wind_speed_10m,cloud_cover"),
            URLQueryItem(name: "daily", value: "sunrise,sunset"),
            URLQueryItem(name: "forecast_days", value: String(forecastDays)),
            URLQueryItem(name: "past_days", value: String(min(92, max(0, pastDays)))),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "wind_speed_unit", value: "ms")
        ]
        guard let url = components.url else { throw ForecastError.invalidLocation }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw ForecastError.unavailable }
        return try ForecastParser.parse(data)
    }
}
