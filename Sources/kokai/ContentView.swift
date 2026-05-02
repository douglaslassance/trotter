import AppKit
import CoreLocation
import CryptoKit
import MapKit
import SwiftUI

private func iconForKind(_ kind: String?) -> String {
    switch kind?.lowercased() {
    case "city": return "building.2.fill"
    case "town": return "house.fill"
    case "village": return "house"
    case "restaurant", "food", "dining": return "fork.knife"
    case "cafe", "coffee": return "mug.fill"
    case "bar", "pub", "izakaya": return "wineglass"
    case "bookstore", "books": return "books.vertical.fill"
    case "record", "records", "music": return "opticaldisc.fill"
    case "craft", "crafts", "artisan": return "paintbrush.pointed.fill"
    case "architecture", "building": return "building.2.crop.circle.fill"
    case "park", "natural_park", "nature": return "leaf.fill"
    case "viewpoint", "lookout": return "eye.fill"
    case "temple": return "building.columns.fill"
    case "shrine": return "building.columns"
    case "museum": return "photo.artframe"
    case "gallery": return "photo.fill"
    case "landmark": return "mappin"
    case "beach": return "water.waves"
    case "onsen", "hot_spring", "bath": return "drop.fill"
    case "accommodation", "hotel", "ryokan": return "bed.double.fill"
    case "shopping", "market": return "bag.fill"
    case "cave": return "circle.bottomhalf.filled.inverse"
    case "garden": return "leaf"
    case "castle": return "shield.fill"
    case "connection", "transfer": return "arrow.triangle.swap"
    case "airport": return "airplane"
    case "station": return "tram.fill"
    case "port", "harbor": return "ferry.fill"
    default: return "mappin"
    }
}

// Kinds that typically have a Wikipedia article worth pulling an image from.
// Cafes, bars, bookstores, record shops, craft stores and individual restaurants
// rarely have one, so we skip the search and fall back to the gradient + icon.
private func kindUsesImageSearch(_ kind: String?) -> Bool {
    switch kind?.lowercased() {
    case "cafe", "coffee",
         "bar", "pub", "izakaya",
         "bookstore", "books",
         "record", "records", "music",
         "craft", "crafts", "artisan",
         "restaurant", "food", "dining",
         "shopping", "market":
        return false
    default:
        return true
    }
}

private func humanizedKind(_ kind: String?) -> String? {
    guard let kind = kind?.lowercased(), !kind.isEmpty else { return nil }
    switch kind {
    case "natural_park": return "Natural Park"
    case "hot_spring": return "Hot Spring"
    case "rental_car": return "Rental Car"
    default:
        return kind.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private func vehicleIcon(_ vehicle: String?) -> String? {
    guard let v = vehicle?.lowercased(), !v.isEmpty else { return nil }
    switch v {
    case "shinkansen", "bullet": return "train.side.front.car"
    case "train", "limited_express", "rail": return "tram.fill"
    case "tram", "streetcar": return "tram"
    case "metro", "subway": return "tram.tunnel.fill"
    case "bus": return "bus.fill"
    case "car", "rental_car", "drive": return "car.fill"
    case "ferry", "boat", "ship": return "ferry.fill"
    case "bicycle", "bike": return "bicycle"
    case "walk", "foot": return "figure.walk"
    case "plane", "flight": return "airplane"
    default: return "mappin"
    }
}

private func youtubeSearchURL(for feature: KMLFeature) -> URL? {
    guard let name = feature.name, !name.isEmpty else { return nil }
    var components = URLComponents(string: "https://www.youtube.com/results")
    components?.queryItems = [URLQueryItem(name: "search_query", value: name)]
    return components?.url
}

private func googleMapsURL(coord: CLLocationCoordinate2D, name: String?) -> URL? {
    var components = URLComponents(string: "https://www.google.com/maps/search/")
    let q: String
    if let name, !name.isEmpty {
        q = "\(name)"
    } else {
        q = "\(coord.latitude),\(coord.longitude)"
    }
    components?.queryItems = [
        URLQueryItem(name: "api", value: "1"),
        URLQueryItem(name: "query", value: q),
        URLQueryItem(name: "ll", value: "\(coord.latitude),\(coord.longitude)"),
    ]
    return components?.url
}

private func bookingURL(for feature: KMLFeature, country: String?) -> URL? {
    if let explicit = feature.attributes["booking_url"], !explicit.isEmpty,
       let url = URL(string: explicit) {
        return url
    }
    let name = feature.name ?? ""
    var parts: [String] = []
    if !name.isEmpty { parts.append(name) }
    let vehicleTerm = vehicleSearchTerm(feature.vehicle)
    if !vehicleTerm.isEmpty { parts.append(vehicleTerm) }
    if let kindTerm = kindSearchTerm(feature.kind) { parts.append(kindTerm) }
    if let country, !country.isEmpty { parts.append(country) }
    parts.append(bookingActionTerm(for: feature.kind))
    guard !parts.isEmpty else { return nil }
    let query = parts.joined(separator: " ")
    var components = URLComponents(string: "https://www.google.com/search")
    components?.queryItems = [URLQueryItem(name: "q", value: query)]
    return components?.url
}

private func kindSearchTerm(_ kind: String?) -> String? {
    switch kind?.lowercased() {
    case "hotel", "ryokan", "accommodation": return "hotel"
    case "restaurant", "food", "dining": return "restaurant"
    default: return nil
    }
}

private func bookingActionTerm(for kind: String?) -> String {
    switch kind?.lowercased() {
    case "restaurant", "food", "dining": return "reservation"
    case "hotel", "ryokan", "accommodation": return "booking"
    default: return "tickets booking"
    }
}

private func vehicleSearchTerm(_ vehicle: String?) -> String {
    guard let v = vehicle?.lowercased(), !v.isEmpty else { return "" }
    switch v {
    case "shinkansen", "bullet": return "shinkansen"
    case "train", "limited_express", "rail": return "train"
    case "tram", "streetcar": return "tram"
    case "metro", "subway": return "metro"
    case "bus": return "bus"
    case "car", "rental_car", "drive": return "car rental"
    case "ferry", "boat", "ship": return "ferry"
    case "bicycle", "bike": return ""
    case "walk", "foot": return ""
    case "plane", "flight": return "flight"
    default: return ""
    }
}

private func vehicleWikipediaQuery(_ vehicle: String?) -> String? {
    guard let v = vehicle?.lowercased(), !v.isEmpty else { return nil }
    switch v {
    case "shinkansen", "bullet": return "Shinkansen"
    case "train", "limited_express", "rail": return "Limited_express"
    case "tram", "streetcar": return "Tram"
    case "metro", "subway": return "Rapid_transit"
    case "bus": return "Bus"
    case "car", "rental_car", "drive": return "Car"
    case "ferry", "boat", "ship": return "Ferry"
    case "bicycle", "bike": return "Bicycle"
    case "walk", "foot": return "Walking"
    case "plane", "flight": return "Airliner"
    default: return nil
    }
}

private let dayPalette: [Color] = [
    Color(red: 0.96, green: 0.36, blue: 0.36), // Day 1 — red
    Color(red: 0.97, green: 0.56, blue: 0.27), // Day 2 — orange
    Color(red: 0.95, green: 0.78, blue: 0.27), // Day 3 — amber
    Color(red: 0.50, green: 0.80, blue: 0.32), // Day 4 — green
    Color(red: 0.20, green: 0.75, blue: 0.67), // Day 5 — teal
    Color(red: 0.27, green: 0.55, blue: 0.88), // Day 6 — blue
    Color(red: 0.45, green: 0.42, blue: 0.85), // Day 7 — indigo
    Color(red: 0.70, green: 0.40, blue: 0.85), // Day 8 — purple
    Color(red: 0.95, green: 0.45, blue: 0.75), // Day 9 — pink
    Color(red: 0.60, green: 0.20, blue: 0.20), // Day 10 — burgundy
    Color(red: 0.71, green: 0.40, blue: 0.18), // Day 11 — rust
    Color(red: 0.71, green: 0.54, blue: 0.18), // Day 12 — ochre
    Color(red: 0.42, green: 0.56, blue: 0.14), // Day 13 — olive
    Color(red: 0.18, green: 0.42, blue: 0.43), // Day 14 — petrol
    Color(red: 0.11, green: 0.30, blue: 0.48), // Day 15 — navy
    Color(red: 0.36, green: 0.23, blue: 0.49), // Day 16 — deep violet
    Color(red: 0.55, green: 0.20, blue: 0.35), // Day 17 — wine
    Color(red: 0.30, green: 0.45, blue: 0.30), // Day 18 — fern
    Color(red: 0.50, green: 0.35, blue: 0.55), // Day 19 — orchid
    Color(red: 0.18, green: 0.45, blue: 0.55), // Day 20 — deep cyan
    Color(red: 0.55, green: 0.40, blue: 0.30), // Day 21 — sienna
    Color(red: 0.30, green: 0.55, blue: 0.45), // Day 22 — sea green
    Color(red: 0.50, green: 0.35, blue: 0.30), // Day 23 — chestnut
    Color(red: 0.40, green: 0.50, blue: 0.65), // Day 24 — slate blue
]

private func paletteColor(_ index: Int) -> Color {
    let count = dayPalette.count
    return dayPalette[((index % count) + count) % count]
}

private func blendColors(_ a: Color, _ b: Color, t: Double) -> Color {
    let na = NSColor(a).usingColorSpace(.sRGB) ?? NSColor(a)
    let nb = NSColor(b).usingColorSpace(.sRGB) ?? NSColor(b)
    let clamped = max(0, min(1, t))
    return Color(
        red: na.redComponent + (nb.redComponent - na.redComponent) * clamped,
        green: na.greenComponent + (nb.greenComponent - na.greenComponent) * clamped,
        blue: na.blueComponent + (nb.blueComponent - na.blueComponent) * clamped
    )
}

private func color(forDay day: Int, anchors: [Int]) -> Color {
    guard !anchors.isEmpty else { return paletteColor(0) }
    if day <= anchors.first! { return paletteColor(0) }
    if day >= anchors.last! { return paletteColor(anchors.count - 1) }
    for i in 0..<anchors.count - 1 {
        let lo = anchors[i], hi = anchors[i + 1]
        if day >= lo && day <= hi {
            let span = max(1, hi - lo)
            let t = Double(day - lo) / Double(span)
            return blendColors(paletteColor(i), paletteColor(i + 1), t: t)
        }
    }
    return paletteColor(0)
}

// Backward-compatible no-anchor variant (used where no document is available, e.g. HeroImage fallback).
private func color(forDay day: Int) -> Color {
    paletteColor(max(0, day - 1))
}

private func dayShape(_ days: [Int], anchors: [Int]) -> AnyShapeStyle {
    if days.isEmpty {
        return AnyShapeStyle(Color.gray)
    }
    if days.count == 1 {
        return AnyShapeStyle(color(forDay: days[0], anchors: anchors))
    }
    let first = color(forDay: days.first!, anchors: anchors)
    let last = color(forDay: days.last!, anchors: anchors)
    return AnyShapeStyle(LinearGradient(
        colors: [first, last],
        startPoint: .top,
        endPoint: .bottom
    ))
}

private func dayShapeHorizontal(_ days: [Int], anchors: [Int]) -> AnyShapeStyle {
    if days.isEmpty {
        return AnyShapeStyle(Color.gray)
    }
    if days.count == 1 {
        return AnyShapeStyle(color(forDay: days[0], anchors: anchors))
    }
    let first = color(forDay: days.first!, anchors: anchors)
    let last = color(forDay: days.last!, anchors: anchors)
    return AnyShapeStyle(LinearGradient(
        colors: [first, last],
        startPoint: .leading,
        endPoint: .trailing
    ))
}

private func dayShapeHorizontalFallback(_ days: [Int]) -> AnyShapeStyle {
    if days.isEmpty {
        return AnyShapeStyle(Color.gray)
    }
    if days.count == 1 {
        return AnyShapeStyle(color(forDay: days[0]))
    }
    return AnyShapeStyle(LinearGradient(
        colors: [color(forDay: days.first!), color(forDay: days.last!)],
        startPoint: .leading,
        endPoint: .trailing
    ))
}

private func formatDate(_ date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated).day())
}

