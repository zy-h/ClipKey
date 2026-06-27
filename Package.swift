// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClipKey",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClipKey",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
