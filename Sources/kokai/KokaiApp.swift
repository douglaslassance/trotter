import AppKit
import CoreLocation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class LocationAuthorizer: NSObject, CLLocationManagerDelegate {
    static let shared = LocationAuthorizer()
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func request() {
        manager.requestWhenInUseAuthorization()
    }
}

@main
struct KokaiApp: App {
    @State private var nav = NavigationModel()
    @State private var showingOpenPanel = false
    @State private var loadError: String?
    @State private var didAutoReopen = false

    var body: some Scene {
        WindowGroup {
            ContentView(nav: nav)
                .frame(minWidth: 600, minHeight: 400)
                .onAppear {
                    LocationAuthorizer.shared.request()
                    guard !didAutoReopen else { return }
                    didAutoReopen = true
                    if nav.current == nil {
                        _ = try? nav.reopenLast()
                    }
                }
                .onOpenURL { url in
                    do { try nav.open(url) }
                    catch { loadError = error.localizedDescription }
                }
                .fileImporter(isPresented: $showingOpenPanel,
                              allowedContentTypes: [.kml]) { result in
                    if case .success(let url) = result {
                        do { try nav.open(url) }
                        catch { loadError = error.localizedDescription }
                    }
                }
                .alert("Failed to open file",
                       isPresented: Binding(get: { loadError != nil },
                                            set: { if !$0 { loadError = nil } })) {
                    Button("OK") { loadError = nil }
                } message: {
                    Text(loadError ?? "")
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    nav.reloadIfChanged()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { showingOpenPanel = true }
                    .keyboardShortcut("o", modifiers: .command)

                Menu("Open Recent") {
                    if nav.recentURLs.isEmpty {
                        Text("No Recent Files")
                    } else {
                        ForEach(nav.recentURLs, id: \.self) { url in
                            Button(url.lastPathComponent) {
                                do { try nav.open(url) }
                                catch { loadError = error.localizedDescription }
                            }
                        }
                        Divider()
                        Button("Clear Menu") { nav.clearRecents() }
                    }
                }
            }
        }
    }
}
