import CoreLocation
import Foundation

enum KMLFeature: Identifiable {
    case point(Point)
    case lineString(LineString)
    case polygon(Polygon)

    var id: UUID {
        switch self {
        case .point(let p): return p.id
        case .lineString(let l): return l.id
        case .polygon(let p): return p.id
        }
    }

    var name: String? {
        switch self {
        case .point(let p): return p.name
        case .lineString(let l): return l.name
        case .polygon(let p): return p.name
        }
    }

    var details: String? {
        switch self {
        case .point(let p): return p.details
        case .lineString(let l): return l.details
        case .polygon(let p): return p.details
        }
    }

    var attributes: [String: String] {
        switch self {
        case .point(let p): return p.attributes
        case .lineString(let l): return l.attributes
        case .polygon(let p): return p.attributes
        }
    }

    var coordinates: [CLLocationCoordinate2D] {
        switch self {
        case .point(let p): return [p.coordinate]
        case .lineString(let l): return l.coordinates
        case .polygon(let p): return p.outerBoundary
        }
    }

    var vehicle: String? { attributes["vehicle"] }
    var departure: String? { attributes["departure"] }
    var arrival: String? { attributes["arrival"] }
    var kind: String? { attributes["kind"]?.lowercased() }
    var isConnection: Bool { kind == "connection" || kind == "transfer" }

    var durationMinutes: Int? {
        guard let dep = departure.flatMap(KMLFeature.minutesSinceMidnight),
              let arr = arrival.flatMap(KMLFeature.minutesSinceMidnight) else {
            return nil
        }
        var diff = arr - dep
        if diff < 0 { diff += 24 * 60 }
        return diff
    }

    var duration: String? {
        guard let mins = durationMinutes else { return nil }
        return KMLFeature.formatDuration(minutes: mins)
    }

    private static func minutesSinceMidnight(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else { return nil }
        return hours * 60 + minutes
    }

    private static func formatDuration(minutes total: Int) -> String {
        let h = total / 60
        let m = total % 60
        if h == 0 { return "\(m)min" }
        if m == 0 { return "\(h)h" }
        return String(format: "%dh%02d", h, m)
    }

    var days: [Int] {
        guard let s = attributes["days"] else { return [] }
        return s.split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .sorted()
    }

    var nights: Int {
        guard let s = attributes["nights"] else { return 0 }
        return Int(s) ?? 0
    }
    var hasOvernight: Bool { nights > 0 }

    var isSuggested: Bool {
        switch attributes["suggested"]?.lowercased() {
        case "true", "1", "yes": return true
        default: return false
        }
    }

    struct Point: Identifiable {
        let id = UUID()
        var name: String?
        var details: String?
        var attributes: [String: String]
        var coordinate: CLLocationCoordinate2D
    }

    struct LineString: Identifiable {
        let id = UUID()
        var name: String?
        var details: String?
        var attributes: [String: String]
        var coordinates: [CLLocationCoordinate2D]
    }

    struct Polygon: Identifiable {
        let id = UUID()
        var name: String?
        var details: String?
        var attributes: [String: String]
        var outerBoundary: [CLLocationCoordinate2D]
        var innerBoundaries: [[CLLocationCoordinate2D]]
    }
}