private func bezierMid(from start: CLLocationCoordinate2D,
                       to end: CLLocationCoordinate2D,
                       perpOffset: Double) -> CLLocationCoordinate2D {
    let dLat = end.latitude - start.latitude
    let dLon = end.longitude - start.longitude
    let length = sqrt(dLat * dLat + dLon * dLon)
    guard length > 0.0001 else {
        return CLLocationCoordinate2D(
            latitude: (start.latitude + end.latitude) / 2,
            longitude: (start.longitude + end.longitude) / 2
        )
    }
    let perpLat = dLon / length
    let perpLon = -dLat / length
    return CLLocationCoordinate2D(
        latitude: (start.latitude + end.latitude) / 2 + perpLat * perpOffset,
        longitude: (start.longitude + end.longitude) / 2 + perpLon * perpOffset
    )
}

private func bezierSegment(from start: CLLocationCoordinate2D,
                           to end: CLLocationCoordinate2D,
                           perpOffset: Double,
                           samples: Int = 24) -> [CLLocationCoordinate2D] {
    let mid = bezierMid(from: start, to: end, perpOffset: perpOffset)
    var points: [CLLocationCoordinate2D] = []
    for i in 0...samples {
        let t = Double(i) / Double(samples)
        let lat = (1 - t) * (1 - t) * start.latitude
            + 2 * (1 - t) * t * mid.latitude
            + t * t * end.latitude
        let lon = (1 - t) * (1 - t) * start.longitude
            + 2 * (1 - t) * t * mid.longitude
            + t * t * end.longitude
        points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }
    return points
}

private let lineCurveRatio: Double = 0.05

private func segmentLength(from start: CLLocationCoordinate2D,
                           to end: CLLocationCoordinate2D) -> Double {
    let dLat = end.latitude - start.latitude
    let dLon = end.longitude - start.longitude
    return sqrt(dLat * dLat + dLon * dLon)
}

private func curveOffset(from start: CLLocationCoordinate2D,
                         to end: CLLocationCoordinate2D) -> Double {
    segmentLength(from: start, to: end) * lineCurveRatio
}

private func curvedPath(_ original: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
    guard original.count >= 2 else { return original }
    var result: [CLLocationCoordinate2D] = []
    for i in 0..<original.count - 1 {
        let segment = bezierSegment(from: original[i], to: original[i + 1],
                                    perpOffset: curveOffset(from: original[i],
                                                            to: original[i + 1]))
        if i == 0 {
            result.append(contentsOf: segment)
        } else {
            result.append(contentsOf: segment.dropFirst())
        }
    }
    return result
}

private func bezierApex(from start: CLLocationCoordinate2D,
                        to end: CLLocationCoordinate2D,
                        perpOffset: Double) -> CLLocationCoordinate2D {
    let control = bezierMid(from: start, to: end, perpOffset: perpOffset)
    return CLLocationCoordinate2D(
        latitude: 0.25 * start.latitude + 0.5 * control.latitude + 0.25 * end.latitude,
        longitude: 0.25 * start.longitude + 0.5 * control.longitude + 0.25 * end.longitude
    )
}

private func bezierPoint(at t: Double,
                         from start: CLLocationCoordinate2D,
                         to end: CLLocationCoordinate2D,
                         perpOffset: Double) -> CLLocationCoordinate2D {
    let control = bezierMid(from: start, to: end, perpOffset: perpOffset)
    let u = 1 - t
    return CLLocationCoordinate2D(
        latitude: u * u * start.latitude + 2 * u * t * control.latitude + t * t * end.latitude,
        longitude: u * u * start.longitude + 2 * u * t * control.longitude + t * t * end.longitude
    )
}

private func curvedApex(of original: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
    guard !original.isEmpty else { return nil }
    if original.count == 1 { return original[0] }
    if original.count == 2 {
        return bezierApex(from: original[0], to: original[1],
                          perpOffset: curveOffset(from: original[0], to: original[1]))
    }
    let mid = original.count / 2
    if original.count.isMultiple(of: 2) {
        return bezierApex(from: original[mid - 1], to: original[mid],
                          perpOffset: curveOffset(from: original[mid - 1], to: original[mid]))
    }
    return original[mid]
}

struct ContentView: View {
    @Bindable var nav: NavigationModel
    @State private var selectionID: UUID?
    @State private var visibleDays: [Int] = []
    @State private var visibleFeatureIDs: Set<UUID> = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let level = nav.current {
                MapLevelView(level: level,
                             nav: nav,
                             selection: $selectionID,
                             visibleDays: $visibleDays,
                             visibleFeatureIDs: $visibleFeatureIDs)
                    .id(level.id)
            } else {
                EmptyState()
            }
            VStack(alignment: .leading, spacing: 8) {
                BreadcrumbBar(nav: nav)
                if let level = nav.current {
                    TripInfoBar(document: level.document,
                                visibleDays: visibleDays,
                                visibleFeatureIDs: visibleFeatureIDs)
                    DayLegend(document: level.document, days: visibleDays)
                }
            }
            .padding(12)
        }
        .onChange(of: nav.current?.id) {
            selectionID = nil
            visibleDays = []
            visibleFeatureIDs = []
        }
    }
}

private struct TripInfoBar: View {
    let document: KMLDocument
    let visibleDays: [Int]
    let visibleFeatureIDs: Set<UUID>

