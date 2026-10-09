import Foundation
import SwiftData
import CoreLocation

@Model
final class CatchRecord {
    var date: Date = Date()
    var species: String = ""
    var lengthCm: Double?
    var weightKg: Double?
    var lure: String = ""
    var notes: String = ""
    var placeName: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    @Attribute(.externalStorage) var photoData: Data?

    // Weather at the time of the catch — this is what powers the personal insights.
    var snapTemp: Double?
    var snapPressure: Double?
    var snapPressureDelta: Double?
    var snapWind: Double?
    var snapCloud: Double?
    var snapHour: Int?
    var snapScore: Int?

    init(date: Date, species: String, lengthCm: Double?, weightKg: Double?, lure: String,
         notes: String, placeName: String, latitude: Double, longitude: Double, photoData: Data?) {
        self.date = date
        self.species = species
        self.lengthCm = lengthCm
        self.weightKg = weightKg
        self.lure = lure
        self.notes = notes
        self.placeName = placeName
        self.latitude = latitude
        self.longitude = longitude
        self.photoData = photoData
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func apply(snapshot p: HourPoint, score: Int?) {
        snapTemp = p.temp
        snapPressure = p.pressure
        snapPressureDelta = p.pressureDelta
        snapWind = p.wind
        snapCloud = p.cloud
        snapHour = p.hour
        snapScore = score
    }

    var sample: CatchSample? {
        guard let t = snapTemp, let w = snapWind, let c = snapCloud, let h = snapHour else { return nil }
        return CatchSample(temp: t, wind: w, cloud: c, pressureDelta: snapPressureDelta, hour: h, score: snapScore)
    }

    var species4: Species? { Species(rawValue: species.lowercased()) }
}

@Model
final class SavedPlace {
    var name: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var createdAt: Date = Date()

    init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = Date()
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
