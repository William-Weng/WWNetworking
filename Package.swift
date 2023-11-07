// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WWNetworking",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "WWNetworking", targets: ["WWNetworking"]),
    ],
    dependencies: [
        .package(name: "WWPrint", url: "https://github.com/William-Weng/WWPrint.git", from: "1.2.0"),
    ],
    targets: [
        .target(name: "WWNetworking", dependencies: ["WWPrint"]),
        .testTarget(name: "WWNetworkingTests", dependencies: ["WWNetworking"]),
    ]
)
