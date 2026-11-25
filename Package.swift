// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftMoon",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "SwiftMoon",
            targets: ["SwiftMoon"]
        )
    ],
    targets: [
        .target(
            name: "SwiftMoon"
        ),
        .testTarget(
            name: "SwiftMoonTests",
            dependencies: ["SwiftMoon"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
