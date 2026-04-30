import AppKit
import CoreLocation
import CryptoKit
import MapKit
import SwiftUI

private func vehicleIcon(_ vehicle: String?) -> String? {
    guard let v = vehicle?.lowercased(), !v.isEmpty else { return nil }
    switch v {
    case "shinkansen", "bullet": return "🚅"
    case "train", "limited_express", "rail": return "🚆"
    case "tram", "streetcar": return "🚊"
    case "metro", "subway": return "🚇"
    case "bus": return "🚌"
    case "car", "rental_car", "drive": return "🚗"
    case "ferry", "boat", "ship": return "⛴️"
    case "bicycle", "bike": return "🚲"
    case "walk", "foot": return "🚶"
    case "plane", "flight": return "✈️"
    default: return "📍"
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
]

private func color(forDay day: Int) -> Color {
    guard day >= 1, day <= dayPalette.count else { return .gray }
    return dayPalette[day - 1]
}

private func dayShape(_ days: [Int]) -> AnyShapeStyle {
    if days.isEmpty {
        return AnyShapeStyle(Color.red)
    }
    if days.count == 1 {
        return AnyShapeStyle(color(forDay: days[0]))
    }
    return AnyShapeStyle(LinearGradient(
        colors: days.map { color(forDay: $0) },
        startPoint: .top,
        endPoint: .bottom
    ))
}

private func dayShapeHorizontal(_ days: [Int]) -> AnyShapeStyle {
    if days.isEmpty {
        return AnyShapeStyle(Color.red)
    }
    if days.count == 1 {
        return AnyShapeStyle(color(forDay: days[0]))
    }
    return AnyShapeStyle(LinearGradient(
        colors: days.map { color(forDay: $0) },
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

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let level = nav.current {
                MapLevelView(level: level, nav: nav, selection: $selectionID)
                    .id(level.id)
            } else {
                EmptyState()
            }
            BreadcrumbBar(nav: nav)
                .padding(12)
        }
        .onChange(of: nav.current?.id) {
            selectionID = nil
        }
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
                Button { nav.goBack() } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!nav.canGoBack)
                .buttonStyle(.borderless)

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

private struct MapLevelView: View {
    let level: NavigationModel.Level
    @Bindable var nav: NavigationModel
    @Binding var selection: UUID?
    @State private var position: MapCameraPosition
    @State private var latitudeSpan: Double = 0

    init(level: NavigationModel.Level, nav: NavigationModel, selection: Binding<UUID?>) {
        self.level = level
        self.nav = nav
        self._selection = selection
        let initialRect = Self.boundingRect(for: level.document.features)
        _position = State(initialValue: initialRect.map { .rect($0) } ?? .automatic)
    }

    var body: some View {
        Map(position: $position, selection: $selection) {
            ForEach(level.document.features) { feature in
                content(for: feature)
            }
        }
        .mapStyle(.standard(elevation: .automatic,
                            emphasis: .muted,
                            pointsOfInterest: .excludingAll))
        .onMapCameraChange(frequency: .continuous) { ctx in
            latitudeSpan = ctx.region.span.latitudeDelta
        }
    }

    private func displaysAsConnection(_ feature: KMLFeature) -> Bool {
        feature.isConnection || !childExists(for: feature)
    }

    @MapContentBuilder
    private func content(for feature: KMLFeature) -> some MapContent {
        switch feature {
        case .point(let point):
            let asConnection = displaysAsConnection(feature)
            Annotation("", coordinate: point.coordinate, anchor: .center) {
                ZStack {
                    if asConnection {
                        ConnectionMarker(isSelected: selection == feature.id,
                                         days: feature.days)
                    } else {
                        PlaceMarker(isSelected: selection == feature.id,
                                    days: feature.days,
                                    nights: feature.nights)
                    }
                    if let name = point.name, !name.isEmpty {
                        PlaceLabel(text: name, isConnection: asConnection)
                            .fixedSize()
                            .offset(y: asConnection ? 18 : 24)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: asConnection ? 14 : 22,
                       height: asConnection ? 14 : 22)
                .popover(isPresented: popoverBinding(for: feature.id),
                         arrowEdge: .leading) {
                    PlacePopover(
                        feature: feature,
                        document: level.document,
                        canOpen: childExists(for: feature),
                        onOpen: { drill(into: feature) }
                    )
                }
            }
            .tag(feature.id)

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
            .stroke(dayShapeHorizontal(feature.days), lineWidth: 3)
        if let mid = curvedApex(of: line.coordinates) {
            Annotation("", coordinate: mid, anchor: .center) {
                TransitBadge(feature: feature,
                             isSelected: selection == feature.id,
                             detail: badgeDetail(forSpan: latitudeSpan))
                    .popover(isPresented: popoverBinding(for: feature.id),
                             arrowEdge: .leading) {
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
    let isSelected: Bool
    let days: [Int]
    let nights: Int
    @State private var isHovering = false

    private var scale: CGFloat {
        if isSelected { return 1.15 }
        if isHovering { return 1.12 }
        return 1.0
    }

    var body: some View {
        Circle()
            .fill(dayShape(days))
            .frame(width: 22, height: 22)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
            .overlay(alignment: .topTrailing) {
                if nights > 0 {
                    NightBadge(count: nights)
                        .offset(x: 4, y: -4)
                }
            }
            .shadow(radius: isHovering || isSelected ? 5 : 3, y: 1)
            .scaleEffect(scale)
            .onHover { isHovering = $0 }
            .animation(.spring(response: 0.32, dampingFraction: 0.6), value: isHovering)
            .animation(.spring(response: 0.32, dampingFraction: 0.6), value: isSelected)
    }
}

private struct ConnectionMarker: View {
    let isSelected: Bool
    let days: [Int]
    @State private var isHovering = false

    private var scale: CGFloat {
        if isSelected { return 1.4 }
        if isHovering { return 1.3 }
        return 1.0
    }

    private var ringColor: Color {
        if let day = days.first { return color(forDay: day) }
        return .red
    }

    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: 14, height: 14)
            .overlay(Circle().strokeBorder(ringColor, lineWidth: 3))
            .shadow(radius: isHovering || isSelected ? 4 : 2, y: 1)
            .scaleEffect(scale)
            .onHover { isHovering = $0 }
            .animation(.spring(response: 0.32, dampingFraction: 0.6), value: isHovering)
            .animation(.spring(response: 0.32, dampingFraction: 0.6), value: isSelected)
    }
}

private struct NightBadge: View {
    let count: Int

    var body: some View {
        ZStack {
            Image(systemName: "moon.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.indigo)
                .frame(width: 16, height: 16)
                .background(.white, in: Circle())
                .overlay(Circle().strokeBorder(.indigo.opacity(0.4), lineWidth: 0.5))
            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundStyle(.indigo)
                    .offset(x: 0, y: 1)
            }
        }
    }
}

private struct PlaceLabel: View {
    let text: String
    let isConnection: Bool

    var body: some View {
        Text(text)
            .font(.caption.weight(isConnection ? .regular : .semibold))
            .foregroundStyle(isConnection ? .secondary : .primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(AnyShapeStyle(.separator), lineWidth: 0.5))
    }
}

private struct DayChip: View {
    let day: Int
    let date: Date?
    var arrivalTime: String? = nil
    var departureTime: String? = nil

    private var timeText: String? {
        switch (arrivalTime, departureTime) {
        case let (arr?, dep?): return "\(arr) → \(dep)"
        case let (arr?, nil): return "↓ \(arr)"
        case let (nil, dep?): return "↑ \(dep)"
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color(forDay: day))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text(date.map(formatDate) ?? "Day \(day)")
                    .font(.caption.bold())
                    .monospacedDigit()
                if let timeText {
                    Text(timeText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color(forDay: day).opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(color(forDay: day).opacity(0.5), lineWidth: 0.5))
    }
}

private struct DayChipRow: View {
    let days: [Int]
    let document: KMLDocument
    var coordinate: CLLocationCoordinate2D? = nil

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                let times = coordinate.flatMap { document.times(at: $0, day: day) }
                DayChip(
                    day: day,
                    date: document.date(forDay: day),
                    arrivalTime: times?.arrival,
                    departureTime: times?.departure
                )
            }
        }
    }
}

private struct TransitBadge: View {
    let feature: KMLFeature
    let isSelected: Bool
    let detail: BadgeDetail

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
        .animation(.snappy, value: detail)
        .animation(.snappy, value: isSelected)
    }

    private var iconOnlyBody: some View {
        Text(vehicleIcon(feature.vehicle) ?? "•")
            .font(.title3)
            .padding(6)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().stroke(strokeStyle, lineWidth: isSelected ? 1.5 : 0.5))
            .shadow(radius: 2, y: 1)
            .scaleEffect(isSelected ? 1.1 : 1.0)
    }

    private var fullBody: some View {
        HStack(spacing: 6) {
            if let icon = vehicleIcon(feature.vehicle) {
                Text(icon).font(.title3)
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
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(strokeStyle, lineWidth: isSelected ? 1.5 : 0.5)
        )
        .shadow(radius: 2, y: 1)
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }

    private var strokeStyle: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor)
        }
        if let day = feature.days.first {
            return AnyShapeStyle(color(forDay: day).opacity(0.5))
        }
        return AnyShapeStyle(.separator)
    }
}

