// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Amai",
    products: [
        .library(name: "Amai", targets: ["Amai"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kirbyfan64/Cui", from: "0.1.0"),
        // .package(url: "https://github.com/tonyarnold/Differ", from: "1.2.0"),
    ],
    targets: [
        .target(name: "Amai", dependencies: ["Cui"]),
        .target(name: "AmaiDemo", dependencies: ["Amai"]),
    ]
)