    private var visibleDaySet: Set<Int> { Set(visibleDays) }

    private var span: (first: Int, last: Int)? {
        guard let first = visibleDays.min(), let last = visibleDays.max() else { return nil }
        return (first, last)
    }

    private var numDays: Int? {
        let count = visibleDays.count
        return count > 0 ? count : nil
    }

    private var numNights: Int? {
        let total = document.features.reduce(0) { acc, feature in
            guard feature.nights > 0,
                  visibleFeatureIDs.contains(feature.id),
                  !feature.days.isEmpty,
                  Set(feature.days).isSubset(of: visibleDaySet)
            else { return acc }
            return acc + feature.nights
        }
        return total > 0 ? total : nil
    }

    var body: some View {
        HStack(spacing: 10) {
            if let span,
               let start = document.date(forDay: span.first),
               let end = document.date(forDay: span.last) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("\(formatDate(start)) to \(formatDate(end))")
                        .font(.caption.bold())
                        .monospacedDigit()
                }
            }
            if let numDays {
                HStack(spacing: 4) {
                    Image(systemName: "sun.max")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Text("\(numDays) days")
                        .font(.caption.bold())
                        .monospacedDigit()
                }
            }
            if let numNights, numNights > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                    Text("\(numNights) nights")
                        .font(.caption.bold())
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(AnyShapeStyle(.separator), lineWidth: 0.5))
        .shadow(radius: 4, y: 2)
    }
}

private struct DayLegend: View {
    let document: KMLDocument
    let days: [Int]
    @State private var weatherByDay: [Int: WeatherSummary] = [:]

    private struct WeekRow: Identifiable {
        let id = UUID()
        let cells: [Int?]   // 7 entries, nil = empty placeholder
    }

    private func coordinate(for day: Int) -> CLLocationCoordinate2D? {
        for feature in document.features where feature.days.contains(day) {
            if let coord = feature.coordinates.first { return coord }
        }
        return nil
    }

