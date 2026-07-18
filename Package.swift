// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "VoicePage",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoicePage", targets: ["VoicePage"])
    ],
    targets: [
        .executableTarget(
            name: "VoicePage",
            path: "Sources/VoicePage"
        )
    ],
    swiftLanguageVersions: [.v5]
)
