// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Glyph",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.0"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Glyph",
            dependencies: [
                "KeyboardShortcuts",
                "LaunchAtLogin"
            ]
        )
    ]
)