    // Monday = 0, Sunday = 6
    private func mondayIndex(of date: Date) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let weekday = cal.component(.weekday, from: date) // 1=Sun..7=Sat
        return (weekday + 5) % 7
    }

    private var rows: [WeekRow] {
        guard let firstDay = days.first,
              let firstDate = document.date(forDay: firstDay) else { return [] }
        let leading = mondayIndex(of: firstDate)
        var cells: [Int?] = Array(repeating: nil, count: leading)
        for day in days { cells.append(day) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { start in
            WeekRow(cells: Array(cells[start..<start + 7]))
        }
    }

    private struct WeatherTally: Identifiable {
        var id: String { label }
        let icon: String
        let label: String
        var count: Int
    }

    private var weatherCounts: [WeatherTally] {
        var sun = 0, partly = 0, cloudy = 0, fog = 0, rain = 0, drizzle = 0, snow = 0, storm = 0
        for day in days {
            guard let summary = weatherByDay[day] else { continue }
            switch summary.code {
            case 0, 1: sun += 1
            case 2: partly += 1
            case 3: cloudy += 1
            case 45, 48: fog += 1
            case 51, 53, 55, 56, 57: drizzle += 1
            case 61, 63, 65, 66, 67, 80, 81, 82: rain += 1
            case 71, 73, 75, 77, 85, 86: snow += 1
            case 95, 96, 99: storm += 1
            default: break
            }
        }
        let entries: [WeatherTally] = [
            .init(icon: "sun.max.fill", label: "Sunny", count: sun),
            .init(icon: "cloud.sun.fill", label: "Partly cloudy", count: partly),
            .init(icon: "cloud.fill", label: "Cloudy", count: cloudy),
            .init(icon: "cloud.fog.fill", label: "Foggy", count: fog),
            .init(icon: "cloud.drizzle.fill", label: "Drizzle", count: drizzle),
            .init(icon: "cloud.rain.fill", label: "Rainy", count: rain),
            .init(icon: "cloud.snow.fill", label: "Snow", count: snow),
            .init(icon: "cloud.bolt.rain.fill", label: "Storm", count: storm),
        ]
        return entries.filter { $0.count > 0 }
    }

    private static let weekdayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        if !days.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(Array(Self.weekdayLetters.enumerated()), id: \.offset) { _, letter in
                            Text(letter)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                        }
                    }
                    ForEach(rows) { row in
                        HStack(spacing: 4) {
                            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, day in
                                cell(for: day)
                            }
                        }
                    }
                }
                if !weatherCounts.isEmpty {
                    Rectangle()
                        .fill(Color.primary.opacity(0.18))
                        .frame(height: 1)
                    HStack(spacing: 10) {
                        ForEach(weatherCounts) { entry in
                            HStack(spacing: 3) {
                                Image(systemName: entry.icon)
                                    .symbolRenderingMode(.monochrome)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Text("\(entry.count)")
                                    .font(.caption.bold())
                                    .monospacedDigit()
                            }
                            .help(entry.label)
                        }
                    }
                }
            }
            .task(id: legendKey) { await loadWeather() }
            .frame(width: 220, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(AnyShapeStyle(.separator), lineWidth: 0.5))
            .shadow(radius: 4, y: 2)
        }
    }

    @ViewBuilder
    private func cell(for day: Int?) -> some View {
        if let day {
            let dayColor = color(forDay: day, anchors: document.dayAnchors)
            VStack(spacing: 1) {
                ZStack {
                    Circle()
                        .fill(dayColor.opacity(0.18))
                        .frame(width: 22, height: 22)
                    if let summary = weatherByDay[day] {
                        Image(systemName: weatherIcon(for: summary.code))
                            .symbolRenderingMode(.monochrome)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(dayColor)
                            .help(weatherTooltip(for: summary))
                    } else {
                        Circle()
                            .fill(dayColor)
                            .frame(width: 8, height: 8)
                    }
                }
                if let date = document.date(forDay: day) {
                    let cal = Calendar(identifier: .gregorian)
                    let d = cal.component(.day, from: date)
                    let m = cal.component(.month, from: date)
                    Text("\(d)-\(m)")
                        .font(.system(size: 8, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 28)
        } else {
            Color.clear.frame(width: 28, height: 32)
        }
    }

    private var legendKey: String {
        days.map(String.init).joined(separator: ",")
    }

    private func loadWeather() async {
        guard document.showsWeather else {
            await MainActor.run { weatherByDay = [:] }
            return
        }
        var results: [Int: WeatherSummary] = [:]
        for day in days {
            guard let coord = coordinate(for: day),
                  let date = document.date(forDay: day) else { continue }
            if let summary = await WeatherResolver.shared.summary(for: coord, date: date) {
                results[day] = summary
            }
        }
        let collected = results
        await MainActor.run { weatherByDay = collected }
    }
}

private struct EmptyState: View {
    var body: some View {
        ContentUnavailableView("No KML loaded",
                               systemImage: "map",
                               description: Text("Open a .kml file with ⌘O or drop one on the app."))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BreadcrumbBar: View {
    @Bindable var nav: NavigationModel

    var body: some View {
        if !nav.stack.isEmpty {
            HStack(spacing: 6) {
                Button { nav.goHome() } label: {
                    Image(systemName: "map.fill")
                }
                .buttonStyle(.borderless)
                .help("Show the full trip map")

                ForEach(Array(nav.stack.enumerated()), id: \.element.id) { index, level in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button(level.title) { nav.go(to: level) }
                        .buttonStyle(.borderless)
                        .fontWeight(level == nav.current ? .semibold : .regular)
                        .foregroundStyle(level == nav.current ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(AnyShapeStyle(.separator), lineWidth: 0.5))
            .shadow(radius: 4, y: 2)
        }
    }
}

private enum BadgeDetail {
    case hidden, iconOnly, full
}

private func badgeDetail(forSpan span: Double) -> BadgeDetail {
    if span > 6.0 { return .hidden }
    if span > 3.0 { return .iconOnly }
    return .full
}

private enum MarkerDetail {
    case small, full
}

private func markerDetail(forSpan span: Double) -> MarkerDetail {
    span > 3.0 ? .small : .full
}

private struct MapLevelView: View {
    let level: NavigationModel.Level
    @Bindable var nav: NavigationModel
    @Binding var selection: UUID?
    @Binding var visibleDays: [Int]
    @Binding var visibleFeatureIDs: Set<UUID>
    @State private var position: MapCameraPosition
    @State private var latitudeSpan: Double = 0

    init(level: NavigationModel.Level,
         nav: NavigationModel,
         selection: Binding<UUID?>,
         visibleDays: Binding<[Int]>,
         visibleFeatureIDs: Binding<Set<UUID>>) {
        self.level = level
        self.nav = nav
        self._selection = selection
        self._visibleDays = visibleDays
        self._visibleFeatureIDs = visibleFeatureIDs
        if let saved = nav.region(for: level.id) {
            _position = State(initialValue: .region(saved))
        } else {
            let initialRect = Self.boundingRect(for: level.document.features)
            _position = State(initialValue: initialRect.map { .rect($0) } ?? .automatic)
        }
    }

    var body: some View {
        Map(position: $position, selection: $selection) {
            ForEach(level.document.features) { feature in
                content(for: feature)
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .automatic,
                            emphasis: .muted,
                            pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .continuous) { ctx in
            latitudeSpan = ctx.region.span.latitudeDelta
            updateVisibleDays(region: ctx.region)
            nav.saveRegion(ctx.region, for: level.id)
        }
        .onChange(of: nav.fitTrigger) { _, _ in
            if let rect = Self.boundingRect(for: level.document.features) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    position = .rect(rect)
                }
            }
        }
    }

    private func updateVisibleDays(region: MKCoordinateRegion) {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        var seenDays = Set<Int>()
        var seenFeatures = Set<UUID>()
        for feature in level.document.features where !feature.days.isEmpty {
            let coords = feature.coordinates
            let inside = coords.contains { c in
                c.latitude >= minLat && c.latitude <= maxLat &&
                c.longitude >= minLon && c.longitude <= maxLon
            }
            if inside {
                seenDays.formUnion(feature.days)
                seenFeatures.insert(feature.id)
            }
        }
        let sorted = seenDays.sorted()
        if sorted != visibleDays { visibleDays = sorted }
        if seenFeatures != visibleFeatureIDs { visibleFeatureIDs = seenFeatures }
    }

    @MapContentBuilder
    private func content(for feature: KMLFeature) -> some MapContent {
        switch feature {
        case .point(let point):
            let drillable = childExists(for: feature)
            let prominent = feature.nights > 0
            let detail = markerDetail(forSpan: latitudeSpan)
            let markerSize: CGFloat = {
                switch (detail, prominent) {
                case (.full, true): return 46
                case (.full, false): return 31
                case (.small, true): return 31
                case (.small, false): return 15
                }
            }()
            Annotation("", coordinate: point.coordinate, anchor: .center) {
                ZStack {
                    PlaceMarker(kind: feature.kind,
                                isDrillable: drillable,
                                isSelected: selection == feature.id,
                                days: feature.days,
                                nights: feature.nights,
                                detail: detail,
                                coordinate: point.coordinate,
                                document: level.document)
                    if detail == .full, let name = point.name, !name.isEmpty {
                        PlaceLabel(text: name, isDrillable: prominent)
                            .fixedSize()
                            .offset(y: prominent ? 37 : 23)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: markerSize, height: markerSize)
                .popover(isPresented: popoverBinding(for: feature.id),
                         arrowEdge: .top) {
                    PlacePopover(
                        feature: feature,
                        document: level.document,
                        canOpen: drillable,
                        onOpen: { drill(into: feature) }
                    )
                }
            }
            .tag(feature.id)

            if detail == .full {
                ForEach(arrivalBadges(for: feature), id: \.day) { badge in
                    Annotation("", coordinate: badge.coord, anchor: .center) {
                        EntryExitBadge(time: badge.time)
                            .fixedSize()
                            .allowsHitTesting(false)
                    }
                }
                ForEach(departureBadges(for: feature), id: \.day) { badge in
                    Annotation("", coordinate: badge.coord, anchor: .center) {
                        EntryExitBadge(time: badge.time)
                            .fixedSize()
                            .allowsHitTesting(false)
                    }
                }
            }

        case .lineString(let line):
            transitContent(feature: feature, line: line)

        case .polygon(let polygon):
            MapPolygon(coordinates: polygon.outerBoundary)
                .foregroundStyle(.blue.opacity(0.3))
                .stroke(.blue, lineWidth: 2)
        }
    }

    @MapContentBuilder
    private func transitContent(feature: KMLFeature,
                                line: KMLFeature.LineString) -> some MapContent {
        MapPolyline(coordinates: curvedPath(line.coordinates))
            .stroke(dayShapeHorizontal(feature.days, anchors: level.document.dayAnchors), lineWidth: 3)
        if let mid = curvedApex(of: line.coordinates) {
            Annotation("", coordinate: mid, anchor: .center) {
                TransitBadge(feature: feature,
                             document: level.document,
                             isSelected: selection == feature.id,
                             detail: badgeDetail(forSpan: latitudeSpan))
                    .popover(isPresented: popoverBinding(for: feature.id),
                             arrowEdge: .top) {
                        TransitPopover(feature: feature, document: level.document)
                    }
                    .onTapGesture { selection = feature.id }
            }
            .tag(feature.id)
        }
    }

    private func popoverBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selection == id },
            set: { isOn in
                if isOn { selection = id }
                else if selection == id { selection = nil }
            }
        )
    }

    private struct DayBadge {
        let day: Int
        let time: String
        let coord: CLLocationCoordinate2D
    }

    private func arrivalBadges(for feature: KMLFeature) -> [DayBadge] {
        guard let placeCoord = feature.coordinates.first else { return [] }
        var results: [DayBadge] = []
        for day in feature.days {
            guard let inbound = level.document.inboundTransit(at: placeCoord, day: day),
                  case .lineString(let line) = inbound,
                  line.coordinates.count >= 2,
                  let arrival = inbound.arrival else { continue }
            let from = line.coordinates[line.coordinates.count - 2]
            let to = line.coordinates[line.coordinates.count - 1]
            let coord = bezierPoint(at: 0.85,
                                    from: from, to: to,
                                    perpOffset: curveOffset(from: from, to: to))
            results.append(DayBadge(day: day, time: arrival, coord: coord))
        }
        return results
    }

    private func departureBadges(for feature: KMLFeature) -> [DayBadge] {
        guard let placeCoord = feature.coordinates.first else { return [] }
        var results: [DayBadge] = []
        for day in feature.days {
            guard let outbound = level.document.outboundTransit(at: placeCoord, day: day),
                  case .lineString(let line) = outbound,
                  line.coordinates.count >= 2,
                  let departure = outbound.departure else { continue }
            let from = line.coordinates[0]
            let to = line.coordinates[1]
            let coord = bezierPoint(at: 0.15,
                                    from: from, to: to,
                                    perpOffset: curveOffset(from: from, to: to))
            results.append(DayBadge(day: day, time: departure, coord: coord))
        }
        return results
    }

    private func entryBadgeCoord(for feature: KMLFeature) -> CLLocationCoordinate2D? {
        guard let coord = feature.coordinates.first,
              let firstDay = feature.days.first,
              let inbound = level.document.inboundTransit(at: coord, day: firstDay),
              case .lineString(let line) = inbound,
              line.coordinates.count >= 2 else { return nil }
        let from = line.coordinates[line.coordinates.count - 2]
        let to = line.coordinates[line.coordinates.count - 1]
        return bezierPoint(at: 0.85,
                           from: from, to: to,
                           perpOffset: curveOffset(from: from, to: to))
    }

    private func exitBadgeCoord(for feature: KMLFeature) -> CLLocationCoordinate2D? {
        guard let coord = feature.coordinates.first,
              let lastDay = feature.days.last,
              let outbound = level.document.outboundTransit(at: coord, day: lastDay),
              case .lineString(let line) = outbound,
              line.coordinates.count >= 2 else { return nil }
        let from = line.coordinates[0]
        let to = line.coordinates[1]
        return bezierPoint(at: 0.15,
                           from: from, to: to,
                           perpOffset: curveOffset(from: from, to: to))
    }

    private func arrivalInfo(for feature: KMLFeature) -> (date: Date, time: String)? {
        guard let coord = feature.coordinates.first,
              let firstDay = feature.days.first,
              let arrival = level.document.times(at: coord, day: firstDay)?.arrival,
              let date = level.document.date(forDay: firstDay) else { return nil }
        return (date, arrival)
    }

    private func departureInfo(for feature: KMLFeature) -> (date: Date, time: String)? {
        guard let coord = feature.coordinates.first,
              let lastDay = feature.days.last,
              let departure = level.document.times(at: coord, day: lastDay)?.departure,
              let date = level.document.date(forDay: lastDay) else { return nil }
        return (date, departure)
    }

    private func childExists(for feature: KMLFeature) -> Bool {
        guard case .point = feature, let name = feature.name else { return false }
        return nav.canDrillDown(into: name)
    }

    private func drill(into feature: KMLFeature) {
        guard let name = feature.name else { return }
        if (try? nav.drillDown(matching: name)) == true {
            selection = nil
        }
    }

    private func midpoint(of coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !coords.isEmpty else { return nil }
        if coords.count == 1 { return coords[0] }
        let mid = coords.count / 2
        if coords.count.isMultiple(of: 2) {
            let a = coords[mid - 1], b = coords[mid]
            return CLLocationCoordinate2D(
                latitude: (a.latitude + b.latitude) / 2,
                longitude: (a.longitude + b.longitude) / 2
            )
        }
        return coords[mid]
    }

    static func boundingRect(for features: [KMLFeature]) -> MKMapRect? {
        let coords = features.flatMap(\.coordinates)
        guard !coords.isEmpty else { return nil }
        let points = coords.map { MKMapPoint($0) }
        var rect = MKMapRect(origin: points[0], size: .init(width: 0, height: 0))
        for p in points.dropFirst() {
            rect = rect.union(MKMapRect(origin: p, size: .init(width: 0, height: 0)))
        }
        let padX = max(rect.size.width * 0.2, 1000)
        let padY = max(rect.size.height * 0.2, 1000)
        return rect.insetBy(dx: -padX, dy: -padY)
    }
}

private struct PlaceMarker: View {
    let kind: String?
    let isDrillable: Bool
    let isSelected: Bool
    let days: [Int]
    let nights: Int
    var detail: MarkerDetail = .full
    var coordinate: CLLocationCoordinate2D? = nil
    var document: KMLDocument? = nil
    @State private var isHovering = false
    @State private var hasBadWeather = false

    private var displaysLarge: Bool { nights > 0 }

    private var size: CGFloat {
        switch (detail, displaysLarge) {
        case (.full, true): return 46
        case (.full, false): return 31
        case (.small, true): return 31
        case (.small, false): return 15
        }
    }

    private var iconSize: CGFloat {
        switch (detail, displaysLarge) {
        case (.full, true): return 20
        case (.full, false): return 14
        case (.small, true): return 14
        case (.small, false): return 0
        }
    }

    private var borderWidth: CGFloat {
        let base: CGFloat
        switch (detail, displaysLarge) {
        case (.full, true): base = 3
        case (.full, false): base = 2
        case (.small, true): base = 2
        case (.small, false): base = 1.5
        }
        return isDrillable ? base : max(0.75, base * 0.5)
    }

    private var showsIcon: Bool {
        !(detail == .small && !displaysLarge)
    }

    private var scale: CGFloat {
        if isSelected { return 1.15 }
        if isHovering { return 1.12 }
        return 1.0
    }

    var body: some View {
        Group {
            if showsIcon {
                Image(systemName: iconForKind(kind))
                    .font(.system(size: iconSize, weight: .heavy))
                    .foregroundStyle(.white)
            } else {
                Color.clear
            }
        }
            .frame(width: size, height: size)
            .background(Circle().fill(dayShape(days, anchors: document?.dayAnchors ?? [])))
            .overlay(Circle().strokeBorder(.white, lineWidth: borderWidth))
            .overlay(alignment: .topTrailing) {
                if nights > 0 && detail == .full {
                    NightBadge(count: nights)
                        .offset(x: 4, y: -4)
                }
            }
            .overlay(alignment: .topLeading) {
                if hasBadWeather && detail == .full {
                    BadWeatherBadge()
                        .offset(x: -4, y: -4)
                }
            }
            .shadow(radius: isHovering || isSelected ? 5 : 3, y: 1)
            .scaleEffect(scale)
            .onHover { isHovering = $0 }
            .animation(.spring(response: 0.32, dampingFraction: 0.6), value: isHovering)
            .animation(.spring(response: 0.32, dampingFraction: 0.6), value: isSelected)
            .animation(.snappy, value: detail)
            .task(id: weatherKey) { await checkWeather() }
    }

    private var weatherKey: String {
        guard let coordinate else { return "" }
        return "\(coordinate.latitude),\(coordinate.longitude)|\(days.map(String.init).joined(separator: ","))"
    }

    private func checkWeather() async {
        guard let coordinate, let document, document.showsWeather, !days.isEmpty else { return }
        for day in days {
            guard let date = document.date(forDay: day) else { continue }
            if let summary = await WeatherResolver.shared.summary(for: coordinate, date: date),
               isBadWeather(code: summary.code) {
                await MainActor.run { hasBadWeather = true }
                return
            }
        }
        await MainActor.run { hasBadWeather = false }
    }
}

private struct BadWeatherBadge: View {
    var body: some View {
        Image(systemName: "cloud.bolt.rain.fill")
            .font(.system(size: 10, weight: .heavy))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.white)
            .padding(4)
            .background(Circle().fill(Color.yellow))
            .help("Bad weather expected")
    }
}

private struct NightBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "moon.fill")
                .font(.system(size: 8, weight: .bold))
            Text("\(count)")
                .font(.system(size: 9, weight: .heavy))
                .monospacedDigit()
        }
        .foregroundStyle(.indigo)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(.white, in: Capsule())
        .overlay(Capsule().strokeBorder(.indigo.opacity(0.4), lineWidth: 0.5))
    }
}

