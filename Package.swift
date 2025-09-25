// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WWNetworking",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "WWNetworking", targets: ["WWNetworking"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "WWNetworking", resources: [.copy("Privacy")]),
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
