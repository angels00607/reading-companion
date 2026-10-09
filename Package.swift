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
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.0.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")
    ],
    targets: [
        .target(name: "ReadingDomain", resources: [.copy("Resources/challenge_catalog_v2.json")]),
        .target(name: "ReadingData", dependencies: ["ReadingDomain", .product(name: "GRDB", package: "GRDB.swift"), .product(name: "ZIPFoundation", package: "ZIPFoundation")],
                resources: [.copy("Resources/local_v1.sql"), .copy("Resources/local_v2.sql"), .copy("Resources/local_v3.sql"), .copy("Resources/local_v4.sql"), .copy("Resources/local_v5.sql"), .copy("Resources/local_v6.sql"), .copy("Resources/local_v7.sql"), .copy("Resources/local_v8.sql"), .copy("Resources/local_v9.sql"), .copy("Resources/local_v10.sql"), .copy("Resources/local_v11.sql"), .copy("Resources/local_v12.sql"), .copy("Resources/local_v13.sql"), .copy("Resources/local_v14.sql")]),
        .target(name: "ReadingUI", dependencies: ["ReadingDomain"]),
        .testTarget(name: "ReadingDomainTests", dependencies: ["ReadingDomain"]),
        .testTarget(name: "ReadingDataTests", dependencies: ["ReadingData", "ReadingDomain", .product(name: "GRDB", package: "GRDB.swift"), .product(name: "ZIPFoundation", package: "ZIPFoundation")]),
        .testTarget(name: "ReadingUITests", dependencies: ["ReadingUI"])
    ]
)