private struct EntryExitBadge: View {
    let time: String

    var body: some View {
        Text(time)
            .font(.system(size: 10, weight: .semibold))
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(.separator.opacity(0.5), lineWidth: 0.5))
    }
}

private struct PlaceLabel: View {
    let text: String
    let isDrillable: Bool

    var body: some View {
        Text(text)
            .font(.caption.weight(isDrillable ? .semibold : .regular))
            .foregroundStyle(isDrillable ? .primary : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(AnyShapeStyle(.separator), lineWidth: 0.5))
    }
}

private struct DayTimeline: View {
    let days: [Int]
    let document: KMLDocument
    var startTime: String? = nil
    var endTime: String? = nil
    var weatherByDay: [Int: WeatherSummary] = [:]

    private var gradientColors: [Color] {
        if days.isEmpty { return [.gray] }
        let anchors = document.dayAnchors
        if days.count == 1 {
            let c = color(forDay: days[0], anchors: anchors)
            return [c, c]
        }
        return [
            color(forDay: days.first!, anchors: anchors),
            color(forDay: days.last!, anchors: anchors),
        ]
    }

    private var startDate: Date? {
        days.first.flatMap { document.date(forDay: $0) }
    }

    private var endDate: Date? {
        days.last.flatMap { document.date(forDay: $0) }
    }

    private static let maxWeatherMarkers = 5

