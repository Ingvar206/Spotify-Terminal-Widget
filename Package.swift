// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SpotifyWidget",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Full-featured terminal emulator (VT100/xterm) as a Swift library
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "SpotifyWidget",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/SpotifyWidget"
        )
    ]
)
