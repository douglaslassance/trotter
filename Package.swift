// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "kokai",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "kokai",
            path: "Sources/kokai"
        )
    ]
)