    private var displayedWeatherDays: Set<Int> {
        guard days.count > Self.maxWeatherMarkers else { return Set(days) }
        let step = Double(days.count - 1) / Double(Self.maxWeatherMarkers - 1)
        let indices = (0..<Self.maxWeatherMarkers).map { Int(round(Double($0) * step)) }
        return Set(indices.compactMap { $0 < days.count ? days[$0] : nil })
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if startTime != nil || startDate != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let startDate {
                        Text(formatDate(startDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    if let startTime {
                        Text(startTime)
                            .font(.caption.bold())
                            .monospacedDigit()
                    }
                }
            }
            Capsule()
                .fill(LinearGradient(
                    colors: gradientColors,
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 14)
                .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 0.5))
                .overlay(
                    HStack(spacing: 0) {
                        ForEach(days, id: \.self) { day in
                            ZStack {
                                if displayedWeatherDays.contains(day), let summary = weatherByDay[day] {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 20, height: 20)
                                        .overlay(Circle().stroke(.separator, lineWidth: 0.5))
                                    Image(systemName: weatherIcon(for: summary.code))
                                        .font(.system(size: 10, weight: .semibold))
                                        .symbolRenderingMode(.monochrome)
                                        .foregroundStyle(summary.isHistorical ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
                                        .help(weatherTooltip(for: summary))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                )
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
            if endTime != nil || endDate != nil {
                VStack(alignment: .trailing, spacing: 2) {
                    if let endDate {
                        Text(formatDate(endDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    if let endTime {
                        Text(endTime)
                            .font(.caption.bold())
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}

private struct TransitBadge: View {
    let feature: KMLFeature
    let document: KMLDocument
    let isSelected: Bool
    let detail: BadgeDetail

    @State private var validation: TransitValidator.Result?
    @State private var isHovering = false

    private var scale: CGFloat {
        if isSelected { return 1.1 }
        if isHovering { return 1.06 }
        return 1.0
    }

    var body: some View {
        Group {
            switch detail {
            case .hidden:
                Color.clear.frame(width: 1, height: 1)
            case .iconOnly:
                iconOnlyBody
            case .full:
                fullBody
            }
        }
        .opacity(detail == .hidden ? 0 : 1)
        .allowsHitTesting(detail != .hidden)
        .scaleEffect(scale)
        .onHover { isHovering = $0 }
        .animation(.snappy, value: detail)
        .animation(.spring(response: 0.32, dampingFraction: 0.6), value: isHovering)
        .animation(.spring(response: 0.32, dampingFraction: 0.6), value: isSelected)
        .task { await validate() }
    }

    private var iconOnlyBody: some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
                .overlay(Circle().stroke(strokeStyle, lineWidth: isSelected ? 1.5 : 0.5))
                .shadow(radius: 2, y: 1)
            Image(systemName: vehicleIcon(feature.vehicle) ?? "questionmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(width: 24, height: 24)
    }

    private var fullBody: some View {
        ZStack {
            Capsule()
                .fill(.regularMaterial)
                .overlay(Capsule().stroke(strokeStyle, lineWidth: isSelected ? 1.5 : 0.5))
                .shadow(radius: 2, y: 1)
            HStack(spacing: 6) {
                if let icon = vehicleIcon(feature.vehicle) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .overlay(alignment: .topTrailing) {
                            if let dot = validationDotColor {
                                Circle()
                                    .fill(dot)
                                    .frame(width: 7, height: 7)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                    .offset(x: 3, y: -3)
                            }
                        }
                }
                VStack(alignment: .leading, spacing: 0) {
                    if let name = feature.name {
                        Text(name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    if let duration = feature.duration {
                        Text(duration)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private var validationDotColor: Color? {
        switch validation {
        case .validated: return .green
        case .notFound, .failed: return .yellow
        case .none: return nil
        }
    }

    private var strokeStyle: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor)
        }
        if let day = feature.days.first {
            return AnyShapeStyle(color(forDay: day, anchors: document.dayAnchors).opacity(0.5))
        }
        return AnyShapeStyle(.separator)
    }

    private func validate() async {
        guard let dep = feature.departure,
              let day = feature.days.first,
              let baseDate = document.date(forDay: day),
              let start = feature.coordinates.first,
              let end = feature.coordinates.last else { return }
        let parts = dep.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = parts[0]
        components.minute = parts[1]
        guard let fullDate = Calendar.current.date(from: components),
              fullDate > Date() else { return }
        let result = await TransitValidator.shared.validate(
            from: start, to: end,
            departureDate: fullDate,
            vehicle: feature.vehicle)
        await MainActor.run { validation = result }
    }
}

private struct PlacePopover: View {
    let feature: KMLFeature
    let document: KMLDocument
    let canOpen: Bool
    let onOpen: () -> Void

    @State private var resolvedBookingURL: URL?
    @State private var imageRefreshTrigger = 0
    @State private var weatherByDay: [Int: WeatherSummary] = [:]

    private var bookableKinds: Set<String> {
        ["hotel", "ryokan", "accommodation",
         "restaurant", "food", "dining",
         "museum", "gallery", "architecture",
         "onsen", "hot_spring", "bath",
         "castle", "garden"]
    }

    private var showsBookingButton: Bool {
        guard let kind = feature.kind else { return false }
        return bookableKinds.contains(kind)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                HeroImage(explicitURL: feature.attributes["image_url"],
                          wikipediaQuery: feature.name,
                          kind: feature.kind,
                          vehicle: nil,
                          days: feature.days,
                          coordinate: feature.coordinates.first,
                          refreshTrigger: imageRefreshTrigger)
                    .frame(height: 160)
                    .clipped()
                ImageRefreshButton { imageRefreshTrigger += 1 }
                    .padding(8)
            }

            popoverBody
                .padding(16)
        }
        .frame(width: 320)
        .task { await resolveBooking() }
        .task { await resolveWeather() }
    }

    private var arrivalTime: String? {
        guard let coord = feature.coordinates.first, let firstDay = feature.days.first else { return nil }
        return document.times(at: coord, day: firstDay)?.arrival
    }

    private var departureTime: String? {
        guard let coord = feature.coordinates.first, let lastDay = feature.days.last else { return nil }
        return document.times(at: coord, day: lastDay)?.departure
    }

    private var stayDuration: String? {
        guard let firstDay = feature.days.first,
              let lastDay = feature.days.last,
              let arrivalDate = combinedDate(day: firstDay, time: arrivalTime),
              let departureDate = combinedDate(day: lastDay, time: departureTime)
        else { return nil }
        let totalMinutes = Int(departureDate.timeIntervalSince(arrivalDate) / 60)
        guard totalMinutes > 0 else { return nil }
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        if days > 0 && hours > 0 { return "\(days)d \(hours)h" }
        if days > 0 { return "\(days)d" }
        return "\(hours)h"
    }

    private func combinedDate(day: Int, time: String?) -> Date? {
        guard let time, let baseDate = document.date(forDay: day) else { return nil }
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = parts[0]
        components.minute = parts[1]
        return Calendar.current.date(from: components)
    }

    private var popoverBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: iconForKind(feature.kind))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 35, height: 35)
                    .background(Circle().fill(dayShape(feature.days, anchors: document.dayAnchors)))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.name ?? "Untitled")
                        .font(.title3.weight(.semibold))
                    if let kind = humanizedKind(feature.kind) {
                        Text(kind)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if let stayDuration {
                    DurationBadge(duration: stayDuration)
                }
                if feature.nights > 0 {
                    NightBadgeLarge(count: feature.nights)
                }
            }
            if !feature.days.isEmpty {
                DayTimeline(days: feature.days,
                            document: document,
                            startTime: arrivalTime,
                            endTime: departureTime,
                            weatherByDay: weatherByDay)
            }
            HStack(spacing: 8) {
                if canOpen, let name = feature.name {
                    Button(action: onOpen) {
                        Label("Open \(name)", systemImage: "arrow.down.right.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                } else {
                    Spacer(minLength: 0)
                }
                if showsBookingButton, let url = resolvedBookingURL {
                    ActionIconLink(url: url, systemImage: bookingIcon, helpText: bookingLabel)
                }
                if let coord = feature.coordinates.first,
                   let mapsURL = googleMapsURL(coord: coord, name: feature.name) {
                    ActionIconLink(url: mapsURL, systemImage: "map.fill", helpText: "Open in Google Maps")
                }
                if let youtubeURL = youtubeSearchURL(for: feature) {
                    ActionIconLink(url: youtubeURL, systemImage: "play.rectangle.fill", helpText: "Search on YouTube")
                }
            }
        }
    }

    private var bookingLabel: String {
        switch feature.kind?.lowercased() {
        case "restaurant", "food", "dining": return "Reserve a table"
        case "hotel", "ryokan", "accommodation": return "Book a stay"
        default: return "Book a ticket"
        }
    }

    private var bookingIcon: String {
        switch feature.kind?.lowercased() {
        case "restaurant", "food", "dining": return "fork.knife"
        default: return "ticket.fill"
        }
    }

    private func resolveBooking() async {
        guard showsBookingButton else { return }
        var country: String?
        if let coord = feature.coordinates.first {
            country = await CountryResolver.shared.country(for: coord)
        }
        let url = bookingURL(for: feature, country: country)
        await MainActor.run { resolvedBookingURL = url }
    }

    private func resolveWeather() async {
        guard document.showsWeather, let coord = feature.coordinates.first else { return }
        var results: [Int: WeatherSummary] = [:]
        for day in feature.days {
            guard let date = document.date(forDay: day) else { continue }
            if let summary = await WeatherResolver.shared.summary(for: coord, date: date) {
                results[day] = summary
            }
        }
        let collected = results
        await MainActor.run { weatherByDay = collected }
    }
}

private struct NightBadgeLarge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "moon.fill")
                .font(.caption.bold())
                .foregroundStyle(.indigo)
            Text("\(count)").font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.indigo.opacity(0.12), in: Capsule())
    }
}

private struct ImageRefreshButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help("Try a different image")
    }
}

private struct ActionIconLink: View {
    let url: URL
    let systemImage: String
    let helpText: String

    var body: some View {
        Link(destination: url) {
            Image(systemName: systemImage)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(helpText)
    }
}

private struct DurationBadge: View {
    let duration: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(duration)
                .font(.caption.bold())
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.15), in: Capsule())
    }
}

private struct TransitPopover: View {
    let feature: KMLFeature
    let document: KMLDocument

    @State private var resolvedBookingURL: URL?
    @State private var imageRefreshTrigger = 0
    @State private var validation: TransitValidator.Result?

    private var showsBookingButton: Bool {
        let v = feature.vehicle?.lowercased() ?? ""
        return v != "walk" && v != "foot" && v != "bicycle" && v != "bike"
    }

    private var validatedArrival: String? {
        if case .validated(let arr, _) = validation {
            return Self.timeFormatter.string(from: arr)
        }
        return nil
    }