private struct PlacePopover: View {
    let feature: KMLFeature
    let document: KMLDocument
    let canOpen: Bool
    let onOpen: () -> Void

    private var displaysAsConnection: Bool { feature.isConnection || !canOpen }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeroImage(explicitURL: feature.attributes["image_url"],
                      wikipediaQuery: feature.name,
                      vehicle: nil,
                      days: feature.days,
                      coordinate: feature.coordinates.first)
                .frame(height: 160)
                .clipped()

            popoverBody
                .padding(16)
        }
        .frame(width: 320)
    }

    private var popoverBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                if displaysAsConnection {
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(
                            feature.days.first.map(color(forDay:)) ?? .red,
                            lineWidth: 3))
                } else {
                    Circle()
                        .fill(dayShape(feature.days))
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.name ?? "Untitled")
                        .font(.title3.weight(.semibold))
                    if displaysAsConnection {
                        Text("Connection")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if feature.nights > 0 {
                    NightBadgeLarge(count: feature.nights)
                }
            }
            if !feature.days.isEmpty {
                DayChipRow(days: feature.days,
                           document: document,
                           coordinate: feature.coordinates.first)
            }
            if canOpen, let name = feature.name {
                Button(action: onOpen) {
                    Label("Open \(name)", systemImage: "arrow.down.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.regular)
            }
        }
    }
}

