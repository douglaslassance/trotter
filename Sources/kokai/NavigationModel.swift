import Foundation
import Observation

@Observable
final class NavigationModel {
    struct Level: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let document: KMLDocument

        var title: String {
            document.name ?? url.deletingPathExtension().lastPathComponent
        }

        static func == (lhs: Level, rhs: Level) -> Bool { lhs.id == rhs.id }
    }

    private static let recentsKey = "kokai.recentURLs"
    private static let recentsLimit = 10

    private(set) var stack: [Level] = []
    private(set) var recentURLs: [URL] = []
    private var lastModified: [URL: Date] = [:]

    var current: Level? { stack.last }
    var canGoBack: Bool { stack.count > 1 }

    init() {
        recentURLs = Self.loadRecents()
    }

    func open(_ url: URL) throws {
        let level = try makeLevel(at: url)
        stack = [level]
        recordModified(url)
        recordRecent(url)
    }

    func reloadIfChanged() {
        var newStack: [Level] = []
        var didReload = false
        for level in stack {
            if let current = fileModificationDate(at: level.url),
               let known = lastModified[level.url],
               current > known {
                if let reloaded = try? makeLevel(at: level.url) {
                    newStack.append(reloaded)
                    lastModified[level.url] = current
                    didReload = true
                    continue
                }
            }
            newStack.append(level)
        }
        if didReload {
            stack = newStack
        }
    }

    private func fileModificationDate(at url: URL) -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attrs?[.modificationDate] as? Date
    }

    private func recordModified(_ url: URL) {
        lastModified[url] = fileModificationDate(at: url) ?? Date()
    }

    func reopenLast() throws -> Bool {
        guard let url = recentURLs.first else { return false }
        guard FileManager.default.fileExists(atPath: url.path) else {
            recentURLs.removeFirst()
            saveRecents()
            return false
        }
        try open(url)
        return true
    }

    func clearRecents() {
        recentURLs.removeAll()
        saveRecents()
    }

    private func recordRecent(_ url: URL) {
        let standardized = url.standardizedFileURL
        recentURLs.removeAll { $0.standardizedFileURL == standardized }
        recentURLs.insert(standardized, at: 0)
        if recentURLs.count > Self.recentsLimit {
            recentURLs = Array(recentURLs.prefix(Self.recentsLimit))
        }
        saveRecents()
    }

    private func saveRecents() {
        let paths = recentURLs.map { $0.path }
        UserDefaults.standard.set(paths, forKey: Self.recentsKey)
    }

    private static func loadRecents() -> [URL] {
        guard let paths = UserDefaults.standard.array(forKey: recentsKey) as? [String] else {
            return []
        }
        return paths.map { URL(fileURLWithPath: $0) }
    }

    func drillDown(matching name: String) throws -> Bool {
        guard let parent = current else { return false }
        guard let childURL = resolveSibling(named: name, near: parent.url) else {
            return false
        }
        let level = try makeLevel(at: childURL)
        stack.append(level)
        recordModified(childURL)
        return true
    }

    func goBack() {
        guard canGoBack else { return }
        stack.removeLast()
    }

    func go(to level: Level) {
        guard let index = stack.firstIndex(of: level) else { return }
        stack = Array(stack.prefix(index + 1))
    }

    private func makeLevel(at url: URL) throws -> Level {
        let data = try Data(contentsOf: url)
        let document = try KMLParser.parse(data: data)
        return Level(url: url, document: document)
    }

    func canDrillDown(into name: String) -> Bool {
        guard let parent = current else { return false }
        return resolveSibling(named: name, near: parent.url) != nil
    }

    private func resolveSibling(named name: String, near url: URL) -> URL? {
        let folder = url.deletingPathExtension().deletingLastPathComponent()
        let parentFolder = url.deletingLastPathComponent()
        let candidates = [
            parentFolder.appendingPathComponent("\(name).kml"),
            folder.appendingPathComponent("\(name).kml"),
        ]
        let fm = FileManager.default
        if let hit = candidates.first(where: { fm.fileExists(atPath: $0.path) }) {
            return hit
        }
        // case-insensitive scan in parent folder
        guard let entries = try? fm.contentsOfDirectory(at: parentFolder,
                                                       includingPropertiesForKeys: nil) else {
            return nil
        }
        let target = "\(name).kml".lowercased()
        return entries.first { $0.lastPathComponent.lowercased() == target }
    }
}