    private var validatedDuration: String? {
        if case .validated(_, let dur) = validation {
            return Self.formatDuration(seconds: Int(dur))
        }
        return nil
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func formatDuration(seconds: Int) -> String {
        let mins = seconds / 60
        let h = mins / 60
        let m = mins % 60
        if h == 0 { return "\(m)min" }
        if m == 0 { return "\(h)h" }
        return String(format: "%dh%02d", h, m)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                HeroImage(explicitURL: feature.attributes["image_url"],
                          wikipediaQuery: feature.name,
                          kind: feature.kind,
                          vehicle: feature.vehicle,
                          days: feature.days,
                          coordinate: feature.coordinates.first,
                          refreshTrigger: imageRefreshTrigger)
                    .frame(height: 160)
                    .clipped()

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.name ?? "Transit")
                                .font(.title3.weight(.semibold))
                            ValidationLabel(result: validation)
                        }
                        Spacer(minLength: 0)
                        if let duration = validatedDuration ?? feature.duration {
                            DurationBadge(duration: duration)
                        }
                    }
                    if !feature.days.isEmpty {
                        DayTimeline(days: feature.days,
                                    document: document,
                                    startTime: feature.departure,
                                    endTime: validatedArrival ?? feature.arrival)
                    }
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        if showsBookingButton, let url = resolvedBookingURL {
                            ActionIconLink(url: url, systemImage: "ticket.fill", helpText: "Book ticket")
                        }
                        if let youtubeURL = youtubeSearchURL(for: feature) {
                            ActionIconLink(url: youtubeURL, systemImage: "play.rectangle.fill", helpText: "Search on YouTube")
                        }
                    }
                }
                .padding(16)
            }
            ImageRefreshButton { imageRefreshTrigger += 1 }
                .padding(8)
        }
        .frame(width: 320)
        .task { await resolveBooking() }
        .task { await validate() }
    }

    private func resolveBooking() async {
        guard showsBookingButton else { return }
        var country: String?
        if let coord = feature.coordinates.first {
            country = await CountryResolver.shared.country(for: coord)
        }
        let url = bookingURL(for: feature, country: country)
        await MainActor.run { resolvedBookingURL = url }
    }

    private func validate() async {
        guard let dep = feature.departure,
              let day = feature.days.first,
              let baseDate = document.date(forDay: day),
              let start = feature.coordinates.first,
              let end = feature.coordinates.last else { return }
        let parts = dep.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = parts[0]
        components.minute = parts[1]
        guard let fullDate = Calendar.current.date(from: components),
              fullDate > Date() else { return }
        let result = await TransitValidator.shared.validate(
            from: start, to: end,
            departureDate: fullDate,
            vehicle: feature.vehicle)
        await MainActor.run { validation = result }
    }
}

private struct ValidationLabel: View {
    let result: TransitValidator.Result?

    var body: some View {
        switch result {
        case .validated:
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("Verified")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .notFound, .failed:
            HStack(spacing: 4) {
                Circle().fill(Color.yellow).frame(width: 6, height: 6)
                Text("Unverified")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .none:
            EmptyView()
        }
    }
}

private actor WikipediaImageResolver {
    static let shared = WikipediaImageResolver()
    private var memo: [String: [URL]] = [:]

    func imageURL(for query: String, context: String? = nil, attempt: Int = 0) async -> URL? {
        let urls = await candidates(for: query, context: context)
        guard !urls.isEmpty else { return nil }
        return urls[attempt % urls.count]
    }

    func candidates(for query: String, context: String? = nil) async -> [URL] {
        await fetchCandidates(for: query, context: context)
    }

    func clear(query: String, context: String? = nil) {
        memo.removeValue(forKey: memoKey(query: query, context: context))
    }

    private func fetchCandidates(for query: String, context: String?) async -> [URL] {
        let key = memoKey(query: query, context: context)
        if let cached = memo[key] { return cached }
        var urls: [URL] = []
        if let url = await fetchSummary(title: query) {
            urls.append(url)
        }
        let searchQuery = context.map { "\(query) \($0)" } ?? query
        for resultKey in await searchTopMatches(query: searchQuery, limit: 10)
            where resultKey.lowercased() != query.lowercased() {
            if let url = await fetchSummary(title: resultKey), !urls.contains(url) {
                urls.append(url)
            }
        }
        memo[key] = urls
        return urls
    }

    private func memoKey(query: String, context: String?) -> String {
        if let context, !context.isEmpty { return "\(query)|\(context)" }
        return query
    }

    private func fetchSummary(title: String) async -> URL? {
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        guard let endpoint = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
            return nil
        }
        var request = URLRequest(url: endpoint)
        request.setValue("kokai/1.0 (local development)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            if let original = json["originalimage"] as? [String: Any],
               let source = original["source"] as? String,
               let url = URL(string: source) {
                return url
            }
            if let thumb = json["thumbnail"] as? [String: Any],
               let source = thumb["source"] as? String,
               let url = URL(string: source) {
                return url
            }
        } catch {
            return nil
        }
        return nil
    }

    private func searchTopMatches(query: String, limit: Int) async -> [String] {
        var components = URLComponents(string: "https://en.wikipedia.org/w/rest.php/v1/search/page")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let endpoint = components?.url else { return [] }
        var request = URLRequest(url: endpoint)
        request.setValue("kokai/1.0 (local development)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pages = json["pages"] as? [[String: Any]] else {
                return []
            }
            return pages.compactMap { page in
                page["key"] as? String ?? page["title"] as? String
            }
        } catch {
            return []
        }
    }
}

private actor TransitValidator {
    static let shared = TransitValidator()

    enum Result {
        case validated(arrival: Date, expectedDuration: TimeInterval)
        case notFound
        case failed
    }

    private var cache: [String: Result] = [:]

    func validate(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        departureDate: Date,
        vehicle: String?
    ) async -> Result {
        let key = "\(start.latitude),\(start.longitude)|\(end.latitude),\(end.longitude)|\(Int(departureDate.timeIntervalSince1970))"
        if let cached = cache[key] { return cached }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = transportType(for: vehicle)
        request.departureDate = departureDate

        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                cache[key] = .notFound
                return .notFound
            }
            let arrival = departureDate.addingTimeInterval(route.expectedTravelTime)
            let result = Result.validated(arrival: arrival, expectedDuration: route.expectedTravelTime)
            cache[key] = result
            return result
        } catch {
            cache[key] = .failed
            return .failed
        }
    }

    private func transportType(for vehicle: String?) -> MKDirectionsTransportType {
        switch vehicle?.lowercased() {
        case "car", "rental_car", "drive": return .automobile
        case "walk", "foot": return .walking
        case "bicycle", "bike": return .walking
        default: return .transit
        }
    }
}

private actor CountryResolver {
    static let shared = CountryResolver()
    private var cache: [String: String?] = [:]

    func country(for coord: CLLocationCoordinate2D) async -> String? {
        let key = String(format: "%.1f,%.1f", coord.latitude, coord.longitude)
        if let cached = cache[key] { return cached }
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            let country = placemarks.first?.country
            cache[key] = country
            return country
        } catch {
            cache[key] = nil
            return nil
        }
    }
}

struct WeatherSummary: Equatable {
    let highC: Double
    let lowC: Double
    let code: Int
    let isHistorical: Bool
}

private func weatherTooltip(for summary: WeatherSummary) -> String {
    let high = Int(summary.highC.rounded())
    let low = Int(summary.lowC.rounded())
    let prefix = summary.isHistorical ? "Typical (last year)" : "Forecast"
    return "\(prefix): \(high)° / \(low)°"
}

private func isBadWeather(code: Int) -> Bool {
    switch code {
    case 65, 67, 82, 71, 73, 75, 77, 85, 86, 95, 96, 99: return true
    default: return false
    }
}

private func weatherIcon(for code: Int) -> String {
    switch code {
    case 0, 1: return "sun.max.fill"
    case 2: return "cloud.sun.fill"
    case 3: return "cloud.fill"
    case 45, 48: return "cloud.fog.fill"
    case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
    case 61, 63, 65, 66, 67: return "cloud.rain.fill"
    case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
    case 80, 81, 82: return "cloud.heavyrain.fill"
    case 95, 96, 99: return "cloud.bolt.rain.fill"
    default: return "thermometer.medium"
    }
}

