// swift-tools-version:5.6
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
    ],
    targets: [
        .target(name: "WWNetworking", dependencies: []),
        .testTarget(name: "WWNetworkingTests", dependencies: ["WWNetworking"]),
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
