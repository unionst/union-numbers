// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "union-numbers",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "UnionNumbers",
            targets: ["UnionNumbers"]
        ),
    ],
    targets: [
        .target(
            name: "UnionNumbers"
        ),
    ]
)