private actor WeatherResolver {
    static let shared = WeatherResolver()
    private var cache: [String: WeatherSummary] = [:]

    func summary(for coord: CLLocationCoordinate2D, date: Date) async -> WeatherSummary? {
        let cal = Calendar(identifier: .gregorian)
        let startOfDay = cal.startOfDay(for: date)
        let key = String(format: "%.2f,%.2f|%@", coord.latitude, coord.longitude,
                         Self.dateFormatter.string(from: startOfDay))
        if let hit = cache[key] { return hit }

        let today = cal.startOfDay(for: Date())
        let daysFromNow = cal.dateComponents([.day], from: today, to: startOfDay).day ?? 0

        let summary: WeatherSummary?
        if daysFromNow >= 0 && daysFromNow <= 15 {
            summary = await fetchForecast(coord: coord, date: startOfDay)
        } else {
            summary = await fetchHistorical(coord: coord, date: startOfDay)
        }
        if let summary { cache[key] = summary }
        return summary
    }

    private func fetchForecast(coord: CLLocationCoordinate2D, date: Date) async -> WeatherSummary? {
        let day = Self.dateFormatter.string(from: date)
        let url = "https://api.open-meteo.com/v1/forecast?latitude=\(coord.latitude)&longitude=\(coord.longitude)&daily=temperature_2m_max,temperature_2m_min,weathercode&start_date=\(day)&end_date=\(day)&timezone=auto"
        return await fetch(urlString: url, isHistorical: false)
    }

    private func fetchHistorical(coord: CLLocationCoordinate2D, date: Date) async -> WeatherSummary? {
        // Sample the same calendar date across the past 3 years and take the most common
        // weather code (mode), with averaged highs/lows. This dampens single-year anomalies.
        let cal = Calendar(identifier: .gregorian)
        let cutoff = cal.date(byAdding: .day, value: -5, to: cal.startOfDay(for: Date())) ?? Date()

        var samples: [(code: Int, high: Double, low: Double)] = []
        for yearsBack in 1...3 {
            guard let prior = cal.date(byAdding: .year, value: -yearsBack, to: date) else { continue }
            let target = prior < cutoff ? prior : cutoff
            let day = Self.dateFormatter.string(from: target)
            let url = "https://archive-api.open-meteo.com/v1/archive?latitude=\(coord.latitude)&longitude=\(coord.longitude)&daily=temperature_2m_max,temperature_2m_min,weathercode&start_date=\(day)&end_date=\(day)&timezone=auto"
            if let s = await fetchRaw(urlString: url) {
                samples.append(s)
            }
        }

        guard !samples.isEmpty else { return nil }

        // Mode of weather codes; tiebreak by lower (sunnier) code.
        var counts: [Int: Int] = [:]
        for s in samples { counts[s.code, default: 0] += 1 }
        let maxCount = counts.values.max() ?? 0
        let topCodes = counts.filter { $0.value == maxCount }.map(\.key).sorted()
        let mode = topCodes.first ?? samples[0].code
        let avgHigh = samples.map(\.high).reduce(0, +) / Double(samples.count)
        let avgLow = samples.map(\.low).reduce(0, +) / Double(samples.count)
        return WeatherSummary(highC: avgHigh, lowC: avgLow, code: mode, isHistorical: true)
    }

    private func fetchRaw(urlString: String) async -> (code: Int, high: Double, low: Double)? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let daily = json["daily"] as? [String: Any],
                  let highs = daily["temperature_2m_max"] as? [Double],
                  let lows = daily["temperature_2m_min"] as? [Double],
                  let codes = daily["weathercode"] as? [Int],
                  let high = highs.first, let low = lows.first, let code = codes.first
            else { return nil }
            return (code, high, low)
        } catch {
            return nil
        }
    }

    private func fetch(urlString: String, isHistorical: Bool) async -> WeatherSummary? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let daily = json["daily"] as? [String: Any],
                  let highs = daily["temperature_2m_max"] as? [Double],
                  let lows = daily["temperature_2m_min"] as? [Double],
                  let codes = daily["weathercode"] as? [Int],
                  let high = highs.first, let low = lows.first, let code = codes.first
            else { return nil }
            return WeatherSummary(highC: high, lowC: low, code: code, isHistorical: isHistorical)
        } catch {
            return nil
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}

private struct WeatherBadge: View {
    let summary: WeatherSummary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: weatherIcon(for: summary.code))
                .font(.caption.bold())
                .foregroundStyle(summary.isHistorical ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
            Text("\(Int(summary.highC.rounded()))° / \(Int(summary.lowC.rounded()))°")
                .font(.caption.bold())
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(AnyShapeStyle(.separator), lineWidth: 0.5))
        .help(summary.isHistorical ? "Typical for the date (last year)" : "Forecast")
    }
}

private enum ImageChoiceStore {
    static func chosenURL(for key: String) -> URL? {
        guard let s = UserDefaults.standard.string(forKey: defaultsKey(key)) else { return nil }
        return URL(string: s)
    }

    static func setChosenURL(_ url: URL?, for key: String) {
        let k = defaultsKey(key)
        if let url {
            UserDefaults.standard.set(url.absoluteString, forKey: k)
        } else {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }

    private static func defaultsKey(_ key: String) -> String {
        "kokai.image.choice.\(key)"
    }
}

private actor DiskImageCache {
    static let shared = DiskImageCache()
    private let directory: URL

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        directory = caches.appendingPathComponent("kokai/images", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func data(for key: String) -> Data? {
        try? Data(contentsOf: path(for: key))
    }

    func write(_ data: Data, for key: String) {
        try? data.write(to: path(for: key), options: .atomic)
    }

    func clear(key: String) {
        try? FileManager.default.removeItem(at: path(for: key))
    }

    private func path(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(hex).img")
    }
}

private struct HeroImage: View {
    let explicitURL: String?
    let wikipediaQuery: String?
    let kind: String?
    let vehicle: String?
    let days: [Int]
    let coordinate: CLLocationCoordinate2D?

    @State private var image: NSImage?
    @State private var resolved = false

    private var cacheKey: String {
        if let explicitURL, !explicitURL.isEmpty { return "url:\(explicitURL)" }
        if let q = wikipediaQuery, !q.isEmpty { return "q:\(q)" }
        if let v = vehicle, !v.isEmpty { return "v:\(v)" }
        return "default"
    }

    var refreshTrigger: Int = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                fallback
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else if !resolved {
                    ProgressView()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: cacheKey) { await load() }
        .onChange(of: refreshTrigger) { _, _ in refresh() }
    }

    private func refresh() {
        let key = cacheKey
        let q = wikipediaQuery
        let v = vehicle
        let coord = coordinate
        Task {
            let context = await searchContext(coord: coord, vehicle: v)
            let urls = await allCandidates(query: q, vehicle: v, context: context)
            guard !urls.isEmpty else { return }
            let current = ImageChoiceStore.chosenURL(for: key)
            let currentIndex = current.flatMap { urls.firstIndex(of: $0) } ?? -1
            let next = urls[(currentIndex + 1) % urls.count]
            ImageChoiceStore.setChosenURL(next, for: key)
            await DiskImageCache.shared.clear(key: key)
            await MainActor.run {
                image = nil
                resolved = false
            }
            await download(url: next, key: key)
        }
    }

    private func load() async {
        let key = cacheKey
        if let data = await DiskImageCache.shared.data(for: key),
           let cached = NSImage(data: data) {
            await MainActor.run {
                image = cached
                resolved = true
            }
            return
        }
        if let url = ImageChoiceStore.chosenURL(for: key) {
            await download(url: url, key: key)
            return
        }
        guard let url = await firstURL() else {
            await MainActor.run { resolved = true }
            return
        }
        ImageChoiceStore.setChosenURL(url, for: key)
        await download(url: url, key: key)
    }

    private func download(url: URL, key: String) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await DiskImageCache.shared.write(data, for: key)
            if let img = NSImage(data: data) {
                await MainActor.run {
                    image = img
                    resolved = true
                }
                return
            }
        } catch {
            // network failure
        }
        await MainActor.run { resolved = true }
    }

    private func firstURL() async -> URL? {
        if let explicitURL, !explicitURL.isEmpty, let url = URL(string: explicitURL) {
            return url
        }
        let context = await searchContext(coord: coordinate, vehicle: vehicle)
        if kindUsesImageSearch(kind),
           let q = wikipediaQuery, !q.isEmpty,
           let url = await WikipediaImageResolver.shared.imageURL(for: q, context: context) {
            return url
        }
        if let vQuery = vehicleWikipediaQuery(vehicle),
           let url = await WikipediaImageResolver.shared.imageURL(for: vQuery) {
            return url
        }
        return nil
    }

    private func allCandidates(query: String?, vehicle: String?, context: String?) async -> [URL] {
        if let explicitURL, !explicitURL.isEmpty, let url = URL(string: explicitURL) {
            return [url]
        }
        var urls: [URL] = []
        if kindUsesImageSearch(kind), let q = query, !q.isEmpty {
            urls.append(contentsOf: await WikipediaImageResolver.shared.candidates(for: q, context: context))
        }
        if let vQuery = vehicleWikipediaQuery(vehicle) {
            for url in await WikipediaImageResolver.shared.candidates(for: vQuery) {
                if !urls.contains(url) { urls.append(url) }
            }
        }
        return urls
    }

    private func searchContext(coord: CLLocationCoordinate2D?, vehicle: String?) async -> String? {
        var parts: [String] = []
        if let v = vehicleWikipediaQuery(vehicle)?.lowercased() {
            parts.append(v)
        }
        if let k = humanizedKind(kind)?.lowercased(), !k.isEmpty {
            parts.append(k)
        }
        if let coord, let country = await CountryResolver.shared.country(for: coord) {
            parts.append(country)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private var fallback: some View {
        ZStack {
            Rectangle().fill(dayShapeHorizontalFallback(days.isEmpty ? [1] : days))
            if let icon = vehicleIcon(vehicle) {
                Image(systemName: icon)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}
