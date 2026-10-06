// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "ReadingCompanion",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ReadingDomain", targets: ["ReadingDomain"]),
        .library(name: "ReadingData", targets: ["ReadingData"]),
        .library(name: "ReadingUI", targets: ["ReadingUI"])
    ],
    dependencies: [.package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.0.0")],
    targets: [
        .target(name: "ReadingDomain", resources: [.copy("Resources/challenge_catalog_v2.json")]),
        .target(name: "ReadingData", dependencies: ["ReadingDomain", .product(name: "GRDB", package: "GRDB.swift")],
                resources: [.copy("Resources/local_v1.sql"), .copy("Resources/local_v2.sql"), .copy("Resources/local_v3.sql"), .copy("Resources/local_v4.sql"), .copy("Resources/local_v5.sql"), .copy("Resources/local_v6.sql")]),
        .target(name: "ReadingUI", dependencies: ["ReadingDomain"]),
        .testTarget(name: "ReadingDomainTests", dependencies: ["ReadingDomain"]),
        .testTarget(name: "ReadingDataTests", dependencies: ["ReadingData", "ReadingDomain", .product(name: "GRDB", package: "GRDB.swift")]),
        .testTarget(name: "ReadingUITests", dependencies: ["ReadingUI"])
    ]
)
