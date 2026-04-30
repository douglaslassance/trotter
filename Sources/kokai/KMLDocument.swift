import CoreLocation
import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let kml = UTType(importedAs: "com.google.earth.kml")
}

struct KMLDocument {
    var name: String?
    var details: String?
    var attributes: [String: String]
    let features: [KMLFeature]

    var startDate: Date? {
        guard let s = attributes["start_date"] else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: s)
    }

    func date(forDay day: Int) -> Date? {
        guard let start = startDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: day - 1, to: start)
    }

    struct DayTimes {
        var arrival: String?
        var departure: String?
    }

    func times(at coord: CLLocationCoordinate2D, day: Int) -> DayTimes? {
        var result = DayTimes()
        for feature in features {
            guard case .lineString(let line) = feature, feature.days.contains(day) else { continue }
            if let last = line.coordinates.last,
               KMLDocument.coordsEqual(last, coord),
               result.arrival == nil {
                result.arrival = feature.arrival
            }
            if let first = line.coordinates.first,
               KMLDocument.coordsEqual(first, coord),
               result.departure == nil {
                result.departure = feature.departure
            }
        }
        if result.arrival == nil && result.departure == nil { return nil }
        return result
    }

    private static func coordsEqual(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) < 0.001 && abs(a.longitude - b.longitude) < 0.001
    }
}
