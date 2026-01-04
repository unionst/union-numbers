// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "union-numbers",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "UnionNumbers",
            targets: ["UnionNumbers"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/unionst/union-gradients", from: "1.0.1"),
        .package(url: "https://github.com/unionst/union-shake", from: "1.0.1")
    ],
    targets: [
        .target(
            name: "UnionNumbers",
            dependencies: [
                .product(name: "UnionGradients", package: "union-gradients"),
                .product(name: "UnionShake", package: "union-shake")
            ]
        ),
    ]
)
