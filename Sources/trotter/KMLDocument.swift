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
    /// Sub-map references parsed from `<NetworkLink>` elements: name -> href.
    /// hrefs are kept as written in the KML (typically relative paths).
    var networkLinks: [String: String] = [:]

    var startDate: Date? {
        guard let s = attributes["start_date"] else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: s)
    }

    var showsWeather: Bool {
        switch attributes["show_weather"]?.lowercased() {
        case "true", "1", "yes": return true
        default: return false
        }
    }

    func date(forDay day: Int) -> Date? {
        guard let start = startDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: day - 1, to: start)
    }

    var lastDay: Int {
        features.flatMap(\.days).max() ?? 1
    }

    var totalDays: Int { lastDay }

    /// Distinct boundary days across the trip (first and last day of every multi-day feature).
    /// These act as palette anchor points: consecutive days inside a single stay share the
    /// same surrounding anchor pair so they only consume one palette step total.
    var dayAnchors: [Int] {
        var set = Set<Int>()
        for f in features where !f.days.isEmpty {
            if let first = f.days.first { set.insert(first) }
            if let last = f.days.last { set.insert(last) }
        }
        return set.sorted()
    }

    var totalNights: Int {
        features.reduce(0) { $0 + $1.nights }
    }

    var endDate: Date? {
        date(forDay: lastDay)
    }

    struct DayTimes {
        var arrival: String?
        var departure: String?
    }

    func inboundTransit(at coord: CLLocationCoordinate2D, day: Int) -> KMLFeature? {
        for feature in features {
            guard case .lineString(let line) = feature, feature.days.contains(day) else { continue }
            if let last = line.coordinates.last, KMLDocument.coordsEqual(last, coord) {
                return feature
            }
        }
        return nil
    }

    func outboundTransit(at coord: CLLocationCoordinate2D, day: Int) -> KMLFeature? {
        for feature in features {
            guard case .lineString(let line) = feature, feature.days.contains(day) else { continue }
            if let first = line.coordinates.first, KMLDocument.coordsEqual(first, coord) {
                return feature
            }
        }
        return nil
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
