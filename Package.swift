// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "YahooSwiftance",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
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