private struct NightBadgeLarge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "moon.fill")
                .font(.caption.bold())
                .foregroundStyle(.indigo)
            if count > 1 {
                Text("× \(count)").font(.caption.bold())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.indigo.opacity(0.12), in: Capsule())
    }
}

private struct TransitPopover: View {
    let feature: KMLFeature
    let document: KMLDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeroImage(explicitURL: feature.attributes["image_url"],
                      wikipediaQuery: feature.name,
                      vehicle: feature.vehicle,
                      days: feature.days,
                      coordinate: feature.coordinates.first)
                .frame(height: 160)
                .clipped()

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.name ?? "Transit")
                        .font(.title3.weight(.semibold))
                    if let dep = feature.departure, let arr = feature.arrival {
                        HStack(spacing: 6) {
                            Text("\(dep) → \(arr)")
                                .font(.callout)
                                .monospacedDigit()
                            if let duration = feature.duration {
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text(duration)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .font(.callout)
                    } else if let duration = feature.duration {
                        Text(duration)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                if !feature.days.isEmpty {
                    DayChipRow(days: feature.days, document: document)
                }
                if let bookingURL = feature.attributes["booking_url"],
                   let url = URL(string: bookingURL) {
                    Link(destination: url) {
                        Label("Book ticket", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding(16)
        }
        .frame(width: 320)
    }
}

private actor WikipediaImageResolver {
    static let shared = WikipediaImageResolver()
    private var memo: [String: [URL]] = [:]

    func imageURL(for query: String, context: String? = nil, attempt: Int = 0) async -> URL? {
        let candidates = await candidates(for: query, context: context)
        guard !candidates.isEmpty else { return nil }
        return candidates[attempt % candidates.count]
    }

    func clear(query: String, context: String? = nil) {
        memo.removeValue(forKey: memoKey(query: query, context: context))
    }

    private func candidates(for query: String, context: String?) async -> [URL] {
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
    let vehicle: String?
    let days: [Int]
    let coordinate: CLLocationCoordinate2D?

    @State private var image: NSImage?
    @State private var resolved = false
    @State private var attempt = 0

    private var baseKey: String {
        if let explicitURL, !explicitURL.isEmpty { return "url:\(explicitURL)" }
        if let q = wikipediaQuery, !q.isEmpty { return "q:\(q)" }
        if let v = vehicle, !v.isEmpty { return "v:\(v)" }
        return "default"
    }

    private var cacheKey: String { "\(baseKey)#\(attempt)" }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                fallback
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                if !resolved && image == nil {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.92), in: Circle())
                    .overlay(Circle().stroke(Color.black.opacity(0.18), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .help("Try a different image")
            .padding(8)
        }
        .task(id: cacheKey) {
            await load()
        }
    }

    private func refresh() {
        image = nil
        resolved = false
        attempt += 1
        Task {
            await DiskImageCache.shared.clear(key: cacheKey)
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
        guard let url = await resolveURL() else {
            await MainActor.run { resolved = true }
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await DiskImageCache.shared.write(data, for: key)
            if let downloaded = NSImage(data: data) {
                await MainActor.run {
                    image = downloaded
                    resolved = true
                }
                return
            }
        } catch {
            // network failure — fall through to fallback
        }
        await MainActor.run { resolved = true }
    }

    private func resolveURL() async -> URL? {
        if let explicitURL, !explicitURL.isEmpty, let url = URL(string: explicitURL) {
            return url
        }
        var contextParts: [String] = []
        if let v = vehicleWikipediaQuery(vehicle)?.lowercased() {
            contextParts.append(v)
        }
        if let coord = coordinate,
           let country = await CountryResolver.shared.country(for: coord) {
            contextParts.append(country)
        }
        let context = contextParts.isEmpty ? nil : contextParts.joined(separator: " ")

        if let q = wikipediaQuery, !q.isEmpty,
           let url = await WikipediaImageResolver.shared.imageURL(
               for: q, context: context, attempt: attempt) {
            return url
        }
        if let vQuery = vehicleWikipediaQuery(vehicle),
           let url = await WikipediaImageResolver.shared.imageURL(
               for: vQuery, attempt: attempt) {
            return url
        }
        return nil
    }

    private var fallback: some View {
        ZStack {
            Rectangle().fill(dayShapeHorizontal(days.isEmpty ? [1] : days))
            if let icon = vehicleIcon(vehicle) {
                Text(icon)
                    .font(.system(size: 80))
                    .shadow(radius: 4)
            }
        }
    }
}
