// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "trotter",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "trotter",
            path: "Sources/trotter"
        )
    ]
)
