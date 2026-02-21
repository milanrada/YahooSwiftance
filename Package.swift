// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "YahooSwiftance",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "YahooSwiftance",
            targets: ["YahooSwiftance"]
        )
    ],
    targets: [
        .target(
            name: "YahooSwiftance"
        ),
        .executableTarget(
            name: "StreamingExample",
            dependencies: ["YahooSwiftance"],
            path: "Examples/StreamingExample"
        ),
        .executableTarget(
            name: "RESTExample",
            dependencies: ["YahooSwiftance"],
            path: "Examples/RESTExample"
        ),
        .testTarget(
            name: "YahooSwiftanceTests",
            dependencies: ["YahooSwiftance"]
        )
    ]
)
