// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AIParsingTestKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "AIParsingTestKit",
            targets: ["AIParsingTestKit"]
        )
    ],
    targets: [
        .target(name: "AIParsingTestKit"),
        .testTarget(
            name: "AIParsingTestKitTests",
            dependencies: ["AIParsingTestKit"]
        ),
        .testTarget(
            name: "CalendarParsingTests",
            dependencies: ["AIParsingTestKit"]
        )
    ]
)
