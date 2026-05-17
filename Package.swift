// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "tpopup",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "tpopup",
            path: "Sources/tpopup",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("NaturalLanguage")
            ]
        )
    ]
)
