import CoreLocation
import Foundation

enum KMLParseError: Error {
    case invalidXML
}

final class KMLParser: NSObject, XMLParserDelegate {
    static func parse(data: Data) throws -> KMLDocument {
        let parser = KMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        guard xmlParser.parse() else {
            throw xmlParser.parserError ?? KMLParseError.invalidXML
        }
        return KMLDocument(name: parser.documentName,
                           details: parser.documentDetails,
                           attributes: parser.documentAttributes,
                           features: parser.features,
                           networkLinks: parser.networkLinks)
    }

    private enum GeometryKind { case point, lineString, polygon }

    private var features: [KMLFeature] = []
    private var currentText = ""

    private var documentName: String?
    private var documentDetails: String?
    private var documentAttributes: [String: String] = [:]

    private var networkLinks: [String: String] = [:]
    private var inNetworkLink = false
    private var networkLinkName: String?
    private var networkLinkHref: String?

    private var inPlacemark = false
    private var currentName: String?
    private var currentDetails: String?
    private var currentAttributes: [String: String] = [:]
    private var currentDataKey: String?
    private var currentGeometry: GeometryKind?
    private var currentCoordinates: [CLLocationCoordinate2D] = []
    private var polygonOuter: [CLLocationCoordinate2D] = []
    private var polygonInner: [[CLLocationCoordinate2D]] = []
    private var inOuterBoundary = false
    private var inInnerBoundary = false
    private var currentWhen: String?
    private var currentBegin: String?
    private var currentEnd: String?

    private static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentText = ""
        switch elementName {
        case "NetworkLink":
            inNetworkLink = true
            networkLinkName = nil
            networkLinkHref = nil
        case "Placemark":
            inPlacemark = true
            currentName = nil
            currentDetails = nil
            currentAttributes = [:]
            currentGeometry = nil
            currentCoordinates = []
            polygonOuter = []
            polygonInner = []
            currentWhen = nil
            currentBegin = nil
            currentEnd = nil
        case "Point": currentGeometry = .point
        case "LineString": currentGeometry = .lineString
        case "Polygon": currentGeometry = .polygon
        case "outerBoundaryIs": inOuterBoundary = true
        case "innerBoundaryIs": inInnerBoundary = true
        case "Data":
            currentDataKey = attributeDict["name"]
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let text = String(data: CDATABlock, encoding: .utf8) {
            currentText += text
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "name":
            if inNetworkLink, networkLinkName == nil { networkLinkName = trimmed }
            else if inPlacemark, currentName == nil { currentName = trimmed }
            else if !inPlacemark, documentName == nil { documentName = trimmed }
        case "description":
            if inPlacemark, currentDetails == nil { currentDetails = trimmed }
            else if !inPlacemark, documentDetails == nil { documentDetails = trimmed }
        case "href":
            if inNetworkLink, !trimmed.isEmpty { networkLinkHref = trimmed }
        case "NetworkLink":
            if let n = networkLinkName, let h = networkLinkHref {
                networkLinks[n] = h
            }
            inNetworkLink = false
            networkLinkName = nil
            networkLinkHref = nil
        case "coordinates":
            let coords = parseCoordinates(trimmed)
            if currentGeometry == .polygon {
                if inOuterBoundary { polygonOuter = coords }
                else if inInnerBoundary { polygonInner.append(coords) }
            } else {
                currentCoordinates = coords
            }
        case "outerBoundaryIs": inOuterBoundary = false
        case "innerBoundaryIs": inInnerBoundary = false
        case "value":
            if let key = currentDataKey, !trimmed.isEmpty {
                if inPlacemark {
                    currentAttributes[key] = trimmed
                } else {
                    documentAttributes[key] = trimmed
                }
            }
        case "Data":
            currentDataKey = nil
        case "when":
            if inPlacemark, !trimmed.isEmpty { currentWhen = trimmed }
        case "begin":
            if inPlacemark, !trimmed.isEmpty { currentBegin = trimmed }
        case "end":
            if inPlacemark, !trimmed.isEmpty { currentEnd = trimmed }
        case "Placemark":
            deriveDaysFromTime()
            if let geometry = currentGeometry {
                switch geometry {
                case .point:
                    if let c = currentCoordinates.first {
                        features.append(.point(.init(name: currentName,
                                                     details: currentDetails,
                                                     attributes: currentAttributes,
                                                     coordinate: c)))
                    }
                case .lineString:
                    features.append(.lineString(.init(name: currentName,
                                                      details: currentDetails,
                                                      attributes: currentAttributes,
                                                      coordinates: currentCoordinates)))
                case .polygon:
                    features.append(.polygon(.init(name: currentName,
                                                   details: currentDetails,
                                                   attributes: currentAttributes,
                                                   outerBoundary: polygonOuter,
                                                   innerBoundaries: polygonInner)))
                }
            }
            inPlacemark = false
        default: break
        }
        currentText = ""
    }

    private func deriveDaysFromTime() {
        guard currentAttributes["days"] == nil else { return }
        guard let startStr = documentAttributes["start_date"],
              let start = Self.isoDate.date(from: startStr) else { return }
        let cal = Calendar(identifier: .gregorian)
        if let beginStr = currentBegin, let endStr = currentEnd,
           let begin = Self.isoDate.date(from: beginStr),
           let end = Self.isoDate.date(from: endStr),
           let beginDay = cal.dateComponents([.day], from: start, to: begin).day,
           let endDay = cal.dateComponents([.day], from: start, to: end).day {
            let days = (beginDay + 1)...(endDay + 1)
            currentAttributes["days"] = days.map(String.init).joined(separator: ",")
            if currentAttributes["nights"] == nil {
                currentAttributes["nights"] = String(endDay - beginDay)
            }
        } else if let whenStr = currentWhen,
                  let when = Self.isoDate.date(from: whenStr),
                  let day = cal.dateComponents([.day], from: start, to: when).day {
            currentAttributes["days"] = String(day + 1)
            if currentAttributes["nights"] == nil {
                currentAttributes["nights"] = "0"
            }
        }
    }

    private func parseCoordinates(_ text: String) -> [CLLocationCoordinate2D] {
        text
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap { tuple in
                let parts = tuple.split(separator: ",")
                guard parts.count >= 2,
                      let lon = Double(parts[0]),
                      let lat = Double(parts[1]) else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
    }
}
